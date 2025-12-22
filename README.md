# krgeobuk-k8s

krgeobuk 프로젝트의 Kubernetes 매니페스트입니다. Kustomize를 사용하여 환경별 설정을 관리합니다.

## 구조

```
krgeobuk-k8s/
├── base/                          # 공통 리소스
│   ├── namespace.yaml            # krgeobuk-dev, krgeobuk-prod
│   ├── external-mysql.yaml       # 외부 MySQL 연결
│   ├── external-redis.yaml       # 외부 Redis 연결
│   └── kustomization.yaml
│
├── applications/                  # 애플리케이션 템플릿
│   ├── auth-server/              # auth-server 매니페스트
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml.template
│   │   └── kustomization.yaml
│   │
│   ├── auth-client/              # auth-client 매니페스트
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── nginx-configmap.yaml
│   │   └── kustomization.yaml
│   │
│   ├── authz-server/             # authz-server 매니페스트
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml.template
│   │   └── kustomization.yaml
│   │
│   └── portal-client/            # portal-client 매니페스트
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       └── kustomization.yaml
│
└── environments/                  # 환경별 설정
    ├── dev/                      # 개발 환경
    │   ├── kustomization.yaml
    │   └── patches/
    │       ├── auth-server-dev.yaml
    │       ├── auth-client-dev.yaml
    │       ├── authz-server-dev.yaml
    │       └── portal-client-dev.yaml
    │
    └── prod/                     # 운영 환경
        ├── kustomization.yaml
        └── patches/
            ├── auth-server-prod.yaml
            ├── auth-client-prod.yaml
            ├── authz-server-prod.yaml
            └── portal-client-prod.yaml
```

## 시작하기

### 1. Secret 생성

```bash
# auth-server secret 생성
cd applications/auth-server/
cp secret.yaml.template secret.yaml
# secret.yaml 파일을 열어 실제 값 입력

# authz-server secret 생성
cd ../authz-server/
cp secret.yaml.template secret.yaml
# secret.yaml 파일을 열어 실제 값 입력 (JWT 공개키는 auth-server에서 복사)
```

### 2. External Service IP 설정

`base/external-mysql.yaml`과 `base/external-redis.yaml`에서 miniPC IP 주소를 실제 값으로 변경하세요:

```yaml
subsets:
- addresses:
  - ip: "192.168.1.100"  # 실제 miniPC IP로 변경
```

### 3. Kustomize 빌드 확인

```bash
# dev 환경 빌드 확인
kubectl kustomize environments/dev/

# prod 환경 빌드 확인
kubectl kustomize environments/prod/
```

### 4. 배포

```bash
# dev 환경 배포
kubectl apply -k environments/dev/

# prod 환경 배포
kubectl apply -k environments/prod/
```

## 환경 정보

### Dev 환경 (krgeobuk-dev namespace)
- **Replicas**: auth-server (1), auth-client (1), authz-server (1), portal-client (1)
- **Resources**: 최소 리소스
- **Database**: auth_dev, authz_dev
- **Redis DB**: 0
- **Log Level**: debug

### Prod 환경 (krgeobuk-prod namespace)
- **Replicas**: auth-server (2), auth-client (2), authz-server (2), portal-client (2)
- **Resources**: 더 많은 리소스
- **Database**: auth_prod, authz_prod
- **Redis DB**: 1
- **Log Level**: info

## 주요 명령어

### 배포 확인
```bash
# Pod 상태 확인
kubectl get pods -n krgeobuk-dev
kubectl get pods -n krgeobuk-prod

# Service 확인
kubectl get svc -n krgeobuk-dev
kubectl get svc -n krgeobuk-prod

# 로그 확인
kubectl logs -f deployment/auth-server -n krgeobuk-dev
kubectl logs -f deployment/auth-client -n krgeobuk-prod
```

### 배포 업데이트
```bash
# 설정 변경 후 재배포
kubectl apply -k environments/dev/

# 롤링 업데이트 확인
kubectl rollout status deployment/auth-server -n krgeobuk-dev
```

### 롤백
```bash
# 이전 버전으로 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-prod

# 특정 리비전으로 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-prod --to-revision=2
```

### 디버깅
```bash
# Pod 내부 접속
kubectl exec -it deployment/auth-server -n krgeobuk-dev -- /bin/sh

# 이벤트 확인
kubectl get events -n krgeobuk-dev --sort-by='.lastTimestamp'

# 리소스 사용량 확인
kubectl top pods -n krgeobuk-dev
```

## 환경별 설정 변경

환경별로 다른 설정이 필요한 경우 `environments/{dev|prod}/kustomization.yaml`의 `configMapGenerator`를 수정하세요:

```yaml
configMapGenerator:
- name: auth-server-config
  behavior: merge
  literals:
  - MYSQL_DATABASE=auth_dev
  - REDIS_DB=0
  - LOG_LEVEL=debug
```

## 주의사항

- `secret.yaml` 파일은 Git에 커밋하지 마세요 (.gitignore에 포함)
- External Service IP는 실제 miniPC IP로 변경해야 합니다
- Prod 환경 배포 전에 반드시 dev 환경에서 테스트하세요

## 문제 해결

### Pod가 시작되지 않는 경우
```bash
kubectl describe pod <pod-name> -n krgeobuk-dev
kubectl logs <pod-name> -n krgeobuk-dev
```

### Database 연결 실패
- External Service의 IP 주소 확인
- MySQL, Redis 컨테이너가 실행 중인지 확인
- Secret의 비밀번호 확인

### 이미지 Pull 실패
- 이미지가 빌드되었는지 확인
- Docker Registry 설정 확인
