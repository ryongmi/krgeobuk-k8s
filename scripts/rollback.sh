#!/bin/bash

# Kubernetes 롤백 자동화 스크립트
# Deployment를 이전 버전으로 롤백

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes 롤백 자동화 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 사용법 출력
usage() {
    echo "사용법: $0 <environment> <service> [revision]"
    echo ""
    echo "환경:"
    echo "  dev    - 개발 환경 (krgeobuk-dev 네임스페이스)"
    echo "  prod   - 프로덕션 환경 (krgeobuk-prod 네임스페이스)"
    echo ""
    echo "서비스:"
    echo "  auth-server            - 인증 서버"
    echo "  authz-server           - 권한 서버"
    echo "  portal-server          - 포털 서버"
    echo "  my-pick-server         - MyPick 서버"
    echo "  my-pick-client         - MyPick 클라이언트"
    echo "  portal-admin-client    - 포털 관리자 클라이언트"
    echo "  my-pick-admin-client   - MyPick 관리자 클라이언트"
    echo ""
    echo "Revision (선택사항):"
    echo "  지정하지 않으면 이전 버전으로 롤백"
    echo "  특정 revision 번호를 지정하면 해당 버전으로 롤백"
    echo ""
    echo "예시:"
    echo "  $0 dev auth-server              # 이전 버전으로 롤백"
    echo "  $0 prod auth-server 3           # Revision 3으로 롤백"
    echo "  $0 dev auth-server --dry-run    # 롤백 시뮬레이션 (실제 롤백 안 함)"
    exit 1
}

# 인자 확인
if [ $# -lt 2 ]; then
    usage
fi

ENV=$1
SERVICE=$2
REVISION=${3:-""}
DRY_RUN=false

# Dry-run 확인
if [[ "$REVISION" == "--dry-run" ]]; then
    DRY_RUN=true
    REVISION=""
fi

# 환경 검증
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
    echo -e "${RED}오류: 지원하지 않는 환경입니다: $ENV${NC}"
    echo -e "${YELLOW}dev 또는 prod를 입력하세요.${NC}"
    exit 1
fi

# 서비스 검증
VALID_SERVICES=("auth-server" "authz-server" "portal-server" "my-pick-server" "my-pick-client" "portal-admin-client" "my-pick-admin-client")
if [[ ! " ${VALID_SERVICES[@]} " =~ " ${SERVICE} " ]]; then
    echo -e "${RED}오류: 지원하지 않는 서비스입니다: $SERVICE${NC}"
    usage
fi

# 네임스페이스 설정
if [ "$ENV" == "dev" ]; then
    NAMESPACE="krgeobuk-dev"
else
    NAMESPACE="krgeobuk-prod"
fi

echo -e "${BLUE}롤백 환경:${NC} $ENV ($NAMESPACE)"
echo -e "${BLUE}롤백 대상:${NC} $SERVICE"
if [ -n "$REVISION" ]; then
    echo -e "${BLUE}타겟 Revision:${NC} $REVISION"
else
    echo -e "${BLUE}타겟 Revision:${NC} 이전 버전"
fi
if [ "$DRY_RUN" == true ]; then
    echo -e "${YELLOW}모드:${NC} Dry-run (시뮬레이션)"
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

echo -e "${GREEN}✓${NC} kubectl 연결 확인 완료"
echo ""

# 네임스페이스 확인
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}오류: 네임스페이스를 찾을 수 없습니다: $NAMESPACE${NC}"
    exit 1
fi

# Deployment 목록 가져오기
echo -e "${CYAN}Deployment 확인 중...${NC}"
DEPLOYMENTS=$(kubectl get deployment -n $NAMESPACE -l "app=$SERVICE" -o jsonpath='{.items[*].metadata.name}')

if [ -z "$DEPLOYMENTS" ]; then
    echo -e "${RED}오류: $SERVICE의 Deployment를 찾을 수 없습니다.${NC}"
    echo -e "${YELLOW}배포된 Deployment가 없거나 레이블이 올바르지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Deployment 확인 완료: $DEPLOYMENTS"
echo ""

# 각 Deployment에 대해 롤백 수행
for DEPLOYMENT in $DEPLOYMENTS; do
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}롤백 대상: $DEPLOYMENT${NC}"
    echo -e "${BLUE}========================================${NC}"

    # 롤아웃 히스토리 확인
    echo -e "${CYAN}롤아웃 히스토리:${NC}"
    kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE
    echo ""

    # 현재 revision 확인
    CURRENT_REVISION=$(kubectl get deployment/$DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
    echo -e "${CYAN}현재 Revision:${NC} $CURRENT_REVISION"
    echo ""

    # 롤백 확인
    if [ "$DRY_RUN" != true ]; then
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}롤백 확인${NC}"
        echo -e "${YELLOW}========================================${NC}"
        echo -e "Deployment: ${CYAN}$DEPLOYMENT${NC}"
        echo -e "네임스페이스: ${CYAN}$NAMESPACE${NC}"
        echo -e "현재 Revision: ${CYAN}$CURRENT_REVISION${NC}"
        if [ -n "$REVISION" ]; then
            echo -e "타겟 Revision: ${CYAN}$REVISION${NC}"
        else
            echo -e "타겟 Revision: ${CYAN}이전 버전${NC}"
        fi
        echo ""

        read -p "롤백을 진행하시겠습니까? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}롤백이 취소되었습니다.${NC}"
            continue
        fi
        echo ""
    fi

    # 롤백 실행
    echo -e "${CYAN}롤백 실행 중...${NC}"
    if [ -n "$REVISION" ]; then
        # 특정 revision으로 롤백
        if [ "$DRY_RUN" == true ]; then
            echo -e "${YELLOW}[Dry-run]${NC} kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE --to-revision=$REVISION"
        else
            if kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE --to-revision=$REVISION; then
                echo -e "${GREEN}✓${NC} Revision $REVISION으로 롤백 시작됨"
            else
                echo -e "${RED}✗${NC} 롤백 실패"
                continue
            fi
        fi
    else
        # 이전 버전으로 롤백
        if [ "$DRY_RUN" == true ]; then
            echo -e "${YELLOW}[Dry-run]${NC} kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE"
        else
            if kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE; then
                echo -e "${GREEN}✓${NC} 이전 버전으로 롤백 시작됨"
            else
                echo -e "${RED}✗${NC} 롤백 실패"
                continue
            fi
        fi
    fi

    # 롤아웃 상태 확인 (dry-run이 아닐 때만)
    if [ "$DRY_RUN" != true ]; then
        echo -e "${CYAN}롤아웃 상태 확인 중...${NC}"
        if kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=300s; then
            echo -e "${GREEN}✓${NC} 롤백 완료"
        else
            echo -e "${YELLOW}⚠${NC} 롤아웃 타임아웃 (계속 진행 중일 수 있습니다)"
        fi
        echo ""

        # 롤백 후 revision 확인
        NEW_REVISION=$(kubectl get deployment/$DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
        echo -e "${GREEN}롤백 후 Revision:${NC} $NEW_REVISION"
        echo ""
    fi
done

if [ "$DRY_RUN" != true ]; then
    # Pod 상태 확인
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Pod 상태 확인${NC}"
    echo -e "${BLUE}========================================${NC}"
    kubectl get pods -n $NAMESPACE -l "app=$SERVICE" -o wide
    echo ""

    # 이벤트 확인
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}최근 이벤트${NC}"
    echo -e "${BLUE}========================================${NC}"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i "$SERVICE" | tail -10
    echo ""

    # 다음 단계 안내
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}다음 단계${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}1. Pod 로그 확인${NC}"
    echo "   ./scripts/logs.sh $ENV $SERVICE"
    echo ""
    echo -e "${YELLOW}2. 헬스 체크${NC}"
    echo "   ./scripts/health-check.sh $ENV"
    echo ""
    echo -e "${YELLOW}3. Pod 상태 모니터링${NC}"
    echo "   kubectl get pods -n $NAMESPACE -l app=$SERVICE -w"
    echo ""
    echo -e "${YELLOW}4. 롤아웃 히스토리 확인${NC}"
    for DEPLOYMENT in $DEPLOYMENTS; do
        echo "   kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE"
    done
    echo ""

    echo -e "${GREEN}✓ 롤백이 완료되었습니다!${NC}"
else
    echo -e "${YELLOW}Dry-run 모드로 실행되었습니다. 실제 롤백은 수행되지 않았습니다.${NC}"
fi
