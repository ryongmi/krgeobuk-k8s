#!/bin/bash

#####################################################################
# krgeobuk Phase 3 준비 자동화 (전체 버전)
#
# 설명: 실제 배포용 값을 대화형으로 입력받아 모든 설정 파일 생성
# 사용법: ./setup-phase3-full.sh
#
# 주의: 실제 배포에 사용할 값을 입력하세요.
#       테스트용으로는 setup-phase3-simple.sh를 사용하세요.
#####################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Phase 3 준비 자동화 (전체 버전)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}실제 배포에 사용할 값을 입력받습니다.${NC}"
echo -e "${YELLOW}각 항목에 대해 안전한 값을 입력하세요.${NC}"
echo ""

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_ROOT="$(cd "${K8S_ROOT}/../krgeobuk-infrastructure" && pwd)"

#####################################################################
# 유틸리티 함수
#####################################################################

# 사용자 입력 받기 (기본값 지원)
prompt_input() {
    local prompt=$1
    local default=$2
    local var_name=$3
    local is_secret=${4:-false}

    if [ -n "$default" ]; then
        echo -ne "${BLUE}${prompt} [${default}]: ${NC}"
    else
        echo -ne "${BLUE}${prompt}: ${NC}"
    fi

    if [ "$is_secret" = true ]; then
        read -s input_value
        echo ""
    else
        read input_value
    fi

    if [ -z "$input_value" ] && [ -n "$default" ]; then
        input_value="$default"
    fi

    eval "$var_name='$input_value'"
}

# 비밀번호 검증 (최소 8자)
validate_password() {
    local password=$1
    if [ ${#password} -lt 8 ]; then
        echo -e "${RED}✗ 비밀번호는 최소 8자 이상이어야 합니다.${NC}"
        return 1
    fi
    return 0
}

# 이메일 검증
validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}✗ 올바른 이메일 형식이 아닙니다.${NC}"
        return 1
    fi
    return 0
}

# JWT 키 생성
generate_jwt_keys() {
    local output_dir=$1
    mkdir -p "$output_dir"

    echo -e "${YELLOW}  JWT 키 쌍 생성 중...${NC}"

    # 4096 bit RSA 키 생성
    openssl genrsa -out "${output_dir}/access-private.key" 4096 2>/dev/null
    openssl rsa -in "${output_dir}/access-private.key" -pubout -out "${output_dir}/access-public.key" 2>/dev/null
    openssl genrsa -out "${output_dir}/refresh-private.key" 4096 2>/dev/null
    openssl rsa -in "${output_dir}/refresh-private.key" -pubout -out "${output_dir}/refresh-public.key" 2>/dev/null

    echo -e "${GREEN}  ✓ JWT 키 생성 완료${NC}"
}

# NextAuth Secret 생성
generate_nextauth_secret() {
    openssl rand -base64 32
}

#####################################################################
# 1. MySQL 설정
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}1. MySQL 설정${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

while true; do
    prompt_input "MySQL Root 비밀번호" "" MYSQL_ROOT_PASSWORD true
    if validate_password "$MYSQL_ROOT_PASSWORD"; then
        break
    fi
done

while true; do
    prompt_input "MySQL 사용자 비밀번호" "" MYSQL_PASSWORD true
    if validate_password "$MYSQL_PASSWORD"; then
        break
    fi
done

echo ""

#####################################################################
# 2. Redis 설정
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}2. Redis 설정${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

while true; do
    prompt_input "Redis 비밀번호" "" REDIS_PASSWORD true
    if validate_password "$REDIS_PASSWORD"; then
        break
    fi
done

echo ""

#####################################################################
# 3. OAuth 설정
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}3. OAuth 설정${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Google Cloud Console 및 Naver Developers에서 발급받은 Client Secret을 입력하세요.${NC}"
echo -e "${YELLOW}테스트용으로는 엔터를 눌러 더미 값을 사용할 수 있습니다.${NC}"
echo ""

prompt_input "Google Client Secret" "dummy-google-secret-for-testing" GOOGLE_CLIENT_SECRET true
prompt_input "Naver Client Secret" "dummy-naver-secret-for-testing" NAVER_CLIENT_SECRET true

echo ""

#####################################################################
# 4. SMTP 설정
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}4. SMTP 설정 (이메일 전송용)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Gmail의 경우 앱 비밀번호를 사용하세요.${NC}"
echo -e "${YELLOW}테스트용으로는 엔터를 눌러 더미 값을 사용할 수 있습니다.${NC}"
echo ""

while true; do
    prompt_input "SMTP 사용자 (이메일)" "test@example.com" SMTP_USER false
    if [ "$SMTP_USER" = "test@example.com" ] || validate_email "$SMTP_USER"; then
        break
    fi
done

prompt_input "SMTP 비밀번호" "dummy-smtp-password" SMTP_PASS true

echo ""

#####################################################################
# 5. Jenkins 설정
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}5. Jenkins 설정${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

while true; do
    prompt_input "Jenkins Admin 비밀번호" "" JENKINS_ADMIN_PASSWORD true
    if validate_password "$JENKINS_ADMIN_PASSWORD"; then
        break
    fi
done

echo ""

#####################################################################
# 6. External Service IP 설정
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}6. External Service IP 설정${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Docker가 실행 중인 호스트 머신의 IP 주소를 입력하세요.${NC}"
echo -e "${YELLOW}로컬 테스트: 127.0.0.1 또는 host.docker.internal${NC}"
echo -e "${YELLOW}원격 서버: 실제 IP 주소 (예: 192.168.1.100)${NC}"
echo ""

prompt_input "MySQL 서버 IP" "127.0.0.1" EXTERNAL_MYSQL_IP false
prompt_input "Redis (auth) 서버 IP" "$EXTERNAL_MYSQL_IP" EXTERNAL_REDIS_AUTH_IP false
prompt_input "Redis (authz) 서버 IP" "$EXTERNAL_MYSQL_IP" EXTERNAL_REDIS_AUTHZ_IP false

echo ""

#####################################################################
# 7. 설정 확인
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}설정 확인${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "MySQL Root Password: ${YELLOW}[HIDDEN]${NC}"
echo -e "MySQL Password: ${YELLOW}[HIDDEN]${NC}"
echo -e "Redis Password: ${YELLOW}[HIDDEN]${NC}"
echo -e "Google Client Secret: ${YELLOW}[HIDDEN]${NC}"
echo -e "Naver Client Secret: ${YELLOW}[HIDDEN]${NC}"
echo -e "SMTP User: ${YELLOW}${SMTP_USER}${NC}"
echo -e "SMTP Password: ${YELLOW}[HIDDEN]${NC}"
echo -e "Jenkins Admin Password: ${YELLOW}[HIDDEN]${NC}"
echo -e "External MySQL IP: ${YELLOW}${EXTERNAL_MYSQL_IP}${NC}"
echo -e "External Redis (auth) IP: ${YELLOW}${EXTERNAL_REDIS_AUTH_IP}${NC}"
echo -e "External Redis (authz) IP: ${YELLOW}${EXTERNAL_REDIS_AUTHZ_IP}${NC}"
echo ""

read -p "이 설정으로 진행하시겠습니까? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}설정이 취소되었습니다.${NC}"
    exit 0
fi

echo ""

#####################################################################
# 8. 파일 생성
#####################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}파일 생성 중...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 8.1 krgeobuk-infrastructure/.env 생성
echo -e "${YELLOW}1. krgeobuk-infrastructure/.env 생성 중...${NC}"

cat > "${INFRA_ROOT}/.env" << EOF
# MySQL 설정
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Redis 설정
REDIS_PASSWORD=${REDIS_PASSWORD}

# Jenkins 설정
JENKINS_ADMIN_PASSWORD=${JENKINS_ADMIN_PASSWORD}
EOF

echo -e "${GREEN}✓ .env 파일 생성 완료${NC}"
echo ""

# 8.2 auth-server secret
echo -e "${YELLOW}2. auth-server secret 생성 중...${NC}"
mkdir -p /tmp/jwt-keys-auth
generate_jwt_keys /tmp/jwt-keys-auth

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
  MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
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

echo -e "${GREEN}✓ auth-server secret 생성 완료${NC}"
echo ""

# 8.3 authz-server secret
echo -e "${YELLOW}3. authz-server secret 생성 중...${NC}"
mkdir -p /tmp/jwt-keys-authz
generate_jwt_keys /tmp/jwt-keys-authz

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
  MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
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
  access-private.key: |
$(sed 's/^/    /' /tmp/jwt-keys-authz/access-private.key)
  access-public.key: |
$(sed 's/^/    /' /tmp/jwt-keys-authz/access-public.key)
  refresh-private.key: |
$(sed 's/^/    /' /tmp/jwt-keys-authz/refresh-private.key)
  refresh-public.key: |
$(sed 's/^/    /' /tmp/jwt-keys-authz/refresh-public.key)
EOF

echo -e "${GREEN}✓ authz-server secret 생성 완료${NC}"
echo ""

# 8.4 portal-server secret
echo -e "${YELLOW}4. portal-server secret 생성 중...${NC}"

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
  MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
EOF

echo -e "${GREEN}✓ portal-server secret 생성 완료${NC}"
echo ""

# 8.5 my-pick-server secret
echo -e "${YELLOW}5. my-pick-server secret 생성 중...${NC}"

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
  MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
EOF

echo -e "${GREEN}✓ my-pick-server secret 생성 완료${NC}"
echo ""

# JWT 키 임시 파일 정리
rm -rf /tmp/jwt-keys-auth /tmp/jwt-keys-authz

# 8.6 External Service IP 업데이트
echo -e "${YELLOW}6. External Service IP 업데이트 중...${NC}"

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

echo -e "${GREEN}✓ External Service IP 업데이트 완료${NC}"
echo ""

#####################################################################
# 9. 완료
#####################################################################

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Phase 3 준비 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}생성된 파일:${NC}"
echo -e "${GREEN}✓ krgeobuk-infrastructure/.env${NC}"
echo -e "${GREEN}✓ applications/auth-server/secret.yaml${NC}"
echo -e "${GREEN}✓ applications/authz-server/secret.yaml${NC}"
echo -e "${GREEN}✓ applications/portal-server/secret.yaml${NC}"
echo -e "${GREEN}✓ applications/my-pick-server/secret.yaml${NC}"
echo -e "${GREEN}✓ base/external-mysql.yaml${NC}"
echo -e "${GREEN}✓ base/external-redis.yaml${NC}"

echo ""
echo -e "${YELLOW}다음 단계:${NC}"
echo -e "  1. 인프라 시작:"
echo -e "     ${BLUE}cd ${INFRA_ROOT}/scripts && ./start-all.sh${NC}"
echo -e ""
echo -e "  2. Kustomize 빌드 테스트:"
echo -e "     ${BLUE}cd ${K8S_ROOT}/environments/dev && kustomize build .${NC}"
echo -e ""
echo -e "  3. Dry-run 검증:"
echo -e "     ${BLUE}kubectl apply -k ${K8S_ROOT}/environments/dev --dry-run=client${NC}"
echo -e ""
echo -e "  4. 실제 배포 (선택사항):"
echo -e "     ${BLUE}kubectl apply -k ${K8S_ROOT}/environments/dev${NC}"
echo ""

echo -e "${RED}⚠ 보안 주의사항:${NC}"
echo -e "  - secret.yaml 파일은 절대 Git에 커밋하지 마세요"
echo -e "  - .env 파일은 절대 Git에 커밋하지 마세요"
echo -e "  - 프로덕션 환경에는 더 강력한 비밀번호를 사용하세요"
echo -e "  - JWT 키는 안전하게 백업하세요"
echo ""
