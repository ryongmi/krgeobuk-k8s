#!/bin/bash

# Secret 검증 스크립트
# 환경 파일의 필수 변수가 모두 설정되었는지 확인

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Secret 검증 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 사용법
usage() {
    echo "사용법: $0 <env-file>"
    echo ""
    echo "예시:"
    echo "  $0 .env"
    echo "  $0 .env.prod"
    exit 1
}

# 인자 확인
if [ $# -ne 1 ]; then
    usage
fi

ENV_FILE=$1

# 파일 존재 확인
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}오류: 환경 파일을 찾을 수 없습니다: $ENV_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}검증 파일:${NC} $ENV_FILE"
echo ""

# 환경 변수 로드
source "$ENV_FILE"

# 검증 결과
TOTAL=0
PASS=0
FAIL=0

# 변수 검증 함수
check_var() {
    local var_name=$1
    local var_value=${!var_name}
    TOTAL=$((TOTAL + 1))

    if [ -z "$var_value" ]; then
        echo -e "${RED}✗${NC} $var_name: ${RED}미설정${NC}"
        FAIL=$((FAIL + 1))
        return 1
    elif [ "$var_value" == "your-"* ] || [ "$var_value" == "YOUR_"* ]; then
        echo -e "${YELLOW}⚠${NC} $var_name: ${YELLOW}기본값 (수정 필요)${NC}"
        FAIL=$((FAIL + 1))
        return 1
    else
        echo -e "${GREEN}✓${NC} $var_name: ${GREEN}설정됨${NC}"
        PASS=$((PASS + 1))
        return 0
    fi
}

# 필수 변수 검증
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}공통 변수 검증${NC}"
echo -e "${BLUE}========================================${NC}"
check_var "MYSQL_PASSWORD"
check_var "REDIS_PASSWORD"
echo ""

# auth-server 특정 변수
if grep -q "GOOGLE_CLIENT_SECRET" "$ENV_FILE" 2>/dev/null; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}auth-server 변수 검증${NC}"
    echo -e "${BLUE}========================================${NC}"
    check_var "GOOGLE_CLIENT_SECRET"
    check_var "NAVER_CLIENT_SECRET"
    check_var "SMTP_USER"
    check_var "SMTP_PASS"
    echo ""
fi

# my-pick-server 특정 변수
if grep -q "YOUTUBE_API_KEY" "$ENV_FILE" 2>/dev/null; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}my-pick-server 변수 검증${NC}"
    echo -e "${BLUE}========================================${NC}"
    check_var "YOUTUBE_API_KEY"
    check_var "TWITTER_BEARER_TOKEN"
    echo ""
fi

# my-pick-client 특정 변수
if grep -q "NEXT_PUBLIC_YOUTUBE_API_KEY" "$ENV_FILE" 2>/dev/null; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}my-pick-client 변수 검증${NC}"
    echo -e "${BLUE}========================================${NC}"
    check_var "NEXT_PUBLIC_YOUTUBE_API_KEY"
    check_var "NEXT_PUBLIC_TWITTER_API_KEY"
    check_var "NEXT_PUBLIC_TWITTER_API_SECRET"
    check_var "NEXT_PUBLIC_TWITTER_BEARER_TOKEN"
    echo ""
fi

# JWT 키 파일 확인
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}JWT 키 파일 검증${NC}"
echo -e "${BLUE}========================================${NC}"

JWT_KEYS_DIR="jwt-keys"
if [ -d "$JWT_KEYS_DIR" ]; then
    for key in access-private.key access-public.key refresh-private.key refresh-public.key; do
        TOTAL=$((TOTAL + 1))
        if [ -f "$JWT_KEYS_DIR/$key" ]; then
            echo -e "${GREEN}✓${NC} $key: ${GREEN}존재함${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗${NC} $key: ${RED}없음${NC}"
            FAIL=$((FAIL + 1))
        fi
    done
else
    echo -e "${RED}✗${NC} JWT 키 디렉토리가 없습니다: $JWT_KEYS_DIR"
    echo -e "${YELLOW}   scripts/generate-jwt-keys.sh를 실행하세요.${NC}"
    TOTAL=$((TOTAL + 4))
    FAIL=$((FAIL + 4))
fi
echo ""

# 결과 요약
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}검증 결과${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "총 검사 항목: $TOTAL"
echo -e "${GREEN}통과: $PASS${NC}"
echo -e "${RED}실패: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ 모든 검증 통과!${NC}"
    echo -e "${GREEN}Secret 생성을 진행할 수 있습니다.${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAIL개 항목이 실패했습니다.${NC}"
    echo -e "${YELLOW}위의 오류를 수정한 후 다시 시도하세요.${NC}"
    echo ""
    echo -e "${YELLOW}도움말:${NC}"
    echo "  1. 환경 파일을 편집하여 누락된 변수 추가"
    echo "  2. 기본값('your-...')을 실제 값으로 변경"
    echo "  3. JWT 키가 없으면 scripts/generate-jwt-keys.sh 실행"
    exit 1
fi
