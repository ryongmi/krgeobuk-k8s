#!/bin/bash

# JWT 키 생성 스크립트
# RSA 키 쌍을 생성하여 Kubernetes Secret에 사용

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 기본 설정
KEYS_DIR="./jwt-keys"
KEY_SIZE=2048

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}JWT 키 생성 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# OpenSSL 설치 확인
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}오류: openssl이 설치되어 있지 않습니다.${NC}"
    echo "설치 방법:"
    echo "  Ubuntu/Debian: sudo apt-get install openssl"
    echo "  macOS: brew install openssl"
    echo "  Windows: Git Bash 또는 WSL 사용"
    exit 1
fi

# 키 디렉토리 생성
if [ -d "$KEYS_DIR" ]; then
    echo -e "${YELLOW}경고: $KEYS_DIR 디렉토리가 이미 존재합니다.${NC}"
    read -p "기존 키를 덮어쓰시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}작업이 취소되었습니다.${NC}"
        exit 0
    fi
    rm -rf "$KEYS_DIR"
fi

mkdir -p "$KEYS_DIR"
echo -e "${GREEN}✓${NC} 키 디렉토리 생성: $KEYS_DIR"
echo ""

# Access Token 키 생성
echo -e "${YELLOW}[1/4]${NC} Access Token Private Key 생성 중..."
openssl genrsa -out "$KEYS_DIR/access-private.key" $KEY_SIZE 2>/dev/null
echo -e "${GREEN}✓${NC} 생성 완료: $KEYS_DIR/access-private.key"

echo -e "${YELLOW}[2/4]${NC} Access Token Public Key 생성 중..."
openssl rsa -in "$KEYS_DIR/access-private.key" -pubout -out "$KEYS_DIR/access-public.key" 2>/dev/null
echo -e "${GREEN}✓${NC} 생성 완료: $KEYS_DIR/access-public.key"
echo ""

# Refresh Token 키 생성
echo -e "${YELLOW}[3/4]${NC} Refresh Token Private Key 생성 중..."
openssl genrsa -out "$KEYS_DIR/refresh-private.key" $KEY_SIZE 2>/dev/null
echo -e "${GREEN}✓${NC} 생성 완료: $KEYS_DIR/refresh-private.key"

echo -e "${YELLOW}[4/4]${NC} Refresh Token Public Key 생성 중..."
openssl rsa -in "$KEYS_DIR/refresh-private.key" -pubout -out "$KEYS_DIR/refresh-public.key" 2>/dev/null
echo -e "${GREEN}✓${NC} 생성 완료: $KEYS_DIR/refresh-public.key"
echo ""

# 파일 권한 설정
chmod 600 "$KEYS_DIR"/*.key
echo -e "${GREEN}✓${NC} 파일 권한 설정 완료 (600)"
echo ""

# 생성된 키 목록
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}생성된 키 파일:${NC}"
echo -e "${GREEN}========================================${NC}"
ls -lh "$KEYS_DIR"
echo ""

# Base64 인코딩 (Kubernetes Secret용)
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes Secret용 Base64 인코딩${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}다음 명령어로 Base64 인코딩된 값을 확인할 수 있습니다:${NC}"
echo ""
echo "  # Access Private Key"
echo "  cat $KEYS_DIR/access-private.key | base64 -w 0"
echo ""
echo "  # Access Public Key"
echo "  cat $KEYS_DIR/access-public.key | base64 -w 0"
echo ""
echo "  # Refresh Private Key"
echo "  cat $KEYS_DIR/refresh-private.key | base64 -w 0"
echo ""
echo "  # Refresh Public Key"
echo "  cat $KEYS_DIR/refresh-public.key | base64 -w 0"
echo ""

# 다음 단계 안내
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}다음 단계${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}1. auth-server Secret에 Private/Public 키 추가${NC}"
echo "   - applications/auth-server/secret.yaml 편집"
echo "   - Private 키와 Public 키 모두 추가"
echo ""
echo -e "${YELLOW}2. 다른 서비스 Secret에 Public 키만 추가${NC}"
echo "   - authz-server/secret.yaml"
echo "   - portal-server/secret.yaml"
echo "   - my-pick-server/secret.yaml"
echo "   - Public 키만 추가 (Private 키는 auth-server만 보유)"
echo ""
echo -e "${YELLOW}3. Secret 적용${NC}"
echo "   kubectl apply -f applications/<service>/secret.yaml -n <namespace>"
echo ""
echo -e "${GREEN}✓ JWT 키 생성 완료!${NC}"
