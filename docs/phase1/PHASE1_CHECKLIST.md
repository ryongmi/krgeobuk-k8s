# Phase 1: Repository Setup Completion Checklist

**목표**: auth-server와 auth-client를 위한 인프라 구조 생성 (예시로 사용)

**완료 날짜**: 2024-12-21

## 리포지토리 위치

- **krgeobuk-k8s**: `D:\GitHub\krgeobuk-k8s`
- **krgeobuk-infrastructure**: `D:\GitHub\krgeobuk-infrastructure`
- **krgeobuk-deployment**: `D:\GitHub\krgeobuk-deployment`

## ✅ 완료된 작업

### krgeobuk-infrastructure

- [x] 디렉토리 구조 생성
- [x] `docker-compose/docker-compose.yaml` - MySQL, Redis, Jenkins, Verdaccio 통합 구성
- [x] `docker-compose/mysql/init/01-create-databases.sql` - auth_dev, auth_prod DB 생성
- [x] `docker-compose/mysql/init/02-create-users.sql` - auth_user 계정 생성 및 권한 부여
- [x] `docker-compose/redis/redis.conf` - Redis 설정 (persistence, maxmemory 등)
- [x] `docker-compose/jenkins/Dockerfile` - kubectl, docker 포함한 Jenkins 이미지
- [x] `docker-compose/jenkins/plugins.txt` - 필수 Jenkins 플러그인 목록
- [x] `docker-compose/verdaccio/config.yaml` - @krgeobuk 스코프 패키지용 설정
- [x] `backup/mysql-backup.sh` - 자동 MySQL 백업 스크립트 (7일 보관)
- [x] `backup/redis-backup.sh` - 자동 Redis 백업 스크립트 (7일 보관)
- [x] `.env.example` - 환경 변수 템플릿
- [x] `.gitignore` - data/, logs/ 등 제외 설정
- [x] `README.md` - 인프라 설정 가이드

### krgeobuk-k8s

#### Base 리소스
- [x] `base/namespace.yaml` - krgeobuk-dev, krgeobuk-prod 네임스페이스
- [x] `base/external-mysql.yaml` - External Service로 Docker MySQL 연결
- [x] `base/external-redis.yaml` - External Service로 Docker Redis 연결
- [x] `base/kustomization.yaml` - base 리소스 통합

#### auth-server 애플리케이션
- [x] `applications/auth-server/deployment.yaml` - 기본 Deployment (initContainer, health probes)
- [x] `applications/auth-server/service.yaml` - HTTP(8000), TCP(8010) 서비스
- [x] `applications/auth-server/configmap.yaml` - 기본 환경 변수
- [x] `applications/auth-server/secret.yaml.template` - Secret 템플릿
- [x] `applications/auth-server/kustomization.yaml` - auth-server 리소스 통합

#### auth-client 애플리케이션
- [x] `applications/auth-client/deployment.yaml` - Nginx 기반 프론트엔드 Deployment
- [x] `applications/auth-client/service.yaml` - HTTP(3000) 서비스
- [x] `applications/auth-client/configmap.yaml` - 기본 환경 변수
- [x] `applications/auth-client/nginx-configmap.yaml` - Nginx 설정 (gzip, caching, SPA routing)
- [x] `applications/auth-client/kustomization.yaml` - auth-client 리소스 통합

#### Dev 환경
- [x] `environments/dev/kustomization.yaml` - dev 환경 통합 (auth_dev DB, Redis DB 0)
- [x] `environments/dev/patches/auth-server-dev.yaml` - replicas: 1, resources: small
- [x] `environments/dev/patches/auth-client-dev.yaml` - replicas: 1, resources: small

#### Prod 환경
- [x] `environments/prod/kustomization.yaml` - prod 환경 통합 (auth_prod DB, Redis DB 1)
- [x] `environments/prod/patches/auth-server-prod.yaml` - replicas: 2, resources: medium, podAntiAffinity
- [x] `environments/prod/patches/auth-client-prod.yaml` - replicas: 2, resources: medium, podAntiAffinity

#### 문서
- [x] `README.md` - Kubernetes 매니페스트 사용 가이드
- [x] `.gitignore` - secret.yaml 제외

### krgeobuk-deployment

- [x] `scripts/deploy-dev.sh` - dev 환경 자동 배포 스크립트
- [x] `scripts/deploy-prod.sh` - prod 환경 배포 스크립트 (백업 확인, double confirmation)
- [x] `scripts` 실행 권한 설정 (chmod +x)
- [x] `README.md` - 배포 스크립트 사용 가이드
- [x] `.gitignore` 생성

## 📋 사용자 확인 및 수정 필요 항목

### 1. krgeobuk-infrastructure 설정

#### 필수 작업
```bash
cd D:\GitHub\krgeobuk-infrastructure

# 1. .env 파일 생성
cp .env.example .env
# .env 파일을 열어 실제 비밀번호 입력:
# - MYSQL_ROOT_PASSWORD
# - MYSQL_AUTH_PASSWORD
```

#### 확인 사항
- [ ] `docker-compose/mysql/init/*.sql` - 비밀번호가 보안 요구사항에 맞는지 확인
- [ ] `docker-compose/redis/redis.conf` - maxmemory 설정이 서버 사양에 맞는지 확인
- [ ] `docker-compose/jenkins/plugins.txt` - 추가 필요한 플러그인 확인

### 2. krgeobuk-k8s 설정

#### 필수 작업
```bash
cd D:\GitHub\krgeobuk-k8s

# 1. miniPC IP 주소 업데이트
# base/external-mysql.yaml과 base/external-redis.yaml에서
# ip: "192.168.1.100" → 실제 miniPC IP로 변경

# 2. Secret 파일 생성
cd applications/auth-server/
cp secret.yaml.template secret.yaml
# secret.yaml을 열어 실제 값 입력:
# - MYSQL_PASSWORD (Base64 인코딩 필요)
# - JWT_SECRET (Base64 인코딩 필요)
# - GOOGLE_CLIENT_SECRET, NAVER_CLIENT_SECRET 등
```

#### 확인 사항
- [ ] `applications/auth-server/deployment.yaml` - 컨테이너 이미지 이름이 올바른지 확인 (krgeobuk/auth-server)
- [ ] `applications/auth-client/deployment.yaml` - 컨테이너 이미지 이름 확인 (krgeobuk/auth-client)
- [ ] `environments/dev/kustomization.yaml` - 환경 변수가 개발 환경에 적합한지 확인
- [ ] `environments/prod/patches/*.yaml` - 리소스 요청/제한이 서버 사양에 맞는지 확인

### 3. krgeobuk-deployment 설정

#### 필수 작업
```bash
cd D:\GitHub\krgeobuk-deployment

# 환경 변수 설정 (선택적)
export K8S_PATH=/path/to/krgeobuk-k8s  # 기본값: ../krgeobuk-k8s
```

#### 확인 사항
- [ ] `scripts/deploy-dev.sh` - 배포 스크립트의 rollout timeout 값이 적절한지 확인 (현재 5분)
- [ ] `scripts/deploy-prod.sh` - 프로덕션 안전장치가 충분한지 확인

## 🔄 다음 단계: 다른 서비스로 확장

auth-server와 auth-client 파일을 검토하고 수정이 완료되면, 동일한 패턴으로 다른 서비스 생성:

### authz-server 추가 (Phase 1-B)

```bash
# krgeobuk-infrastructure
# - docker-compose/mysql/init/*.sql에 authz_dev, authz_prod DB 추가 (이미 완료)

# krgeobuk-k8s
# - applications/authz-server/ 디렉토리 생성
# - auth-server를 참고하여 동일한 구조로 파일 생성
# - environments/dev/kustomization.yaml에 authz-server 추가
# - environments/dev/patches/authz-server-dev.yaml 생성 (Redis DB 2 사용)
# - environments/prod/kustomization.yaml에 authz-server 추가
# - environments/prod/patches/authz-server-prod.yaml 생성 (Redis DB 3 사용)
```

### portal-client 추가 (Phase 1-C)

```bash
# krgeobuk-k8s
# - applications/portal-client/ 디렉토리 생성
# - auth-client를 참고하여 동일한 구조로 파일 생성
# - environments/*/kustomization.yaml에 portal-client 추가
# - environments/*/patches/portal-client-*.yaml 생성
```

## 🚀 Phase 2 준비사항

Phase 1 완료 후 진행할 작업:

### Phase 2: 인프라 실제 구동

1. **miniPC에 Docker 인프라 시작**
   ```bash
   cd /opt/krgeobuk/infrastructure
   docker-compose -f docker-compose/docker-compose.yaml up -d

   # 확인
   docker ps
   docker exec krgeobuk-mysql mysql -u root -p -e "SHOW DATABASES;"
   docker exec krgeobuk-redis redis-cli PING
   ```

2. **k3s 설치 및 설정**
   ```bash
   # k3s 설치
   curl -sfL https://get.k3s.io | sh -

   # kubeconfig 복사 (로컬 머신에서)
   scp user@miniPC:/etc/rancher/k3s/k3s.yaml ~/.kube/config
   # server URL을 miniPC IP로 변경
   ```

3. **첫 배포 테스트**
   ```bash
   # Kustomize 빌드 테스트
   kubectl kustomize /opt/krgeobuk/k8s/environments/dev/

   # 배포
   cd /opt/krgeobuk/deployment
   ./scripts/deploy-dev.sh
   ```

## 📝 참고사항

### Base64 인코딩 방법
```bash
# Secret 값 인코딩
echo -n "your-password" | base64
echo -n "your-jwt-secret" | base64
```

### Docker 이미지 빌드 (Phase 2 이전 필요)
```bash
# auth-server 이미지 빌드
cd /path/to/auth-server
docker build -t krgeobuk/auth-server:latest .
docker build -t krgeobuk/auth-server:dev-$(git rev-parse --short HEAD) .

# auth-client 이미지 빌드
cd /path/to/auth-client
docker build -t krgeobuk/auth-client:latest .
docker build -t krgeobuk/auth-client:dev-$(git rev-parse --short HEAD) .
```

### 파일 검증 방법
```bash
# Kustomize 빌드 검증
kubectl kustomize environments/dev/ > /tmp/dev-manifest.yaml
kubectl kustomize environments/prod/ > /tmp/prod-manifest.yaml

# YAML 문법 검증
kubectl apply --dry-run=client -k environments/dev/
kubectl apply --dry-run=client -k environments/prod/
```

## ✨ 완료 기준

Phase 1이 완료된 것으로 간주하는 기준:

- [x] 모든 파일이 세 개의 리포지토리에 생성됨
- [ ] 사용자가 파일 검토 및 수정 완료
- [ ] miniPC IP 주소가 실제 값으로 업데이트됨
- [ ] Secret 파일이 생성되고 실제 값으로 채워짐
- [ ] .env 파일이 생성되고 비밀번호 설정됨
- [ ] Kustomize 빌드가 에러 없이 성공
- [ ] 필요한 Docker 이미지가 빌드됨

**현재 상태**: ✅ 파일 생성 완료, 사용자 검토 대기 중

---

**생성일**: 2024-12-21
**다음 업데이트**: Phase 2 시작 시
