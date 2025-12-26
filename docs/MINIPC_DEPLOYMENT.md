# miniPC Kubernetes 배포 가이드

이 문서는 krgeobuk 마이크로서비스를 miniPC의 k3s 클러스터에 배포하는 전체 과정을 설명합니다.

## 목차

1. [사전 준비](#사전-준비)
2. [인프라 구성](#인프라-구성)
3. [Secret 설정](#secret-설정)
4. [Kubernetes 배포](#kubernetes-배포)
5. [배포 확인](#배포-확인)
6. [트러블슈팅](#트러블슈팅)

## 사전 준비

### 1. 필수 구성 요소

miniPC에 다음이 설치되어 있어야 합니다:

- ✅ **k3s** - 경량 Kubernetes 클러스터
- ✅ **Docker** - 인프라 컨테이너 (MySQL, Redis, Jenkins)
- ✅ **Git** - 리포지토리 클론
- ✅ **kubectl** - Kubernetes CLI (k3s 설치 시 자동 설치)

### 2. 리포지토리 클론

```bash
# miniPC에서 실행
cd ~
git clone --recursive https://github.com/your-org/krgeobuk-infra.git
cd krgeobuk-infra

# 서브모듈 업데이트
git submodule update --init --recursive
```

### 3. 네트워크 확인

```bash
# miniPC IP 주소 확인
ip addr show

# 예시 출력: 192.168.1.100
# 이 IP는 나중에 ExternalName Service 설정에 사용됩니다
```

## 인프라 구성

### 1. krgeobuk-infrastructure 설정

Docker Compose로 MySQL, Redis, Jenkins를 실행합니다.

```bash
cd ~/krgeobuk-infra/krgeobuk-infrastructure/docker-compose

# 환경 변수 파일 생성
cp ../.env.example .env

# .env 파일 편집 (필수!)
nano .env
```

**필수 설정 항목**:
```bash
# MySQL 설정
MYSQL_ROOT_PASSWORD=강력한_비밀번호_입력
MYSQL_DEV_USER_PASSWORD=개발용_비밀번호
MYSQL_PROD_USER_PASSWORD=운영용_비밀번호  # 운영 환경 활성화 시

# Redis 설정
REDIS_PASSWORD=강력한_비밀번호_입력

# Jenkins 설정
JENKINS_ADMIN_PASSWORD=관리자_비밀번호

# 환경 설정
ENVIRONMENT=production  # 또는 development
```

### 2. 인프라 시작

```bash
# Docker Compose 실행
docker compose up -d

# 컨테이너 상태 확인
docker compose ps

# 예상 출력:
# - krgeobuk-mysql (포트 3306)
# - krgeobuk-redis (포트 6379)
# - jenkins (포트 9090)
# - verdaccio (포트 4873)

# 로그 확인
docker compose logs -f
```

### 3. 데이터베이스 확인

```bash
# MySQL 접속 테스트
docker exec krgeobuk-mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW DATABASES;"

# 예상 출력 (개발 환경):
# - auth_dev
# - authz_dev
# - portal_dev
# - mypick_dev

# dev_user 권한 확인
docker exec krgeobuk-mysql mysql -u dev_user -p"${MYSQL_DEV_USER_PASSWORD}" -e "SHOW DATABASES;"

# Redis 접속 테스트
docker exec krgeobuk-redis redis-cli -a "${REDIS_PASSWORD}" PING
# 출력: PONG
```

## Secret 설정

### 1. JWT 키 생성

auth-server용 JWT 키 페어를 생성합니다.

```bash
cd ~/krgeobuk-infra/auth-server

# JWT 키 생성 스크립트 실행
bash script/generate-jwt-keys.sh

# 생성된 키 확인
ls -la keys/
# - access-private.key
# - access-public.key
# - refresh-private.key
# - refresh-public.key
```

### 2. auth-server Secret 생성

```bash
cd ~/krgeobuk-infra/krgeobuk-k8s/applications/auth-server

# Secret 템플릿 복사
cp secret.yaml.template secret.yaml

# Secret 파일 편집
nano secret.yaml
```

**설정해야 할 값**:

```yaml
stringData:
  # MySQL 비밀번호 (.env 파일과 동일하게)
  MYSQL_PASSWORD: "개발용_비밀번호"
  MYSQL_ROOT_PASSWORD: "루트_비밀번호"

  # Redis 비밀번호 (.env 파일과 동일하게)
  REDIS_PASSWORD: "레디스_비밀번호"

  # OAuth Secrets (선택사항)
  GOOGLE_CLIENT_SECRET: "구글_클라이언트_시크릿"
  NAVER_CLIENT_SECRET: "네이버_클라이언트_시크릿"

  # Email SMTP (선택사항)
  SMTP_USER: "your-email@gmail.com"
  SMTP_PASS: "구글_앱_비밀번호"
```

**JWT 키 복사**:
```bash
# auth-server의 생성된 키를 secret.yaml에 복사
cat ~/krgeobuk-infra/auth-server/keys/access-private.key
cat ~/krgeobuk-infra/auth-server/keys/access-public.key
cat ~/krgeobuk-infra/auth-server/keys/refresh-private.key
cat ~/krgeobuk-infra/auth-server/keys/refresh-public.key

# 각 키 내용을 secret.yaml의 해당 위치에 붙여넣기
```

### 3. authz-server Secret 생성

```bash
cd ~/krgeobuk-infra/krgeobuk-k8s/applications/authz-server

# Secret 템플릿 복사
cp secret.yaml.template secret.yaml

# Secret 파일 편집
nano secret.yaml
```

**설정해야 할 값**:

```yaml
stringData:
  # MySQL/Redis 비밀번호 (auth-server와 동일)
  MYSQL_PASSWORD: "개발용_비밀번호"
  MYSQL_ROOT_PASSWORD: "루트_비밀번호"
  REDIS_PASSWORD: "레디스_비밀번호"

---
# JWT 공개키 (auth-server에서 복사)
stringData:
  access-public.key: |
    -----BEGIN PUBLIC KEY-----
    (auth-server의 access-public.key 내용 복사)
    -----END PUBLIC KEY-----
```

### 4. 기타 서비스 Secret 생성

다른 서비스도 필요한 경우 동일한 방식으로 Secret을 생성합니다:

```bash
# portal-server
cd ~/krgeobuk-infra/krgeobuk-k8s/applications/portal-server
cp secret.yaml.template secret.yaml
nano secret.yaml

# my-pick-server
cd ~/krgeobuk-infra/krgeobuk-k8s/applications/my-pick-server
cp secret.yaml.template secret.yaml
nano secret.yaml

# 각 서비스별로 필요한 비밀번호 설정
```

## Kubernetes 배포

### 1. Secret 적용

먼저 생성한 Secret을 Kubernetes에 적용합니다.

```bash
cd ~/krgeobuk-infra/krgeobuk-k8s

# auth-server secret 적용
kubectl apply -f applications/auth-server/secret.yaml

# authz-server secret 적용
kubectl apply -f applications/authz-server/secret.yaml

# 기타 서비스 secret 적용
kubectl apply -f applications/portal-server/secret.yaml
kubectl apply -f applications/my-pick-server/secret.yaml

# Secret 확인
kubectl get secrets -n krgeobuk-dev
kubectl get secrets -n krgeobuk-prod
```

### 2. 매니페스트 빌드 확인

실제 배포 전에 매니페스트가 올바르게 생성되는지 확인합니다.

```bash
# dev 환경 빌드 테스트
kubectl kustomize environments/dev/ > /tmp/dev-manifests.yaml

# prod 환경 빌드 테스트
kubectl kustomize environments/prod/ > /tmp/prod-manifests.yaml

# 생성된 리소스 확인
grep "^kind:" /tmp/dev-manifests.yaml | sort | uniq -c
```

### 3. Dev 환경 배포

```bash
# dev 환경 전체 배포
kubectl apply -k environments/dev/

# 또는 개별 서비스 배포 (테스트 권장)
kubectl apply -k applications/auth-server/overlays/dev
kubectl apply -k applications/authz-server/overlays/dev
kubectl apply -k applications/portal-client/overlays/dev
kubectl apply -k applications/auth-client/overlays/dev
```

### 4. Prod 환경 배포

Dev 환경에서 정상 동작 확인 후 진행:

```bash
# prod 환경 전체 배포
kubectl apply -k environments/prod/

# 또는 개별 서비스 배포
kubectl apply -k applications/auth-server/overlays/prod
kubectl apply -k applications/authz-server/overlays/prod
# ...
```

## 배포 확인

### 1. Pod 상태 확인

```bash
# dev 환경 Pod 확인
kubectl get pods -n krgeobuk-dev

# prod 환경 Pod 확인
kubectl get pods -n krgeobuk-prod

# 모든 Pod가 Running 상태여야 함
# 예상 출력:
# NAME                           READY   STATUS    RESTARTS   AGE
# auth-server-xxx                1/1     Running   0          2m
# authz-server-xxx               1/1     Running   0          2m
# portal-client-xxx              1/1     Running   0          2m
```

### 2. Service 확인

```bash
# Service 목록
kubectl get svc -n krgeobuk-dev

# ExternalName Service 확인 (MySQL, Redis)
kubectl get svc krgeobuk-mysql -n krgeobuk-dev -o yaml
kubectl get svc krgeobuk-redis -n krgeobuk-dev -o yaml
```

### 3. 로그 확인

```bash
# auth-server 로그
kubectl logs -f deployment/auth-server -n krgeobuk-dev

# authz-server 로그
kubectl logs -f deployment/authz-server -n krgeobuk-dev

# 여러 Pod의 로그 동시 확인
kubectl logs -f -l app=auth-server -n krgeobuk-dev --all-containers=true
```

### 4. Health Check

```bash
# Pod 내부에서 health check
kubectl exec -it deployment/auth-server -n krgeobuk-dev -- curl localhost:8000/health

# 예상 출력: {"status":"ok","timestamp":"..."}
```

### 5. Ingress 확인

```bash
# Ingress 리소스 확인
kubectl get ingress -n krgeobuk-dev

# Ingress 상세 정보
kubectl describe ingress krgeobuk-ingress -n krgeobuk-dev

# 외부 접속 테스트
curl http://minipc-ip/api/auth/health
```

## 트러블슈팅

### Pod가 시작되지 않는 경우

```bash
# Pod 상세 정보 확인
kubectl describe pod <pod-name> -n krgeobuk-dev

# 이벤트 확인
kubectl get events -n krgeobuk-dev --sort-by='.lastTimestamp'

# 로그 확인 (이전 컨테이너 포함)
kubectl logs <pod-name> -n krgeobuk-dev --previous
```

**일반적인 문제**:

1. **ImagePullBackOff**: 이미지를 찾을 수 없음
   - 이미지가 빌드되었는지 확인
   - ImagePullPolicy 확인 (개발: Never, 운영: Always)

2. **CrashLoopBackOff**: 컨테이너가 시작 후 즉시 종료
   - 로그에서 오류 확인
   - 환경 변수 설정 확인
   - Secret 값 확인

3. **Pending**: Pod가 스케줄링되지 않음
   - 리소스 부족: `kubectl describe node`
   - PVC 마운트 실패: `kubectl get pvc`

### Database 연결 실패

```bash
# ExternalName Service 확인
kubectl get svc krgeobuk-mysql -n krgeobuk-dev -o yaml

# DNS 확인 (Pod 내부에서)
kubectl exec -it deployment/auth-server -n krgeobuk-dev -- nslookup krgeobuk-mysql

# MySQL 컨테이너 상태 확인
docker ps | grep mysql
docker logs krgeobuk-mysql

# 연결 테스트 (Pod 내부에서)
kubectl exec -it deployment/auth-server -n krgeobuk-dev -- nc -zv krgeobuk-mysql 3306
```

**해결 방법**:
- ExternalName이 `host.docker.internal`로 설정되었는지 확인
- MySQL 컨테이너가 실행 중인지 확인
- Secret의 비밀번호가 .env 파일과 일치하는지 확인

### Secret 관련 문제

```bash
# Secret 존재 확인
kubectl get secret auth-server-secrets -n krgeobuk-dev

# Secret 내용 확인 (디코딩)
kubectl get secret auth-server-secrets -n krgeobuk-dev -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d

# Secret 재적용
kubectl delete secret auth-server-secrets -n krgeobuk-dev
kubectl apply -f applications/auth-server/secret.yaml
```

### 배포 롤백

문제 발생 시 이전 버전으로 롤백:

```bash
# 배포 히스토리 확인
kubectl rollout history deployment/auth-server -n krgeobuk-dev

# 이전 버전으로 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-dev

# 특정 리비전으로 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-dev --to-revision=2
```

### 리소스 부족

```bash
# 노드 리소스 사용량 확인
kubectl top nodes

# Pod 리소스 사용량 확인
kubectl top pods -n krgeobuk-dev

# 리소스 제한 조정 필요 시
# applications/{service}/overlays/dev/patch-deployment.yaml 수정
```

## 운영 팁

### 1. 로그 모니터링

```bash
# 전체 서비스 로그 수집
kubectl logs -f -l tier=backend -n krgeobuk-prod --all-containers=true

# 특정 시간 이후 로그
kubectl logs --since=1h deployment/auth-server -n krgeobuk-prod
```

### 2. 정기 백업

```bash
# krgeobuk-infrastructure 백업 스크립트 사용
cd ~/krgeobuk-infra/krgeobuk-infrastructure

# MySQL 백업
./backup/mysql-backup.sh

# Redis 백업
./backup/redis-backup.sh

# 백업 확인
ls -lh /opt/krgeobuk/backups/mysql/
ls -lh /opt/krgeobuk/backups/redis/
```

### 3. 업데이트 배포

```bash
# 1. 이미지 재빌드 (각 서비스 리포지토리에서)
cd ~/krgeobuk-infra/auth-server
docker build -t auth-server:latest .

# 2. Kubernetes 재배포
kubectl rollout restart deployment/auth-server -n krgeobuk-dev

# 3. 롤아웃 상태 확인
kubectl rollout status deployment/auth-server -n krgeobuk-dev
```

### 4. 스케일링

```bash
# 수동 스케일링
kubectl scale deployment/auth-server --replicas=3 -n krgeobuk-prod

# HPA (Horizontal Pod Autoscaler) 설정 (선택사항)
kubectl autoscale deployment/auth-server \
  --cpu-percent=70 \
  --min=2 \
  --max=5 \
  -n krgeobuk-prod
```

## 다음 단계

배포가 완료되면:

1. **CI/CD 파이프라인 설정**: Jenkins를 사용한 자동 배포 구성
2. **모니터링 구성**: Prometheus + Grafana 설정
3. **백업 자동화**: Cron job으로 정기 백업 스케줄링
4. **SSL/TLS 설정**: cert-manager로 Let's Encrypt 인증서 자동 발급
5. **도메인 연결**: Ingress에 실제 도메인 설정

## 참고 문서

- [QUICKSTART.md](../QUICKSTART.md) - 빠른 시작 가이드
- [DEPLOYMENT.md](./DEPLOYMENT.md) - 배포 전략 상세 문서
- [krgeobuk-infrastructure README](../../krgeobuk-infrastructure/README.md) - 인프라 구성 가이드
