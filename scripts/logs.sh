#!/bin/bash

# Kubernetes 로그 수집 스크립트
# Pod 로그를 조회하고 분석

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes 로그 수집 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 사용법 출력
usage() {
    echo "사용법: $0 <environment> <service> [options]"
    echo ""
    echo "환경:"
    echo "  dev    - 개발 환경 (krgeobuk-dev 네임스페이스)"
    echo "  prod   - 프로덕션 환경 (krgeobuk-prod 네임스페이스)"
    echo ""
    echo "서비스:"
    echo "  auth-server            - 인증 서버"
    echo "  auth-client            - 인증 클라이언트"
    echo "  authz-server           - 권한 서버"
    echo "  portal-server          - 포털 서버"
    echo "  portal-client          - 포털 클라이언트"
    echo "  my-pick-server         - MyPick 서버"
    echo "  my-pick-client         - MyPick 클라이언트"
    echo "  portal-admin-client    - 포털 관리자 클라이언트"
    echo "  my-pick-admin-client   - MyPick 관리자 클라이언트"
    echo "  mysql                  - MySQL"
    echo "  redis                  - Redis"
    echo "  verdaccio              - Verdaccio"
    echo ""
    echo "옵션:"
    echo "  -f, --follow           실시간 로그 스트리밍"
    echo "  -p, --previous         이전 컨테이너 로그 (crashed pod)"
    echo "  --tail N               마지막 N줄만 표시 (기본: 100)"
    echo "  --timestamps           타임스탬프 표시"
    echo "  --all-pods             모든 Pod 로그 병합"
    echo "  --pod <pod-name>       특정 Pod만 조회"
    echo "  --container <name>     특정 컨테이너만 조회"
    echo "  --since <duration>     특정 시간 이후 로그 (예: 1h, 30m, 1d)"
    echo ""
    echo "예시:"
    echo "  $0 dev auth-server                        # 기본 로그 조회 (마지막 100줄)"
    echo "  $0 dev auth-server -f                     # 실시간 로그 스트리밍"
    echo "  $0 dev auth-server --tail 500             # 마지막 500줄"
    echo "  $0 dev auth-server -p                     # 이전 컨테이너 로그"
    echo "  $0 dev auth-server --all-pods             # 모든 Pod 로그"
    echo "  $0 dev auth-server --since 1h             # 최근 1시간 로그"
    echo "  $0 dev auth-server --pod auth-server-xxx  # 특정 Pod 로그"
    exit 1
}

# 인자 확인
if [ $# -lt 2 ]; then
    usage
fi

ENV=$1
SERVICE=$2
shift 2

# 기본 옵션
FOLLOW=false
PREVIOUS=false
TAIL=100
TIMESTAMPS=false
ALL_PODS=false
SPECIFIC_POD=""
CONTAINER=""
SINCE=""

# 옵션 파싱
while [ $# -gt 0 ]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -p|--previous)
            PREVIOUS=true
            shift
            ;;
        --tail)
            TAIL=$2
            shift 2
            ;;
        --timestamps)
            TIMESTAMPS=true
            shift
            ;;
        --all-pods)
            ALL_PODS=true
            shift
            ;;
        --pod)
            SPECIFIC_POD=$2
            shift 2
            ;;
        --container)
            CONTAINER=$2
            shift 2
            ;;
        --since)
            SINCE=$2
            shift 2
            ;;
        *)
            echo -e "${RED}알 수 없는 옵션: $1${NC}"
            usage
            ;;
    esac
done

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

echo -e "${BLUE}로그 수집 환경:${NC} $ENV ($NAMESPACE)"
echo -e "${BLUE}대상 서비스:${NC} $SERVICE"

# 옵션 표시
OPTIONS=""
if [ "$FOLLOW" == true ]; then
    echo -e "${BLUE}모드:${NC} 실시간 스트리밍"
    OPTIONS="$OPTIONS --follow"
fi
if [ "$PREVIOUS" == true ]; then
    echo -e "${BLUE}타겟:${NC} 이전 컨테이너"
    OPTIONS="$OPTIONS --previous"
fi
if [ "$TIMESTAMPS" == true ]; then
    OPTIONS="$OPTIONS --timestamps"
fi
if [ -n "$SINCE" ]; then
    echo -e "${BLUE}시간 범위:${NC} 최근 $SINCE"
    OPTIONS="$OPTIONS --since=$SINCE"
else
    echo -e "${BLUE}로그 라인:${NC} 마지막 $TAIL줄"
    OPTIONS="$OPTIONS --tail=$TAIL"
fi
if [ -n "$SPECIFIC_POD" ]; then
    echo -e "${BLUE}Pod:${NC} $SPECIFIC_POD"
fi
if [ -n "$CONTAINER" ]; then
    echo -e "${BLUE}Container:${NC} $CONTAINER"
fi
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

# 네임스페이스 확인
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}오류: 네임스페이스를 찾을 수 없습니다: $NAMESPACE${NC}"
    exit 1
fi

# Pod 목록 가져오기
if [ -n "$SPECIFIC_POD" ]; then
    PODS=$SPECIFIC_POD
else
    PODS=$(kubectl get pods -n $NAMESPACE -l "app=$SERVICE" -o jsonpath='{.items[*].metadata.name}')
fi

if [ -z "$PODS" ]; then
    echo -e "${RED}오류: $SERVICE의 Pod를 찾을 수 없습니다.${NC}"
    echo -e "${YELLOW}배포된 Pod가 없거나 레이블이 올바르지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Pod 확인 완료"
echo ""

# 로그 조회 함수
show_logs() {
    local pod=$1
    local options=$2

    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Pod: $pod${NC}"
    echo -e "${CYAN}========================================${NC}"

    # Pod 상태 확인
    local status=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
    local ready=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    echo -e "상태: ${CYAN}$status${NC} | Ready: ${CYAN}$ready${NC}"
    echo ""

    # 컨테이너 목록
    local containers=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}')
    echo -e "컨테이너: ${CYAN}$containers${NC}"
    echo ""

    # 로그 조회
    if [ -n "$CONTAINER" ]; then
        # 특정 컨테이너만
        echo -e "${BLUE}로그 (컨테이너: $CONTAINER):${NC}"
        kubectl logs $pod -n $NAMESPACE -c $CONTAINER $options
    else
        # 모든 컨테이너
        for container in $containers; do
            echo -e "${BLUE}로그 (컨테이너: $container):${NC}"
            kubectl logs $pod -n $NAMESPACE -c $container $options 2>/dev/null || echo -e "${YELLOW}로그를 가져올 수 없습니다.${NC}"
            echo ""
        done
    fi
}

# 로그 수집 시작
if [ "$ALL_PODS" == true ]; then
    # 모든 Pod 로그 병합
    echo -e "${CYAN}모든 Pod 로그 (병합):${NC}"
    echo ""

    if [ "$FOLLOW" == true ]; then
        # 실시간 스트리밍은 stern 사용 권장
        echo -e "${YELLOW}여러 Pod의 실시간 로그를 보려면 stern을 사용하세요:${NC}"
        echo "  stern $SERVICE -n $NAMESPACE"
        echo ""
        echo -e "${YELLOW}stern이 없다면 첫 번째 Pod만 스트리밍합니다.${NC}"
        echo ""
        FIRST_POD=$(echo $PODS | awk '{print $1}')
        show_logs $FIRST_POD "$OPTIONS"
    else
        # 모든 Pod 로그 순차적으로 표시
        for pod in $PODS; do
            show_logs $pod "$OPTIONS"
            echo ""
        done
    fi
else
    # 단일 Pod 또는 첫 번째 Pod
    if [ -n "$SPECIFIC_POD" ]; then
        TARGET_POD=$SPECIFIC_POD
    else
        # Pod가 여러 개면 선택
        POD_COUNT=$(echo $PODS | wc -w)
        if [ $POD_COUNT -gt 1 ]; then
            echo -e "${YELLOW}여러 개의 Pod가 발견되었습니다:${NC}"
            i=1
            for pod in $PODS; do
                echo "  $i) $pod"
                i=$((i + 1))
            done
            echo ""
            echo -e "${YELLOW}첫 번째 Pod의 로그를 표시합니다.${NC}"
            echo -e "${YELLOW}특정 Pod를 보려면 --pod 옵션을 사용하세요.${NC}"
            echo -e "${YELLOW}모든 Pod를 보려면 --all-pods 옵션을 사용하세요.${NC}"
            echo ""
        fi
        TARGET_POD=$(echo $PODS | awk '{print $1}')
    fi

    show_logs $TARGET_POD "$OPTIONS"
fi

# 추가 정보
if [ "$FOLLOW" != true ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}추가 명령어${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}1. 실시간 로그 스트리밍${NC}"
    echo "   $0 $ENV $SERVICE -f"
    echo ""
    echo -e "${YELLOW}2. 이전 컨테이너 로그 (Crashed Pod)${NC}"
    echo "   $0 $ENV $SERVICE -p"
    echo ""
    echo -e "${YELLOW}3. 최근 1시간 로그${NC}"
    echo "   $0 $ENV $SERVICE --since 1h"
    echo ""
    echo -e "${YELLOW}4. 모든 Pod 로그${NC}"
    echo "   $0 $ENV $SERVICE --all-pods"
    echo ""
    echo -e "${YELLOW}5. Pod 상세 정보${NC}"
    echo "   kubectl describe pod <pod-name> -n $NAMESPACE"
    echo ""
    echo -e "${YELLOW}6. 이벤트 확인${NC}"
    echo "   kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep $SERVICE"
    echo ""
fi
