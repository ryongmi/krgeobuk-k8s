# Quick Start Guide - Phase 1 완료 후 필수 작업

이 가이드는 Phase 1에서 생성된 파일들을 검토하고 실제 사용 가능하도록 설정하는 방법을 안내합니다.

## 🎯 목표

auth-server와 auth-client를 예시로 만든 인프라 파일을 검토하고, 수정이 필요한 부분을 수정한 후, 동일한 패턴으로 다른 서비스들을 생성합니다.

## 📂 리포지토리 위치 확인

```bash
# 세 개의 독립 리포지토리 확인
ls D:\GitHub\krgeobuk-k8s
ls D:\GitHub\krgeobuk-infrastructure
ls D:\GitHub\krgeobuk-deployment
```

## ⚡ 즉시 해야 할 작업 (우선순위 순)

### 1️⃣ miniPC IP 주소 설정 (최우선)

**위치**: `D:\GitHub\krgeobuk-k8s\base\`

**파일**:
- `external-mysql.yaml`
- `external-redis.yaml`

**수정 내용**:
```yaml
# 두 파일 모두에서 192.168.1.100을 실제 miniPC IP로 변경
subsets:
- addresses:
  - ip: "192.168.1.100"  # ← 여기를 실제 IP로 변경
```

**확인 방법**:
```bash
# miniPC에서 IP 확인
ip addr show
# 또는
hostname -I
```

### 2️⃣ 환경 변수 파일 생성

**위치**: `D:\GitHub\krgeobuk-infrastructure\`

**작업**:
```bash
cd D:\GitHub\krgeobuk-infrastructure
cp .env.example .env
```

**수정 내용** (`.env` 파일):
```bash
# MySQL
MYSQL_ROOT_PASSWORD=<강력한_비밀번호_입력>
MYSQL_AUTH_PASSWORD=<auth_user_비밀번호_입력>

# 예시 (실제로는 더 강력한 비밀번호 사용)
MYSQL_ROOT_PASSWORD=MyS3cur3RootP@ssw0rd!2024
MYSQL_AUTH_PASSWORD=Auth$erv1ceP@ss2024!
```

### 3️⃣ Kubernetes Secret 생성

**위치**: `D:\GitHub\krgeobuk-k8s\applications\auth-server\`

**작업**:
```bash
cd D:\GitHub\krgeobuk-k8s\applications\auth-server
cp secret.yaml.template secret.yaml
```

**수정 내용** (`secret.yaml`):

먼저 값을 Base64로 인코딩:
```bash
# Windows PowerShell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("your-password"))

# Linux/Mac
echo -n "your-password" | base64
```

그 다음 `secret.yaml`에 입력:
```yaml
data:
  # .env 파일의 MYSQL_AUTH_PASSWORD와 동일한 값을 Base64로 인코딩
  MYSQL_PASSWORD: "QXV0aCRlcnYxY2VQQHNzMjAyNCE="  # ← Base64 인코딩된 값

  # 새로 생성할 JWT Secret (최소 32자 랜덤 문자열)
  JWT_SECRET: "..."  # ← Base64 인코딩된 값

  # OAuth Secrets (나중에 설정 가능)
  GOOGLE_CLIENT_ID: ""
  GOOGLE_CLIENT_SECRET: ""
  NAVER_CLIENT_ID: ""
  NAVER_CLIENT_SECRET: ""
```

### 4️⃣ Docker 이미지 확인

Phase 2(실제 배포) 전에 Docker 이미지가 필요합니다.

**옵션 A: 이미지가 이미 있는 경우**
```bash
# 이미지 확인
docker images | grep krgeobuk
```

**옵션 B: 이미지를 빌드해야 하는 경우**
```bash
# auth-server 이미지 빌드
cd /path/to/auth-server
docker build -t krgeobuk/auth-server:latest .

# auth-client 이미지 빌드
cd /path/to/auth-client
docker build -t krgeobuk/auth-client:latest .
```

**확인할 이미지 이름**:
- `krgeobuk/auth-server:latest`
- `krgeobuk/auth-client:latest`

만약 이미지 이름이 다르다면, Deployment YAML 파일을 수정해야 합니다:
- `D:\GitHub\krgeobuk-k8s\applications\auth-server\deployment.yaml`
- `D:\GitHub\krgeobuk-k8s\applications\auth-client\deployment.yaml`

## 🔍 파일 검토 체크리스트

### krgeobuk-infrastructure 검토

```bash
cd D:\GitHub\krgeobuk-infrastructure
```

#### 확인할 파일들:

1. **`docker-compose/docker-compose.yaml`**
   - [ ] 포트 번호가 충돌하지 않는지 확인 (MySQL: 3306, Redis: 6379, Jenkins: 8080)
   - [ ] 볼륨 마운트 경로가 적절한지 확인

2. **`docker-compose/mysql/init/02-create-users.sql`**
   - [ ] 비밀번호가 보안 요구사항에 맞는지 확인
   - [ ] 필요하면 더 강력한 비밀번호로 변경

3. **`docker-compose/redis/redis.conf`**
   - [ ] `maxmemory 512mb` - 서버 메모리에 맞게 조정
   - [ ] 필요하면 다른 Redis 설정 추가

### krgeobuk-k8s 검토

```bash
cd D:\GitHub\krgeobuk-k8s
```

#### 확인할 파일들:

1. **`applications/auth-server/deployment.yaml`**
   - [ ] 이미지 이름: `krgeobuk/auth-server:latest` (실제 이미지와 일치하는지)
   - [ ] 포트 번호: 8000(HTTP), 8010(TCP) (실제 앱과 일치하는지)
   - [ ] Health check 경로: `/health`, `/health/ready` (실제 앱과 일치하는지)

2. **`applications/auth-server/configmap.yaml`**
   - [ ] 환경 변수가 적절한지 확인
   - [ ] 추가 필요한 환경 변수 확인

3. **`applications/auth-client/deployment.yaml`**
   - [ ] 이미지 이름 확인
   - [ ] 포트 번호: 3000 (실제 앱과 일치하는지)

4. **`applications/auth-client/nginx-configmap.yaml`**
   - [ ] API 프록시 설정: `proxy_pass http://auth-server` (올바른지)
   - [ ] 필요하면 추가 Nginx 설정

5. **`environments/dev/kustomization.yaml`**
   - [ ] `MYSQL_DATABASE=auth_dev` - 맞는지 확인
   - [ ] `REDIS_DB=0` - 맞는지 확인
   - [ ] `LOG_LEVEL=debug` - 개발 환경에 적합한지

6. **`environments/prod/patches/auth-server-prod.yaml`**
   - [ ] `replicas: 2` - 적절한지 (miniPC 성능 고려)
   - [ ] CPU 요청: 500m, 제한: 1000m - 서버 사양에 맞는지
   - [ ] 메모리 요청: 512Mi, 제한: 1Gi - 서버 사양에 맞는지

### krgeobuk-deployment 검토

```bash
cd D:\GitHub\krgeobuk-deployment
```

#### 확인할 파일들:

1. **`scripts/deploy-dev.sh`**
   - [ ] `K8S_PATH` 기본값: `../krgeobuk-k8s` (경로가 맞는지)
   - [ ] timeout 값: 5분 (충분한지)

2. **`scripts/deploy-prod.sh`**
   - [ ] 백업 스크립트 경로: `/opt/krgeobuk/infrastructure/backup/mysql-backup.sh` (맞는지)
   - [ ] timeout 값: 10분 (충분한지)

## ✅ 검증 단계

모든 파일을 수정한 후, 다음 명령어로 검증:

### 1. Kustomize 빌드 테스트

```bash
cd D:\GitHub\krgeobuk-k8s

# Dev 환경 빌드 테스트
kubectl kustomize environments/dev/ > /tmp/dev-manifest.yaml

# Prod 환경 빌드 테스트
kubectl kustomize environments/prod/ > /tmp/prod-manifest.yaml

# 에러가 없어야 함
```

### 2. YAML 문법 검증

```bash
# Dry-run으로 문법 검증 (실제 배포 안 됨)
kubectl apply --dry-run=client -k environments/dev/
kubectl apply --dry-run=client -k environments/prod/

# "created (dry run)" 메시지가 나와야 함
```

### 3. Docker Compose 검증

```bash
cd D:\GitHub\krgeobuk-infrastructure

# Docker Compose 설정 검증
docker-compose -f docker-compose/docker-compose.yaml config

# 에러가 없어야 함
```

## 🔄 수정 완료 후 다음 단계

모든 검토와 수정이 완료되면:

### 옵션 A: 다른 서비스 추가 (authz-server, portal-client)

**질문**:
- "auth-server와 auth-client 패턴을 복사해서 authz-server, portal-client도 만들어줘"
- "authz-server는 포트 8100, 8110 사용하고 Redis DB 2(dev), 3(prod) 사용해"

### 옵션 B: Phase 2 진행 (실제 배포 테스트)

**질문**:
- "Phase 2 시작해줘. miniPC에 인프라 구동하고 싶어"
- "Docker Compose로 MySQL, Redis 먼저 시작해보자"

## 📝 주요 파일 경로 요약

| 항목 | 파일 경로 | 작업 |
|------|----------|------|
| miniPC IP | `krgeobuk-k8s/base/external-*.yaml` | IP 주소 변경 |
| 환경 변수 | `krgeobuk-infrastructure/.env` | 비밀번호 입력 |
| Secret | `krgeobuk-k8s/applications/auth-server/secret.yaml` | Base64 인코딩 값 입력 |
| 이미지 이름 | `krgeobuk-k8s/applications/*/deployment.yaml` | 실제 이미지와 일치하는지 확인 |
| 리소스 제한 | `krgeobuk-k8s/environments/prod/patches/*.yaml` | 서버 사양에 맞게 조정 |

## 💡 팁

### Base64 인코딩 빠른 참조

**Windows PowerShell**:
```powershell
# 인코딩
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("your-text"))

# 디코딩 (확인용)
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("eW91ci10ZXh0"))
```

**Linux/Mac**:
```bash
# 인코딩
echo -n "your-text" | base64

# 디코딩 (확인용)
echo "eW91ci10ZXh0" | base64 -d
```

### JWT Secret 생성

```bash
# 32자 랜덤 문자열 생성
openssl rand -base64 32

# 또는 Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

### Git 커밋 전 체크리스트

```bash
# Secret 파일이 .gitignore에 있는지 확인
cd D:\GitHub\krgeobuk-k8s
cat .gitignore | grep secret.yaml

# .env 파일이 .gitignore에 있는지 확인
cd D:\GitHub\krgeobuk-infrastructure
cat .gitignore | grep .env

# 확인 후 커밋
git add .
git commit -m "feat: Add Phase 1 infrastructure for auth-server and auth-client"
git push origin main
```

## 🆘 문제 해결

### Q: Kustomize 빌드 시 "no matches for kind" 에러

**원인**: Kubernetes API 버전 불일치

**해결**:
```bash
# kubectl 버전 확인
kubectl version

# API 리소스 확인
kubectl api-resources
```

### Q: Secret Base64 인코딩이 잘못됨

**증상**: Pod가 시작되지 않음, env 변수가 이상함

**해결**:
```bash
# 인코딩된 값 확인
echo "eW91ci10ZXh0" | base64 -d

# 올바른 값으로 다시 인코딩
echo -n "correct-value" | base64
```

### Q: Docker 이미지를 찾을 수 없음

**증상**: `ImagePullBackOff` 에러

**해결**:
```bash
# 로컬에 이미지가 있는지 확인
docker images | grep krgeobuk

# 없으면 빌드
cd /path/to/auth-server
docker build -t krgeobuk/auth-server:latest .
```

---

**작성일**: 2024-12-21
**대상**: Phase 1 완료 후 검토 및 설정
**다음 단계**: authz-server, portal-client 추가 또는 Phase 2 진행
