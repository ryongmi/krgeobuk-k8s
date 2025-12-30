#!/bin/bash

#####################################################################
# krgeobuk Phase 3 준비 자동화 (간소화 버전)
#
# 설명: 테스트용 더미 값으로 Phase 3 검증에 필요한 모든 파일 생성
# 사용법: ./setup-phase3-simple.sh
#
# 주의: 이 스크립트는 테스트 목적으로만 사용하세요.
#       실제 배포에는 setup-phase3-full.sh를 사용하세요.
#####################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Phase 3 준비 자동화 (간소화 버전)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}⚠ 경고: 테스트용 더미 값을 사용합니다.${NC}"
echo -e "${YELLOW}   실제 배포에는 setup-phase3-full.sh를 사용하세요.${NC}"
echo ""

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_ROOT="$(cd "${K8S_ROOT}/../krgeobuk-infrastructure" && pwd)"

# 더미 값 설정
MYSQL_PASSWORD="test1234"
REDIS_PASSWORD="test1234"
GOOGLE_CLIENT_SECRET="dummy-google-secret-12345678"
NAVER_CLIENT_SECRET="dummy-naver-secret-12345678"
SMTP_USER="test@example.com"
SMTP_PASS="dummy-smtp-password"
YOUTUBE_API_KEY="dummy-youtube-api-key"
TWITTER_API_KEY="dummy-twitter-api-key"
TWITTER_API_KEY_SECRET="dummy-twitter-api-secret"
TWITTER_BEARER_TOKEN="dummy-twitter-bearer-token"
EXTERNAL_MYSQL_IP="127.0.0.1"
EXTERNAL_REDIS_AUTH_IP="127.0.0.1"
EXTERNAL_REDIS_AUTHZ_IP="127.0.0.1"

# 간단한 테스트용 JWT 키 생성
generate_test_jwt_keys() {
    local output_dir=$1
    mkdir -p "$output_dir"

    # 테스트용 RSA 키 생성 (2048 bit)
    openssl genrsa -out "${output_dir}/access-private.key" 2048 2>/dev/null
    openssl rsa -in "${output_dir}/access-private.key" -pubout -out "${output_dir}/access-public.key" 2>/dev/null
    openssl genrsa -out "${output_dir}/refresh-private.key" 2048 2>/dev/null
    openssl rsa -in "${output_dir}/refresh-private.key" -pubout -out "${output_dir}/refresh-public.key" 2>/dev/null
}

#####################################################################
# 1. krgeobuk-infrastructure/.env 생성
#####################################################################

echo -e "${BLUE}1. krgeobuk-infrastructure/.env 생성 중...${NC}"

cat > "${INFRA_ROOT}/.env" << EOF
# MySQL 설정
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Redis 설정
REDIS_PASSWORD=${REDIS_PASSWORD}

# Jenkins 설정
JENKINS_ADMIN_PASSWORD=admin1234
EOF

echo -e "${GREEN}✓ .env 파일 생성 완료${NC}"
echo ""

#####################################################################
# 2. Secret YAML 파일 생성
#####################################################################

echo -e "${BLUE}2. Secret YAML 파일 생성 중...${NC}"

# 2.1 auth-server secret
echo -e "${YELLOW}  - auth-server secret 생성 중...${NC}"
mkdir -p /tmp/jwt-keys-auth
generate_test_jwt_keys /tmp/jwt-keys-auth

cat > "${K8S_ROOT}/applications/auth-server/secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: auth-server-secrets
  labels:
    app: auth-server
type: Opaque
stringData:
  MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
  GOOGLE_CLIENT_SECRET: "${GOOGLE_CLIENT_SECRET}"
  NAVER_CLIENT_SECRET: "${NAVER_CLIENT_SECRET}"
  SMTP_USER: "${SMTP_USER}"
  SMTP_PASS: "${SMTP_PASS}"
---
apiVersion: v1
kind: Secret
metadata:
  name: auth-server-jwt-keys
  labels:
    app: auth-server
type: Opaque
stringData:
  access-private.key: |
$(sed 's/^/    /' /tmp/jwt-keys-auth/access-private.key)
  access-public.key: |
$(sed 's/^/    /' /tmp/jwt-keys-auth/access-public.key)
  refresh-private.key: |
$(sed 's/^/    /' /tmp/jwt-keys-auth/refresh-private.key)
  refresh-public.key: |
$(sed 's/^/    /' /tmp/jwt-keys-auth/refresh-public.key)
EOF

echo -e "${GREEN}  ✓ auth-server secret 생성 완료${NC}"

# 2.2 authz-server secret
echo -e "${YELLOW}  - authz-server secret 생성 중...${NC}"

cat > "${K8S_ROOT}/applications/authz-server/secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: authz-server-secrets
  labels:
    app: authz-server
type: Opaque
stringData:
  MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
---
apiVersion: v1
kind: Secret
metadata:
  name: authz-server-jwt-keys
  labels:
    app: authz-server
type: Opaque
stringData:
  access-public.key: |
$(sed 's/^/    /' /tmp/jwt-keys-auth/access-public.key)
EOF

echo -e "${GREEN}  ✓ authz-server secret 생성 완료${NC}"

# 2.3 portal-server secret
echo -e "${YELLOW}  - portal-server secret 생성 중...${NC}"

cat > "${K8S_ROOT}/applications/portal-server/secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: portal-server-secrets
  labels:
    app: portal-server
type: Opaque
stringData:
  MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
---
apiVersion: v1
kind: Secret
metadata:
  name: portal-server-jwt-keys
  labels:
    app: portal-server
type: Opaque
stringData:
  access-public.key: |
$(sed 's/^/    /' /tmp/jwt-keys-auth/access-public.key)
EOF

echo -e "${GREEN}  ✓ portal-server secret 생성 완료${NC}"

# 2.4 my-pick-server secret
echo -e "${YELLOW}  - my-pick-server secret 생성 중...${NC}"

cat > "${K8S_ROOT}/applications/my-pick-server/secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-pick-server-secrets
  labels:
    app: my-pick-server
type: Opaque
stringData:
  MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
  YOUTUBE_API_KEY: "${YOUTUBE_API_KEY}"
  TWITTER_API_KEY: "${TWITTER_API_KEY}"
  TWITTER_API_KEY_SECRET: "${TWITTER_API_KEY_SECRET}"
  TWITTER_BEARER_TOKEN: "${TWITTER_BEARER_TOKEN}"
---
apiVersion: v1
kind: Secret
metadata:
  name: my-pick-server-jwt-keys
  labels:
    app: my-pick-server
type: Opaque
stringData:
  access-public.key: |
$(sed 's/^/    /' /tmp/jwt-keys-auth/access-public.key)
EOF

echo -e "${GREEN}  ✓ my-pick-server secret 생성 완료${NC}"

# JWT 키 임시 파일 정리
rm -rf /tmp/jwt-keys-auth

echo ""

#####################################################################
# 3. External Service IP 업데이트
#####################################################################

echo -e "${BLUE}3. External Service IP 업데이트 중...${NC}"

# 3.1 external-mysql.yaml
echo -e "${YELLOW}  - external-mysql.yaml 업데이트 중...${NC}"

cat > "${K8S_ROOT}/base/external-mysql.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: krgeobuk-mysql
spec:
  type: ExternalName
  externalName: ${EXTERNAL_MYSQL_IP}
  ports:
    - name: mysql-auth
      port: 3307
      targetPort: 3307
    - name: mysql-authz
      port: 3308
      targetPort: 3308
    - name: mysql-portal
      port: 3309
      targetPort: 3309
    - name: mysql-mypick
      port: 3310
      targetPort: 3310
EOF

echo -e "${GREEN}  ✓ external-mysql.yaml 업데이트 완료${NC}"

# 3.2 external-redis.yaml
echo -e "${YELLOW}  - external-redis.yaml 업데이트 중...${NC}"

cat > "${K8S_ROOT}/base/external-redis.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: krgeobuk-redis-auth
spec:
  type: ExternalName
  externalName: ${EXTERNAL_REDIS_AUTH_IP}
  ports:
    - name: redis
      port: 6380
      targetPort: 6380
---
apiVersion: v1
kind: Service
metadata:
  name: krgeobuk-redis-authz
spec:
  type: ExternalName
  externalName: ${EXTERNAL_REDIS_AUTHZ_IP}
  ports:
    - name: redis
      port: 6381
      targetPort: 6381
EOF

echo -e "${GREEN}  ✓ external-redis.yaml 업데이트 완료${NC}"

echo ""

#####################################################################
# 4. 생성된 파일 확인
#####################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}생성된 파일 확인${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${GREEN}✓ krgeobuk-infrastructure/.env${NC}"
echo -e "${GREEN}✓ applications/auth-server/secret.yaml${NC}"
echo -e "${GREEN}✓ applications/authz-server/secret.yaml${NC}"
echo -e "${GREEN}✓ applications/portal-server/secret.yaml${NC}"
echo -e "${GREEN}✓ applications/my-pick-server/secret.yaml${NC}"
echo -e "${GREEN}✓ base/external-mysql.yaml${NC}"
echo -e "${GREEN}✓ base/external-redis.yaml${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}생성된 더미 값 정보${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "MySQL Root Password: ${YELLOW}${MYSQL_ROOT_PASSWORD}${NC}"
echo -e "MySQL Password: ${YELLOW}${MYSQL_PASSWORD}${NC}"
echo -e "Redis Password: ${YELLOW}${REDIS_PASSWORD}${NC}"
echo -e "External MySQL IP: ${YELLOW}${EXTERNAL_MYSQL_IP}${NC}"
echo -e "External Redis IP: ${YELLOW}${EXTERNAL_REDIS_AUTH_IP}, ${EXTERNAL_REDIS_AUTHZ_IP}${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Phase 3 준비 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}다음 단계:${NC}"
echo -e "  1. Kustomize 빌드 테스트:"
echo -e "     ${BLUE}cd ${K8S_ROOT}/environments/dev && kustomize build .${NC}"
echo -e "  2. Dry-run 검증:"
echo -e "     ${BLUE}kubectl apply -k ${K8S_ROOT}/environments/dev --dry-run=client${NC}"
echo ""
echo -e "${YELLOW}⚠ 주의사항:${NC}"
echo -e "  - 이 설정은 테스트 목적으로만 사용하세요"
echo -e "  - 실제 배포에는 setup-phase3-full.sh를 사용하세요"
echo -e "  - secret.yaml 파일은 절대 Git에 커밋하지 마세요"
echo ""
