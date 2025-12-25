#!/bin/bash

# Kubernetes 배포 자동화 스크립트
# Kustomize를 사용하여 환경별 서비스 배포

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes 배포 자동화 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 사용법 출력
usage() {
    echo "사용법: $0 <environment> <service>"
    echo ""
    echo "환경:"
    echo "  dev    - 개발 환경 (krgeobuk-dev 네임스페이스)"
    echo "  prod   - 프로덕션 환경 (krgeobuk-prod 네임스페이스)"
    echo ""
    echo "서비스:"
    echo "  all                    - 전체 환경 배포 (environments/\$ENV)"
    echo "  infrastructure         - Ingress/cert-manager 설치 안내"
    echo "  auth-server            - 인증 서버"
    echo "  auth-client            - 인증 클라이언트"
    echo "  authz-server           - 권한 서버"
    echo "  portal-server          - 포털 서버"
    echo "  portal-client          - 포털 클라이언트"
    echo "  my-pick-server         - MyPick 서버"
    echo "  my-pick-client         - MyPick 클라이언트"
    echo "  portal-admin-client    - 포털 관리자 클라이언트"
    echo "  my-pick-admin-client   - MyPick 관리자 클라이언트"
    echo ""
    echo "참고:"
    echo "  - 개별 서비스 배포 시에도 환경별 패치가 자동 적용됩니다"
    echo ""
    echo "예시:"
    echo "  $0 dev all                    # Dev 환경에 모든 서비스 배포"
    echo "  $0 prod auth-server           # Prod 환경에 auth-server 배포"
    echo "  $0 dev infrastructure         # Dev 환경에 인프라만 배포"
    exit 1
}

# 인자 확인
if [ $# -ne 2 ]; then
    usage
fi

ENV=$1
SERVICE=$2

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

echo -e "${BLUE}배포 환경:${NC} $ENV ($NAMESPACE)"
echo -e "${BLUE}배포 대상:${NC} $SERVICE"
echo ""

# kubectl 설치 확인
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}오류: kubectl이 설치되어 있지 않습니다.${NC}"
    exit 1
fi

# kustomize 설치 확인
if ! command -v kustomize &> /dev/null; then
    echo -e "${YELLOW}경고: kustomize가 설치되어 있지 않습니다.${NC}"
    echo -e "${YELLOW}kubectl kustomize를 사용합니다.${NC}"
    KUSTOMIZE_CMD="kubectl kustomize"
else
    KUSTOMIZE_CMD="kustomize build"
fi

# 클러스터 연결 확인
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}오류: Kubernetes 클러스터에 연결할 수 없습니다.${NC}"
    echo -e "${YELLOW}kubectl config를 확인하세요.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} kubectl 연결 확인 완료"
echo ""

# 네임스페이스 확인/생성
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}네임스페이스가 존재하지 않습니다. 생성합니다: $NAMESPACE${NC}"
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✓${NC} 네임스페이스 생성 완료"
else
    echo -e "${GREEN}✓${NC} 네임스페이스 확인 완료: $NAMESPACE"
fi
echo ""

# 배포할 서비스 목록 설정
declare -a SERVICES

case $SERVICE in
    all)
        # 전체 환경 배포 (environments/$ENV)
        SERVICES=("all")
        ;;
    infrastructure|auth-server|auth-client|authz-server|portal-server|portal-client|my-pick-server|my-pick-client|portal-admin-client|my-pick-admin-client)
        SERVICES=("$SERVICE")
        ;;
    *)
        echo -e "${RED}오류: 지원하지 않는 서비스입니다: $SERVICE${NC}"
        usage
        ;;
esac

# 배포 확인
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}배포 정보 확인${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "환경: ${CYAN}$ENV${NC} (네임스페이스: ${CYAN}$NAMESPACE${NC})"
echo -e "배포할 서비스 (${#SERVICES[@]}개):"
for svc in "${SERVICES[@]}"; do
    echo -e "  - ${CYAN}$svc${NC}"
done
echo ""

read -p "배포를 진행하시겠습니까? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}배포가 취소되었습니다.${NC}"
    exit 0
fi
echo ""

# 배포 함수
deploy_service() {
    local service=$1
    local deploy_path=""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}배포 중: $service${NC}"
    echo -e "${BLUE}========================================${NC}"

    # 배포 경로 설정
    if [ "$service" == "infrastructure" ]; then
        # Infrastructure는 별도 설치 필요
        echo -e "${YELLOW}Infrastructure는 다음 명령어로 수동 설치하세요:${NC}"
        echo ""
        echo -e "${CYAN}NGINX Ingress Controller:${NC}"
        echo "  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/baremetal/deploy.yaml"
        echo ""
        echo -e "${CYAN}cert-manager:${NC}"
        echo "  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml"
        echo "  kubectl apply -f infrastructure/cert-manager/cluster-issuer-staging.yaml"
        echo "  kubectl apply -f infrastructure/cert-manager/cluster-issuer-prod.yaml"
        echo ""
        echo -e "${CYAN}자세한 내용:${NC}"
        echo "  - infrastructure/ingress-nginx/README.md"
        echo "  - infrastructure/cert-manager/README.md"
        echo ""
        return 0
    elif [ "$service" == "all" ]; then
        # 전체 환경 배포
        deploy_path="environments/$ENV"
    else
        # 개별 서비스 배포 (환경별 패치 적용됨)
        deploy_path="applications/$service/overlays/$ENV"
    fi

    # 경로 확인
    if [ ! -d "$deploy_path" ]; then
        echo -e "${RED}✗ 오류: 경로를 찾을 수 없습니다: $deploy_path${NC}"
        return 1
    fi

    echo -e "${CYAN}경로:${NC} $deploy_path"

    # Kustomize build 및 apply
    echo -e "${CYAN}Kustomize 빌드 및 적용 중...${NC}"
    if $KUSTOMIZE_CMD "$deploy_path" | kubectl apply -f - -n $NAMESPACE; then
        echo -e "${GREEN}✓${NC} $service 배포 완료"
    else
        echo -e "${RED}✗${NC} $service 배포 실패"
        return 1
    fi

    # Deployment 롤아웃 상태 확인 (all 배포인 경우만)
    if [ "$service" == "all" ]; then
        echo -e "${CYAN}배포된 서비스 롤아웃 확인 중...${NC}"

        # 모든 deployment 확인
        deployments=$(kubectl get deployment -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

        if [ -n "$deployments" ]; then
            for deploy in $deployments; do
                echo -e "${CYAN}  - $deploy 롤아웃 대기 중...${NC}"
                if kubectl rollout status deployment/$deploy -n $NAMESPACE --timeout=60s; then
                    echo -e "${GREEN}  ✓ $deploy 롤아웃 완료${NC}"
                else
                    echo -e "${YELLOW}  ⚠ $deploy 롤아웃 진행 중 (백그라운드에서 계속됩니다)${NC}"
                fi
            done
        fi
    elif [ "$service" != "infrastructure" ]; then
        # 개별 서비스 롤아웃 확인
        if kubectl get deployment -n $NAMESPACE -l "app=$service" &> /dev/null; then
            deployments=$(kubectl get deployment -n $NAMESPACE -l "app=$service" -o jsonpath='{.items[*].metadata.name}')

            if [ -n "$deployments" ]; then
                for deploy in $deployments; do
                    echo -e "${CYAN}  - $deploy 롤아웃 대기 중...${NC}"
                    if kubectl rollout status deployment/$deploy -n $NAMESPACE --timeout=300s; then
                        echo -e "${GREEN}  ✓ $deploy 롤아웃 완료${NC}"
                    else
                        echo -e "${YELLOW}  ⚠ $deploy 롤아웃 타임아웃 (계속 진행 중일 수 있습니다)${NC}"
                    fi
                done
            fi
        fi
    fi

    echo ""
}

# 배포 실행
FAILED_SERVICES=()
SUCCESSFUL_SERVICES=()

for service in "${SERVICES[@]}"; do
    if deploy_service "$service"; then
        SUCCESSFUL_SERVICES+=("$service")
    else
        FAILED_SERVICES+=("$service")
        echo -e "${RED}$service 배포 중 오류가 발생했습니다. 계속 진행합니다.${NC}"
        echo ""
    fi
done

# 배포 결과 요약
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}배포 결과 요약${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "환경: ${CYAN}$ENV${NC} ($NAMESPACE)"
echo -e "총 배포 시도: ${CYAN}${#SERVICES[@]}개${NC}"
echo -e "${GREEN}성공: ${#SUCCESSFUL_SERVICES[@]}개${NC}"
echo -e "${RED}실패: ${#FAILED_SERVICES[@]}개${NC}"
echo ""

if [ ${#SUCCESSFUL_SERVICES[@]} -gt 0 ]; then
    echo -e "${GREEN}성공한 서비스:${NC}"
    for svc in "${SUCCESSFUL_SERVICES[@]}"; do
        echo -e "  ${GREEN}✓${NC} $svc"
    done
    echo ""
fi

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo -e "${RED}실패한 서비스:${NC}"
    for svc in "${FAILED_SERVICES[@]}"; do
        echo -e "  ${RED}✗${NC} $svc"
    done
    echo ""
fi

# Pod 상태 확인
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Pod 상태 확인${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl get pods -n $NAMESPACE -o wide
echo ""

# Service 상태 확인
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Service 상태 확인${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl get svc -n $NAMESPACE
echo ""

# 다음 단계 안내
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}다음 단계${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}1. Pod 로그 확인${NC}"
echo "   ./scripts/logs.sh $ENV <service-name>"
echo ""
echo -e "${YELLOW}2. 헬스 체크${NC}"
echo "   ./scripts/health-check.sh $ENV"
echo ""
echo -e "${YELLOW}3. Pod 상태 모니터링${NC}"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo -e "${YELLOW}4. 롤백 (문제 발생 시)${NC}"
echo "   ./scripts/rollback.sh $ENV <service-name>"
echo ""

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo -e "${RED}⚠️  일부 서비스 배포가 실패했습니다. 로그를 확인하세요.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ 모든 서비스 배포가 완료되었습니다!${NC}"
    exit 0
fi
