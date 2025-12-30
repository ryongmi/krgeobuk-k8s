#!/bin/bash

# Dev 환경용 로컬 이미지 빌드 및 k3s Import
# 로컬 Kubernetes 클러스터에서 사용할 Docker 이미지 빌드

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Dev 환경 로컬 이미지 빌드${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 사용법 출력
usage() {
    echo "사용법: $0 <service>"
    echo ""
    echo "서비스:"
    echo "  all                    - 모든 서비스 빌드"
    echo "  servers                - 모든 백엔드 서버 빌드"
    echo "  clients                - 모든 프론트엔드 클라이언트 빌드"
    echo ""
    echo "  백엔드:"
    echo "    auth-server          - 인증 서버"
    echo "    authz-server         - 권한 서버"
    echo "    portal-server        - 포털 서버"
    echo "    my-pick-server       - MyPick 서버"
    echo ""
    echo "  프론트엔드:"
    echo "    auth-client          - 인증 클라이언트"
    echo "    portal-client        - 포털 클라이언트"
    echo "    portal-admin-client  - 포털 관리자 클라이언트"
    echo "    my-pick-client       - MyPick 클라이언트"
    echo "    my-pick-admin-client - MyPick 관리자 클라이언트"
    echo ""
    echo "예시:"
    echo "  $0 all                # 모든 서비스 빌드"
    echo "  $0 servers            # 백엔드만 빌드"
    echo "  $0 auth-server        # auth-server만 빌드"
    exit 1
}

# 인자 확인
if [ $# -ne 1 ]; then
    usage
fi

SERVICE=$1

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_ROOT="$(cd "${K8S_ROOT}/.." && pwd)"

echo -e "${BLUE}프로젝트 루트:${NC} $INFRA_ROOT"
echo ""

# k3s 설치 확인
K8S_RUNTIME=""
if command -v k3s &> /dev/null; then
    K8S_RUNTIME="k3s"
    echo -e "${GREEN}✓${NC} k3s 감지됨"
elif command -v minikube &> /dev/null && minikube status &> /dev/null; then
    K8S_RUNTIME="minikube"
    echo -e "${GREEN}✓${NC} minikube 감지됨"
elif command -v kind &> /dev/null; then
    K8S_RUNTIME="kind"
    echo -e "${GREEN}✓${NC} kind 감지됨"
else
    echo -e "${YELLOW}⚠${NC} Kubernetes 런타임을 감지하지 못했습니다."
    echo -e "${YELLOW}Docker 이미지만 빌드하고 import는 수동으로 수행하세요.${NC}"
    K8S_RUNTIME="none"
fi
echo ""

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    echo -e "${RED}오류: Docker가 설치되어 있지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker 설치 확인 완료"
echo ""

# 빌드할 서비스 목록 설정
declare -a BACKEND_SERVICES=("auth-server" "authz-server" "portal-server" "my-pick-server")
declare -a FRONTEND_SERVICES=("auth-client" "portal-client" "portal-admin-client" "my-pick-client" "my-pick-admin-client")
declare -a SERVICES

case $SERVICE in
    all)
        SERVICES=("${BACKEND_SERVICES[@]}" "${FRONTEND_SERVICES[@]}")
        ;;
    servers)
        SERVICES=("${BACKEND_SERVICES[@]}")
        ;;
    clients)
        SERVICES=("${FRONTEND_SERVICES[@]}")
        ;;
    auth-server|authz-server|portal-server|my-pick-server|auth-client|portal-client|portal-admin-client|my-pick-client|my-pick-admin-client)
        SERVICES=("$SERVICE")
        ;;
    *)
        echo -e "${RED}오류: 지원하지 않는 서비스입니다: $SERVICE${NC}"
        usage
        ;;
esac

# 빌드 확인
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}빌드 정보 확인${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "빌드할 서비스 (${#SERVICES[@]}개):"
for svc in "${SERVICES[@]}"; do
    echo -e "  - ${CYAN}$svc${NC}"
done
echo -e "Kubernetes 런타임: ${CYAN}$K8S_RUNTIME${NC}"
echo ""

read -p "빌드를 진행하시겠습니까? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}빌드가 취소되었습니다.${NC}"
    exit 0
fi
echo ""

# 이미지 빌드 함수
build_image() {
    local service=$1
    local service_path="${INFRA_ROOT}/${service}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}빌드 중: $service${NC}"
    echo -e "${BLUE}========================================${NC}"

    # 서비스 디렉토리 확인
    if [ ! -d "$service_path" ]; then
        echo -e "${RED}✗ 오류: 디렉토리를 찾을 수 없습니다: $service_path${NC}"
        return 1
    fi

    echo -e "${CYAN}경로:${NC} $service_path"

    # Dockerfile 확인
    if [ ! -f "$service_path/Dockerfile" ]; then
        echo -e "${RED}✗ 오류: Dockerfile을 찾을 수 없습니다: $service_path/Dockerfile${NC}"
        return 1
    fi

    # Docker 이미지 빌드
    echo -e "${CYAN}Docker 이미지 빌드 중...${NC}"

    # 빌드 시간 측정
    local start_time=$(date +%s)

    if cd "$service_path" && docker build -t "${service}:latest" -t "${service}:dev" .; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓${NC} Docker 이미지 빌드 완료 (${duration}초)"
    else
        echo -e "${RED}✗${NC} Docker 이미지 빌드 실패"
        return 1
    fi

    # k8s에 이미지 import
    if [ "$K8S_RUNTIME" != "none" ]; then
        echo -e "${CYAN}Kubernetes에 이미지 import 중...${NC}"

        case $K8S_RUNTIME in
            k3s)
                # k3s는 sudo 권한 필요
                if docker save "${service}:latest" | sudo k3s ctr images import -; then
                    echo -e "${GREEN}✓${NC} k3s에 이미지 import 완료"
                else
                    echo -e "${YELLOW}⚠${NC} k3s import 실패 (수동으로 import 필요)"
                fi
                ;;
            minikube)
                # minikube는 별도 Docker daemon 사용
                if minikube image load "${service}:latest"; then
                    echo -e "${GREEN}✓${NC} minikube에 이미지 로드 완료"
                else
                    echo -e "${YELLOW}⚠${NC} minikube 로드 실패"
                fi
                ;;
            kind)
                # kind는 클러스터명 필요 (기본: kind)
                if kind load docker-image "${service}:latest"; then
                    echo -e "${GREEN}✓${NC} kind에 이미지 로드 완료"
                else
                    echo -e "${YELLOW}⚠${NC} kind 로드 실패"
                fi
                ;;
        esac
    fi

    echo ""
    return 0
}

# 빌드 실행
FAILED_SERVICES=()
SUCCESSFUL_SERVICES=()
TOTAL_START_TIME=$(date +%s)

for service in "${SERVICES[@]}"; do
    if build_image "$service"; then
        SUCCESSFUL_SERVICES+=("$service")
    else
        FAILED_SERVICES+=("$service")
        echo -e "${RED}$service 빌드 중 오류가 발생했습니다. 계속 진행합니다.${NC}"
        echo ""
    fi
done

TOTAL_END_TIME=$(date +%s)
TOTAL_DURATION=$((TOTAL_END_TIME - TOTAL_START_TIME))

# 빌드 결과 요약
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}빌드 결과 요약${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "총 빌드 시도: ${CYAN}${#SERVICES[@]}개${NC}"
echo -e "${GREEN}성공: ${#SUCCESSFUL_SERVICES[@]}개${NC}"
echo -e "${RED}실패: ${#FAILED_SERVICES[@]}개${NC}"
echo -e "총 소요 시간: ${CYAN}${TOTAL_DURATION}초${NC}"
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

# 이미지 확인
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}빌드된 이미지 확인${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${CYAN}Docker 이미지:${NC}"
docker images | grep -E "REPOSITORY|$(IFS=\|; echo "${SUCCESSFUL_SERVICES[*]}")" || echo "  (이미지 없음)"
echo ""

if [ "$K8S_RUNTIME" = "k3s" ]; then
    echo -e "${CYAN}k3s 이미지:${NC}"
    sudo k3s crictl images | grep -E "IMAGE|$(IFS=\|; echo "${SUCCESSFUL_SERVICES[*]}")" || echo "  (이미지 없음)"
    echo ""
elif [ "$K8S_RUNTIME" = "minikube" ]; then
    echo -e "${CYAN}minikube 이미지:${NC}"
    minikube image ls | grep -E "$(IFS=\|; echo "${SUCCESSFUL_SERVICES[*]}")" || echo "  (이미지 없음)"
    echo ""
fi

# 다음 단계 안내
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}다음 단계${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}1. 이미지 확인${NC}"
if [ "$K8S_RUNTIME" = "k3s" ]; then
    echo "   sudo k3s crictl images | grep <service-name>"
elif [ "$K8S_RUNTIME" = "minikube" ]; then
    echo "   minikube image ls | grep <service-name>"
elif [ "$K8S_RUNTIME" = "kind" ]; then
    echo "   docker exec -it kind-control-plane crictl images | grep <service-name>"
else
    echo "   docker images | grep <service-name>"
fi
echo ""
echo -e "${YELLOW}2. Dev 환경 배포${NC}"
echo "   cd ${K8S_ROOT}"
echo "   ./scripts/deploy.sh dev all"
echo ""
echo -e "${YELLOW}3. 특정 서비스만 배포${NC}"
echo "   ./scripts/deploy.sh dev auth-server"
echo ""
echo -e "${YELLOW}4. Pod 상태 확인${NC}"
echo "   kubectl get pods -n krgeobuk-dev -w"
echo ""

# 수동 import 안내 (k8s 런타임 미감지 시)
if [ "$K8S_RUNTIME" = "none" ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}수동 Import 방법${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "${CYAN}k3s:${NC}"
    echo "  docker save <service>:latest | sudo k3s ctr images import -"
    echo ""
    echo -e "${CYAN}minikube:${NC}"
    echo "  minikube image load <service>:latest"
    echo ""
    echo -e "${CYAN}kind:${NC}"
    echo "  kind load docker-image <service>:latest"
    echo ""
fi

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo -e "${RED}⚠️  일부 서비스 빌드가 실패했습니다.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ 모든 서비스 빌드가 완료되었습니다!${NC}"
    exit 0
fi
