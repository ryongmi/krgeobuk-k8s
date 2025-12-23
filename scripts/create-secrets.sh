#!/bin/bash

# Secret YAML 생성 스크립트
# .env 파일을 읽어서 Kubernetes Secret YAML 파일을 자동 생성

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes Secret YAML 생성 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 사용법 출력
usage() {
    echo "사용법: $0 <service-name> <env-file>"
    echo ""
    echo "예시:"
    echo "  $0 auth-server .env"
    echo "  $0 my-pick-server .env.prod"
    echo ""
    echo "지원 서비스:"
    echo "  - auth-server"
    echo "  - authz-server"
    echo "  - portal-server"
    echo "  - my-pick-server"
    echo "  - my-pick-client"
    exit 1
}

# 인자 확인
if [ $# -ne 2 ]; then
    usage
fi

SERVICE=$1
ENV_FILE=$2

# 환경 파일 존재 확인
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}오류: 환경 파일을 찾을 수 없습니다: $ENV_FILE${NC}"
    exit 1
fi

# 환경 변수 로드
echo -e "${BLUE}환경 파일 로드:${NC} $ENV_FILE"
source "$ENV_FILE"
echo -e "${GREEN}✓${NC} 환경 변수 로드 완료"
echo ""

# 출력 디렉토리
OUTPUT_DIR="applications/$SERVICE"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}오류: 서비스 디렉토리를 찾을 수 없습니다: $OUTPUT_DIR${NC}"
    exit 1
fi

OUTPUT_FILE="$OUTPUT_DIR/secret.yaml"

# 기존 파일 백업
if [ -f "$OUTPUT_FILE" ]; then
    BACKUP_FILE="$OUTPUT_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$OUTPUT_FILE" "$BACKUP_FILE"
    echo -e "${YELLOW}기존 파일 백업:${NC} $BACKUP_FILE"
fi

# Base64 인코딩 함수
base64_encode() {
    echo -n "$1" | base64 -w 0 2>/dev/null || echo -n "$1" | base64
}

# Secret YAML 생성
echo -e "${BLUE}Secret YAML 생성 중...${NC}"
echo ""

case $SERVICE in
    auth-server)
        cat > "$OUTPUT_FILE" << EOF
# auth-server Secrets
# 자동 생성됨: $(date)
# 주의: 이 파일을 Git에 커밋하지 마세요!

apiVersion: v1
kind: Secret
metadata:
  name: auth-server-secrets
  labels:
    app: auth-server
type: Opaque
data:
  MYSQL_PASSWORD: $(base64_encode "${MYSQL_PASSWORD}")
  REDIS_PASSWORD: $(base64_encode "${REDIS_PASSWORD}")
  GOOGLE_CLIENT_SECRET: $(base64_encode "${GOOGLE_CLIENT_SECRET}")
  NAVER_CLIENT_SECRET: $(base64_encode "${NAVER_CLIENT_SECRET}")
  SMTP_USER: $(base64_encode "${SMTP_USER}")
  SMTP_PASS: $(base64_encode "${SMTP_PASS}")

---
# JWT 키 파일을 위한 Secret
apiVersion: v1
kind: Secret
metadata:
  name: auth-server-jwt-keys
  labels:
    app: auth-server
type: Opaque
data:
  access-private.key: $(cat jwt-keys/access-private.key | base64 -w 0)
  access-public.key: $(cat jwt-keys/access-public.key | base64 -w 0)
  refresh-private.key: $(cat jwt-keys/refresh-private.key | base64 -w 0)
  refresh-public.key: $(cat jwt-keys/refresh-public.key | base64 -w 0)
EOF
        ;;

    authz-server)
        cat > "$OUTPUT_FILE" << EOF
# authz-server Secrets
# 자동 생성됨: $(date)

apiVersion: v1
kind: Secret
metadata:
  name: authz-server-secrets
  labels:
    app: authz-server
type: Opaque
data:
  MYSQL_PASSWORD: $(base64_encode "${MYSQL_PASSWORD}")
  REDIS_PASSWORD: $(base64_encode "${REDIS_PASSWORD}")

---
# JWT Public Keys (auth-server에서 복사)
apiVersion: v1
kind: Secret
metadata:
  name: authz-server-jwt-keys
  labels:
    app: authz-server
type: Opaque
data:
  access-public.key: $(cat jwt-keys/access-public.key | base64 -w 0)
  refresh-public.key: $(cat jwt-keys/refresh-public.key | base64 -w 0)
EOF
        ;;

    portal-server)
        cat > "$OUTPUT_FILE" << EOF
# portal-server Secrets
# 자동 생성됨: $(date)

apiVersion: v1
kind: Secret
metadata:
  name: portal-server-secrets
  labels:
    app: portal-server
type: Opaque
data:
  MYSQL_PASSWORD: $(base64_encode "${MYSQL_PASSWORD}")
  REDIS_PASSWORD: $(base64_encode "${REDIS_PASSWORD}")

---
# JWT Public Keys (auth-server에서 복사)
apiVersion: v1
kind: Secret
metadata:
  name: portal-server-jwt-keys
  labels:
    app: portal-server
type: Opaque
data:
  access-public.key: $(cat jwt-keys/access-public.key | base64 -w 0)
  refresh-public.key: $(cat jwt-keys/refresh-public.key | base64 -w 0)
EOF
        ;;

    my-pick-server)
        cat > "$OUTPUT_FILE" << EOF
# my-pick-server Secrets
# 자동 생성됨: $(date)

apiVersion: v1
kind: Secret
metadata:
  name: my-pick-server-secrets
  labels:
    app: my-pick-server
type: Opaque
data:
  MYSQL_PASSWORD: $(base64_encode "${MYSQL_PASSWORD}")
  REDIS_PASSWORD: $(base64_encode "${REDIS_PASSWORD}")
  YOUTUBE_API_KEY: $(base64_encode "${YOUTUBE_API_KEY}")
  TWITTER_BEARER_TOKEN: $(base64_encode "${TWITTER_BEARER_TOKEN}")

---
# JWT Public Keys (auth-server에서 복사)
apiVersion: v1
kind: Secret
metadata:
  name: my-pick-server-jwt-keys
  labels:
    app: my-pick-server
type: Opaque
data:
  access-public.key: $(cat jwt-keys/access-public.key | base64 -w 0)
  refresh-public.key: $(cat jwt-keys/refresh-public.key | base64 -w 0)
EOF
        ;;

    my-pick-client)
        cat > "$OUTPUT_FILE" << EOF
# my-pick-client Secrets
# 자동 생성됨: $(date)

apiVersion: v1
kind: Secret
metadata:
  name: my-pick-client-secrets
  labels:
    app: my-pick-client
type: Opaque
data:
  NEXT_PUBLIC_YOUTUBE_API_KEY: $(base64_encode "${NEXT_PUBLIC_YOUTUBE_API_KEY}")
  NEXT_PUBLIC_TWITTER_API_KEY: $(base64_encode "${NEXT_PUBLIC_TWITTER_API_KEY}")
  NEXT_PUBLIC_TWITTER_API_SECRET: $(base64_encode "${NEXT_PUBLIC_TWITTER_API_SECRET}")
  NEXT_PUBLIC_TWITTER_BEARER_TOKEN: $(base64_encode "${NEXT_PUBLIC_TWITTER_BEARER_TOKEN}")
EOF
        ;;

    *)
        echo -e "${RED}오류: 지원하지 않는 서비스입니다: $SERVICE${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓${NC} Secret YAML 생성 완료: $OUTPUT_FILE"
echo ""

# 파일 내용 미리보기 (민감한 정보 마스킹)
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}생성된 파일 미리보기${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}경로:${NC} $OUTPUT_FILE"
echo -e "${YELLOW}크기:${NC} $(wc -c < "$OUTPUT_FILE") bytes"
echo ""

# Secret 적용 방법 안내
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}다음 단계${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}1. Secret 내용 확인${NC}"
echo "   cat $OUTPUT_FILE"
echo ""
echo -e "${YELLOW}2. Secret 적용 (Dev 환경)${NC}"
echo "   kubectl apply -f $OUTPUT_FILE -n krgeobuk-dev"
echo ""
echo -e "${YELLOW}3. Secret 적용 (Prod 환경)${NC}"
echo "   kubectl apply -f $OUTPUT_FILE -n krgeobuk-prod"
echo ""
echo -e "${YELLOW}4. Secret 확인${NC}"
echo "   kubectl get secrets -n krgeobuk-dev"
echo "   kubectl describe secret $SERVICE-secrets -n krgeobuk-dev"
echo ""
echo -e "${RED}⚠️  주의: secret.yaml 파일을 Git에 커밋하지 마세요!${NC}"
echo ""
echo -e "${GREEN}✓ 작업 완료!${NC}"
