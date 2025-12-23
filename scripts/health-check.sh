#!/bin/bash

# Kubernetes 헬스 체크 스크립트
# 모든 서비스의 상태를 확인하고 리포트 생성

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes 헬스 체크 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 사용법 출력
usage() {
    echo "사용법: $0 <environment> [service]"
    echo ""
    echo "환경:"
    echo "  dev    - 개발 환경 (krgeobuk-dev 네임스페이스)"
    echo "  prod   - 프로덕션 환경 (krgeobuk-prod 네임스페이스)"
    echo ""
    echo "서비스 (선택사항):"
    echo "  지정하지 않으면 모든 서비스 체크"
    echo "  auth-server            - 인증 서버"
    echo "  authz-server           - 권한 서버"
    echo "  portal-server          - 포털 서버"
    echo "  my-pick-server         - MyPick 서버"
    echo "  my-pick-client         - MyPick 클라이언트"
    echo "  portal-admin-client    - 포털 관리자 클라이언트"
    echo "  my-pick-admin-client   - MyPick 관리자 클라이언트"
    echo "  infrastructure         - 인프라 (MySQL, Redis, Verdaccio)"
    echo ""
    echo "예시:"
    echo "  $0 dev                  # Dev 환경 전체 체크"
    echo "  $0 prod auth-server     # Prod 환경 auth-server만 체크"
    exit 1
}

# 인자 확인
if [ $# -lt 1 ]; then
    usage
fi

ENV=$1
SERVICE=${2:-"all"}

# 환경 검증
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
    echo -e "${RED}오류: 지원하지 않는 환경입니다: $ENV${NC}"
    echo -e "${YELLOW}dev 또는 prod를 입력하세요.${NC}"
    exit 1
fi

# 네임스페이스 설정
if [ "$ENV" == "dev" ]; then
    NAMESPACE="krgeobuk-dev"
else
    NAMESPACE="krgeobuk-prod"
fi

echo -e "${BLUE}헬스 체크 환경:${NC} $ENV ($NAMESPACE)"
echo -e "${BLUE}대상 서비스:${NC} $SERVICE"
echo ""

# kubectl 설치 확인
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}오류: kubectl이 설치되어 있지 않습니다.${NC}"
    exit 1
fi

# 클러스터 연결 확인
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}오류: Kubernetes 클러스터에 연결할 수 없습니다.${NC}"
    echo -e "${YELLOW}kubectl config를 확인하세요.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} kubectl 연결 확인 완료"
echo ""

# 네임스페이스 확인
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}오류: 네임스페이스를 찾을 수 없습니다: $NAMESPACE${NC}"
    exit 1
fi

# 헬스 체크 카운터
TOTAL_PODS=0
HEALTHY_PODS=0
UNHEALTHY_PODS=0
TOTAL_SERVICES=0
HEALTHY_SERVICES=0
UNHEALTHY_SERVICES=0

# Pod 헬스 체크 함수
check_pod_health() {
    local pod_name=$1
    local namespace=$2

    # Pod 상태 가져오기
    local status=$(kubectl get pod $pod_name -n $namespace -o jsonpath='{.status.phase}')
    local ready=$(kubectl get pod $pod_name -n $namespace -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    local restarts=$(kubectl get pod $pod_name -n $namespace -o jsonpath='{.status.containerStatuses[0].restartCount}')

    TOTAL_PODS=$((TOTAL_PODS + 1))

    # 상태 표시
    if [[ "$status" == "Running" && "$ready" == "True" ]]; then
        if [ "$restarts" -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} $pod_name - ${GREEN}Healthy${NC} (Restarts: $restarts)"
            HEALTHY_PODS=$((HEALTHY_PODS + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} $pod_name - ${YELLOW}Running with restarts${NC} (Restarts: $restarts)"
            HEALTHY_PODS=$((HEALTHY_PODS + 1))
        fi
    else
        echo -e "  ${RED}✗${NC} $pod_name - ${RED}Unhealthy${NC} (Status: $status, Ready: $ready, Restarts: $restarts)"
        UNHEALTHY_PODS=$((UNHEALTHY_PODS + 1))

        # 상세 정보 표시
        echo -e "    ${CYAN}컨테이너 상태:${NC}"
        kubectl get pod $pod_name -n $namespace -o jsonpath='{range .status.containerStatuses[*]}      {.name}: {.state}{"\n"}{end}'
    fi
}

# 서비스 헬스 체크 함수
check_service_health() {
    local service_name=$1
    local namespace=$2

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}서비스: $service_name${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Pod 목록 가져오기
    local pods=$(kubectl get pods -n $namespace -l "app=$service_name" -o jsonpath='{.items[*].metadata.name}')

    if [ -z "$pods" ]; then
        echo -e "${YELLOW}⚠ Pod가 없습니다.${NC}"
        TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
        UNHEALTHY_SERVICES=$((UNHEALTHY_SERVICES + 1))
        echo ""
        return
    fi

    # 각 Pod 체크
    local service_healthy=true
    for pod in $pods; do
        check_pod_health $pod $namespace
        if [ $? -ne 0 ]; then
            service_healthy=false
        fi
    done

    # Service 엔드포인트 확인
    echo ""
    echo -e "${CYAN}Endpoints:${NC}"
    local endpoints=$(kubectl get endpoints -n $namespace -l "app=$service_name" -o jsonpath='{.items[*].subsets[*].addresses[*].ip}')
    if [ -n "$endpoints" ]; then
        echo -e "  ${GREEN}✓${NC} Endpoints: $endpoints"
    else
        echo -e "  ${YELLOW}⚠${NC} Endpoints가 없습니다."
        service_healthy=false
    fi

    # Deployment 상태 확인
    echo ""
    echo -e "${CYAN}Deployment 상태:${NC}"
    local deployments=$(kubectl get deployment -n $namespace -l "app=$service_name" -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$deployments" ]; then
        for deploy in $deployments; do
            local desired=$(kubectl get deployment $deploy -n $namespace -o jsonpath='{.spec.replicas}')
            local current=$(kubectl get deployment $deploy -n $namespace -o jsonpath='{.status.replicas}')
            local ready=$(kubectl get deployment $deploy -n $namespace -o jsonpath='{.status.readyReplicas}')
            local available=$(kubectl get deployment $deploy -n $namespace -o jsonpath='{.status.availableReplicas}')

            if [ "$desired" -eq "$ready" ] && [ "$desired" -eq "$available" ]; then
                echo -e "  ${GREEN}✓${NC} $deploy: $ready/$desired ready"
            else
                echo -e "  ${YELLOW}⚠${NC} $deploy: $ready/$desired ready (current: $current, available: $available)"
                service_healthy=false
            fi
        done
    fi

    # 서비스 전체 상태
    echo ""
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    if [ "$service_healthy" == true ]; then
        echo -e "${GREEN}✓ $service_name: Healthy${NC}"
        HEALTHY_SERVICES=$((HEALTHY_SERVICES + 1))
    else
        echo -e "${RED}✗ $service_name: Unhealthy${NC}"
        UNHEALTHY_SERVICES=$((UNHEALTHY_SERVICES + 1))
    fi
    echo ""
}

# 서비스 목록 설정
declare -a SERVICES

if [ "$SERVICE" == "all" ]; then
    SERVICES=(
        "mysql"
        "redis"
        "verdaccio"
        "auth-server"
        "authz-server"
        "portal-server"
        "my-pick-server"
        "my-pick-client"
        "portal-admin-client"
        "my-pick-admin-client"
    )
else
    SERVICES=("$SERVICE")
fi

# 헬스 체크 시작
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}헬스 체크 시작${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

for svc in "${SERVICES[@]}"; do
    check_service_health $svc $NAMESPACE
done

# 전체 리소스 상태
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}전체 리소스 상태${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${CYAN}Pods:${NC}"
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo -e "${CYAN}Services:${NC}"
kubectl get svc -n $NAMESPACE
echo ""

echo -e "${CYAN}Deployments:${NC}"
kubectl get deployments -n $NAMESPACE
echo ""

echo -e "${CYAN}StatefulSets:${NC}"
kubectl get statefulsets -n $NAMESPACE 2>/dev/null || echo "No StatefulSets found"
echo ""

# 리소스 사용량
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}리소스 사용량${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${CYAN}노드 리소스:${NC}"
kubectl top nodes 2>/dev/null || echo -e "${YELLOW}⚠ Metrics Server가 설치되지 않았습니다.${NC}"
echo ""

echo -e "${CYAN}Pod 리소스 (Top 10):${NC}"
kubectl top pods -n $NAMESPACE 2>/dev/null | head -11 || echo -e "${YELLOW}⚠ Metrics Server가 설치되지 않았습니다.${NC}"
echo ""

# 최근 이벤트
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}최근 이벤트 (Warning/Error)${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -E "Warning|Error" | tail -10 || echo "No warning/error events"
echo ""

# 헬스 체크 요약
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}헬스 체크 요약${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "환경: ${CYAN}$ENV${NC} ($NAMESPACE)"
echo -e "체크 시간: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""
echo -e "서비스 상태:"
echo -e "  총 서비스: ${CYAN}$TOTAL_SERVICES${NC}"
echo -e "  ${GREEN}Healthy: $HEALTHY_SERVICES${NC}"
echo -e "  ${RED}Unhealthy: $UNHEALTHY_SERVICES${NC}"
echo ""
echo -e "Pod 상태:"
echo -e "  총 Pods: ${CYAN}$TOTAL_PODS${NC}"
echo -e "  ${GREEN}Healthy: $HEALTHY_PODS${NC}"
echo -e "  ${RED}Unhealthy: $UNHEALTHY_PODS${NC}"
echo ""

# 전체 상태
if [ $UNHEALTHY_SERVICES -eq 0 ] && [ $UNHEALTHY_PODS -eq 0 ]; then
    echo -e "${GREEN}✓ 모든 서비스가 정상 작동 중입니다!${NC}"
    exit 0
else
    echo -e "${RED}✗ 일부 서비스에 문제가 있습니다.${NC}"
    echo ""
    echo -e "${YELLOW}문제 해결 방법:${NC}"
    echo "  1. Pod 로그 확인: ./scripts/logs.sh $ENV <service-name>"
    echo "  2. Pod 상세 정보: kubectl describe pod <pod-name> -n $NAMESPACE"
    echo "  3. 이벤트 확인: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
    echo "  4. 롤백 고려: ./scripts/rollback.sh $ENV <service-name>"
    exit 1
fi
