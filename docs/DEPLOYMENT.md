# 배포 가이드

이 문서는 krgeobuk-infra 마이크로서비스 생태계의 배포 전략, 환경 설정, CI/CD 파이프라인을 설명합니다.

## 목차

1. [배포 환경](#배포-환경)
2. [환경별 설정](#환경별-설정)
3. [Docker 배포](#docker-배포)
4. [Kubernetes 배포](#kubernetes-배포)
5. [CI/CD 파이프라인](#cicd-파이프라인)
6. [배포 체크리스트](#배포-체크리스트)
7. [롤백 절차](#롤백-절차)
8. [모니터링](#모니터링)

## 배포 환경

krgeobuk-infra는 다음 환경을 지원합니다:

| 환경            | 용도        | 도메인 예시          |
| --------------- | ----------- | -------------------- |
| **local**       | 로컬 개발   | localhost            |
| **development** | 개발 서버   | dev.krgeobuk.com     |
| **staging**     | 스테이징/QA | staging.krgeobuk.com |
| **production**  | 프로덕션    | krgeobuk.com         |

### 환경별 특징

#### Local

- 개발자 로컬 머신
- Docker Compose 사용
- 모든 서비스 동일 머신에서 실행
- 핫 리로딩 활성화

#### Development

- 공유 개발 환경
- 최신 기능 테스트
- 자동 배포 (main 브랜치 푸시 시)
- 개발용 데이터베이스

#### Staging

- 프로덕션 환경과 동일한 구성
- QA 및 통합 테스트
- 프로덕션 배포 전 최종 검증
- 프로덕션 데이터 스냅샷 사용

#### Production

- 실제 서비스 환경
- 고가용성 (HA) 구성
- 자동 스케일링
- 백업 및 재해 복구

## 환경별 설정

### 환경 변수 구조

각 서비스는 `envs/` 디렉토리에 환경별 설정 파일을 관리합니다:

```
service/
├── envs/
│   ├── .env.local
│   ├── .env.development
│   ├── .env.staging
│   ├── .env.production
│   └── .env.example
```

### auth-server 환경 변수

#### .env.production 예시

```bash
# Application
NODE_ENV=production
PORT=8000
APP_NAME=auth-server

# Database
DB_HOST=auth-mysql-prod.cluster-xxxxx.region.rds.amazonaws.com
DB_PORT=3306
DB_USERNAME=auth_user
DB_PASSWORD=${DB_PASSWORD_SECRET}  # Secrets Manager에서 주입
DB_DATABASE=auth_production
DB_SSL=true
DB_POOL_SIZE=20

# Redis
REDIS_HOST=auth-redis-prod.xxxxx.cache.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD_SECRET}
REDIS_TLS=true

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRATION=3600
JWT_REFRESH_EXPIRATION=604800

# OAuth
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
GOOGLE_CALLBACK_URL=https://krgeobuk.com/auth/google/callback

NAVER_CLIENT_ID=${NAVER_CLIENT_ID}
NAVER_CLIENT_SECRET=${NAVER_CLIENT_SECRET}
NAVER_CALLBACK_URL=https://krgeobuk.com/auth/naver/callback

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# CORS
CORS_ORIGIN=https://krgeobuk.com,https://admin.krgeobuk.com

# Rate Limiting
RATE_LIMIT_TTL=60
RATE_LIMIT_MAX=100
```

### authz-server 환경 변수

#### .env.production 예시

```bash
# Application
NODE_ENV=production
PORT=8100
APP_NAME=authz-server

# Database
DB_HOST=authz-mysql-prod.cluster-xxxxx.region.rds.amazonaws.com
DB_PORT=3306
DB_USERNAME=authz_user
DB_PASSWORD=${DB_PASSWORD_SECRET}
DB_DATABASE=authz_production
DB_SSL=true
DB_POOL_SIZE=20

# Redis
REDIS_HOST=authz-redis-prod.xxxxx.cache.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD_SECRET}
REDIS_TLS=true

# JWT (auth-server와 동일한 시크릿)
JWT_SECRET=${JWT_SECRET}

# Service Discovery
AUTH_SERVICE_URL=http://auth-server:8000

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# CORS
CORS_ORIGIN=https://krgeobuk.com,https://admin.krgeobuk.com
```

### portal-client 환경 변수

#### .env.production 예시

```bash
# Environment
NEXT_PUBLIC_ENV=production

# API Endpoints
NEXT_PUBLIC_AUTH_API_URL=https://api.krgeobuk.com/auth
NEXT_PUBLIC_AUTHZ_API_URL=https://api.krgeobuk.com/authz

# Feature Flags
NEXT_PUBLIC_ENABLE_ANALYTICS=true
NEXT_PUBLIC_ENABLE_ERROR_TRACKING=true

# Analytics (선택사항)
NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
```

## Docker 배포

### Docker Compose 배포

#### Development 환경

```bash
# auth-server
cd auth-server
npm run docker:dev:up

# authz-server
cd authz-server
npm run docker:dev:up

# 전체 스택 중지
npm run docker:dev:down
```

#### Production 환경

```bash
# auth-server
cd auth-server
npm run docker:prod:up

# authz-server
cd authz-server
npm run docker:prod:up

# 스케일링 (replicas 지정)
docker compose -f docker-compose.prod.yml up -d --scale auth-server=3
```

### Docker 이미지 빌드 및 푸시

```bash
# 이미지 빌드
docker build -t krgeobuk/auth-server:latest -f auth-server/Dockerfile.prod ./auth-server
docker build -t krgeobuk/authz-server:latest -f authz-server/Dockerfile.prod ./authz-server
docker build -t krgeobuk/portal-client:latest -f portal-client/Dockerfile.prod ./portal-client

# 태그 지정 (버전 관리)
docker tag krgeobuk/auth-server:latest krgeobuk/auth-server:v1.0.0

# Docker Registry에 푸시
docker push krgeobuk/auth-server:latest
docker push krgeobuk/auth-server:v1.0.0
docker push krgeobuk/authz-server:latest
docker push krgeobuk/portal-client:latest
```

## Kubernetes 배포

### Kubernetes 리소스 구조

```
k8s/
├── base/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   └── secrets.yaml
├── auth-server/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── ingress.yaml
├── authz-server/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── ingress.yaml
├── portal-client/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── databases/
    ├── mysql-statefulset.yaml
    ├── redis-deployment.yaml
    └── pvc.yaml
```

### 배포 명령어

```bash
# Namespace 생성
kubectl create namespace krgeobuk-prod

# Secrets 생성 (환경 변수)
kubectl create secret generic auth-secrets \
  --from-env-file=auth-server/envs/.env.production \
  -n krgeobuk-prod

kubectl create secret generic authz-secrets \
  --from-env-file=authz-server/envs/.env.production \
  -n krgeobuk-prod

# ConfigMap 생성
kubectl apply -f k8s/base/configmap.yaml -n krgeobuk-prod

# 데이터베이스 배포
kubectl apply -f k8s/databases/ -n krgeobuk-prod

# 서비스 배포
kubectl apply -f k8s/auth-server/ -n krgeobuk-prod
kubectl apply -f k8s/authz-server/ -n krgeobuk-prod
kubectl apply -f k8s/portal-client/ -n krgeobuk-prod

# 배포 상태 확인
kubectl get pods -n krgeobuk-prod
kubectl get services -n krgeobuk-prod
kubectl get ingress -n krgeobuk-prod
```

### Helm 배포 (권장)

```bash
# Helm 차트 설치
helm install krgeobuk ./helm/krgeobuk \
  -n krgeobuk-prod \
  -f helm/values.production.yaml

# 업그레이드
helm upgrade krgeobuk ./helm/krgeobuk \
  -n krgeobuk-prod \
  -f helm/values.production.yaml

# 롤백
helm rollback krgeobuk -n krgeobuk-prod
```

### Auto Scaling (HPA)

```yaml
# auth-server/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: auth-server-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: auth-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

## CI/CD 파이프라인

### GitHub Actions 워크플로우

#### auth-server 배포 (.github/workflows/auth-server-deploy.yml)

```yaml
name: Deploy auth-server

on:
  push:
    branches: [main]
    paths:
      - "auth-server/**"
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: "18"

      - name: Install dependencies
        run: |
          cd auth-server
          npm ci

      - name: Run tests
        run: |
          cd auth-server
          npm run test
          npm run test:e2e

      - name: Lint
        run: |
          cd auth-server
          npm run lint

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: ./auth-server
          file: ./auth-server/Dockerfile.prod
          push: true
          tags: |
            krgeobuk/auth-server:latest
            krgeobuk/auth-server:${{ github.sha }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Kubernetes
        uses: azure/k8s-deploy@v4
        with:
          manifests: |
            k8s/auth-server/deployment.yaml
            k8s/auth-server/service.yaml
          images: krgeobuk/auth-server:${{ github.sha }}
          namespace: krgeobuk-prod
```

### 배포 전략

#### Blue-Green 배포

```bash
# Blue 환경에 새 버전 배포
kubectl apply -f k8s/auth-server/deployment-green.yaml

# 트래픽 전환 (Service 업데이트)
kubectl patch service auth-server -p '{"spec":{"selector":{"version":"green"}}}'

# 이전 버전(Blue) 제거
kubectl delete deployment auth-server-blue
```

#### Canary 배포

```yaml
# Canary 배포 (10% 트래픽)
apiVersion: v1
kind: Service
metadata:
  name: auth-server
spec:
  selector:
    app: auth-server
  # 10% canary, 90% stable
```

## 배포 체크리스트

### 배포 전 체크리스트

- [ ] 모든 테스트 통과 확인
- [ ] 코드 리뷰 완료
- [ ] 환경 변수 검증
- [ ] 데이터베이스 마이그레이션 스크립트 검토
- [ ] 의존성 버전 확인
- [ ] 보안 취약점 스캔
- [ ] 성능 테스트 완료
- [ ] 롤백 계획 수립
- [ ] 배포 시간 공지

### 배포 중 체크리스트

- [ ] 데이터베이스 백업 생성
- [ ] 이전 버전 이미지 보존
- [ ] 배포 로그 모니터링
- [ ] Health Check 확인
- [ ] 서비스 간 통신 검증

### 배포 후 체크리스트

- [ ] Health Check 정상 확인
- [ ] API 응답 시간 모니터링
- [ ] 에러 로그 확인
- [ ] 사용자 트래픽 모니터링
- [ ] 데이터베이스 연결 풀 확인
- [ ] Redis 캐시 동작 확인
- [ ] 주요 기능 Smoke Test

## 롤백 절차

### Docker Compose 롤백

```bash
# 이전 버전으로 롤백
docker compose down
docker compose up -d --build --force-recreate
```

### Kubernetes 롤백

```bash
# Deployment 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-prod

# 특정 리비전으로 롤백
kubectl rollout undo deployment/auth-server --to-revision=2 -n krgeobuk-prod

# 롤백 상태 확인
kubectl rollout status deployment/auth-server -n krgeobuk-prod

# 롤아웃 히스토리 확인
kubectl rollout history deployment/auth-server -n krgeobuk-prod
```

### Helm 롤백

```bash
# 이전 릴리스로 롤백
helm rollback krgeobuk -n krgeobuk-prod

# 특정 리비전으로 롤백
helm rollback krgeobuk 2 -n krgeobuk-prod

# 릴리스 히스토리 확인
helm history krgeobuk -n krgeobuk-prod
```

### 데이터베이스 롤백

```bash
# TypeORM 마이그레이션 롤백
npm run migration:revert

# 특정 시점으로 복원 (RDS 스냅샷)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier auth-mysql-prod \
  --target-db-instance-identifier auth-mysql-rollback \
  --restore-time 2024-01-01T12:00:00Z
```

## 모니터링

### 메트릭 수집

- **Prometheus**: 메트릭 수집
- **Grafana**: 시각화 대시보드
- **ELK Stack**: 로그 집계 및 분석
- **Sentry**: 에러 트래킹

### 주요 모니터링 지표

#### 애플리케이션 메트릭

- Request rate (RPS)
- Response time (p50, p95, p99)
- Error rate (4xx, 5xx)
- Active connections

#### 인프라 메트릭

- CPU 사용률
- 메모리 사용률
- 디스크 I/O
- 네트워크 대역폭

#### 데이터베이스 메트릭

- Query response time
- Connection pool usage
- Slow query log
- Replication lag

### 알림 설정

```yaml
# Prometheus Alert Rules
groups:
  - name: auth-server
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} per second"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, http_request_duration_seconds) > 1
        for: 5m
        annotations:
          summary: "High response time"
          description: "95th percentile response time is {{ $value }} seconds"
```

## 보안 고려사항

### Secrets 관리

```bash
# AWS Secrets Manager 사용
aws secretsmanager create-secret \
  --name krgeobuk/auth/jwt-secret \
  --secret-string "${JWT_SECRET}"

# Kubernetes Secrets
kubectl create secret generic jwt-secret \
  --from-literal=JWT_SECRET="${JWT_SECRET}" \
  -n krgeobuk-prod
```

### 네트워크 보안

- **VPC**: 프라이빗 서브넷에 서비스 배포
- **Security Group**: 필요한 포트만 개방
- **WAF**: 웹 애플리케이션 방화벽 설정
- **SSL/TLS**: HTTPS 강제 적용

### 이미지 보안

```bash
# 보안 스캔
docker scan krgeobuk/auth-server:latest

# Trivy 사용
trivy image krgeobuk/auth-server:latest
```

## 백업 및 재해 복구

### 데이터베이스 백업

```bash
# 자동 백업 (RDS)
# - 일일 자동 스냅샷
# - 7일 보존 기간
# - Point-in-time recovery 활성화

# 수동 백업
mysqldump -h auth-mysql-prod.xxxxx.rds.amazonaws.com \
  -u auth_user -p auth_production > backup.sql
```

### 재해 복구 계획

- **RPO (Recovery Point Objective)**: 1시간
- **RTO (Recovery Time Objective)**: 30분
- **Multi-AZ 배포**: 고가용성 보장
- **크로스 리전 복제**: 재해 복구

## 문의 및 지원

배포 관련 문의사항:

- **DevOps 팀**: devops@krgeobuk.com
- **긴급 상황**: Slack #devops-emergency
- **문서**: [Confluence 배포 가이드](https://wiki.krgeobuk.com/deploy)
