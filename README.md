# krgeobuk-k8s

krgeobuk 프로젝트의 Kubernetes 매니페스트 리포지토리입니다.
Kustomize Base + Overlays 패턴으로 dev/prod 환경별 설정을 관리합니다.

## 역할

- 9개 마이크로서비스 K8s 매니페스트 (Deployment, Service, ConfigMap)
- Kustomize를 통한 환경별(dev/prod) 설정 관리
- 클러스터 애드온 매니페스트 (cert-manager, ingress-nginx)
- 운영 보조 스크립트 (롤백, 헬스체크, Secret 생성 등)

## 다른 리포지토리와의 관계

```
krgeobuk-infrastructure       krgeobuk-k8s              krgeobuk-deployment
(MySQL, Redis)                (이 리포지토리)            (Jenkins CI/CD)
        │                           │                           │
        ▼                           │                           ▼
ExternalName Service로 ←────────────┘         Jenkins 파이프라인이 이 리포를
MySQL, Redis에 연결                            클론하여 kubectl apply -k 실행
```

- **krgeobuk-infrastructure**: Docker Compose로 운영하는 MySQL, Redis. `base/external-*.yaml`의 ExternalName Service로 연결
- **krgeobuk-deployment**: Jenkins 파이프라인 (`deployToK8s.groovy`)이 이 리포지토리를 클론하여 `kubectl apply -k`로 배포

---

## 서비스 목록

| 서비스 | HTTP 포트 | TCP 포트 | 역할 |
|---|---|---|---|
| auth-server | 8000 | 8010 | 인증 서버 (OAuth, JWT) |
| auth-client | 3000 | - | 인증 클라이언트 UI |
| authz-server | 8100 | 8110 | 권한 관리 서버 (RBAC) |
| portal-client | 3200 | - | 통합 포털 UI |
| portal-server | 8200 | 8210 | 포털 백엔드 API |
| mypick-server | 8300 | 8310 | MyPick 백엔드 API |
| mypick-client | 3300 | - | MyPick 사용자 UI |
| portal-admin-client | 3210 | - | 포털 관리자 UI |
| mypick-admin-client | 3310 | - | MyPick 관리자 UI |

---

## 구조

```
krgeobuk-k8s/
│
├── base/                               # 공통 리소스
│   ├── namespace.yaml                  # krgeobuk-dev, krgeobuk-prod
│   ├── external-mysql.yaml             # 외부 MySQL ExternalName Service
│   ├── external-redis.yaml             # 외부 Redis ExternalName Service
│   └── kustomization.yaml
│
├── applications/                       # 9개 서비스 매니페스트
│   └── {서비스명}/
│       ├── base/                       # 공통 매니페스트
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── configmap.yaml
│       │   └── kustomization.yaml
│       ├── overlays/
│       │   ├── dev/                    # dev 패치 (imagePullPolicy: Never 등)
│       │   │   ├── kustomization.yaml
│       │   │   └── patch-deployment.yaml
│       │   └── prod/                   # prod 패치 (replicas, resources 등)
│       │       ├── kustomization.yaml
│       │       └── patch-deployment.yaml
│       └── secret.yaml.template        # Secret 템플릿 (커밋 금지)
│
├── environments/                       # 환경 통합 배포 진입점
│   ├── dev/
│   │   ├── kustomization.yaml          # 전체 서비스 overlays/dev 참조
│   │   ├── ingress.yaml
│   │   └── namespace.yaml
│   └── prod/
│       ├── kustomization.yaml          # 전체 서비스 overlays/prod 참조
│       ├── ingress.yaml
│       └── namespace.yaml
│
├── cluster-addons/                     # 클러스터 공통 애드온
│   ├── cert-manager/                   # TLS 인증서 자동 발급
│   │   ├── cluster-issuer-prod.yaml
│   │   ├── cluster-issuer-staging.yaml
│   │   └── kustomization.yaml
│   └── ingress-nginx/                  # NGINX Ingress Controller
│       └── kustomization.yaml
│
├── scripts/                            # 운영 보조 스크립트
│   ├── create-secrets.sh               # 전체 서비스 Secret 일괄 생성
│   ├── validate-secrets.sh             # Secret 유효성 검증
│   ├── generate-jwt-keys.sh            # JWT RSA 키 생성
│   ├── deploy.sh                       # 수동 배포
│   ├── rollback.sh                     # 롤백
│   ├── health-check.sh                 # 전체 서비스 헬스체크
│   ├── logs.sh                         # 로그 수집
│   └── build-local-images.sh           # 로컬 이미지 빌드 (dev용)
│
└── docs/                               # 문서
    ├── DEPLOYMENT.md
    ├── MINIPC_DEPLOYMENT.md
    └── ingress/INGRESS_GUIDE.md
```

---

## 시작하기

### 1. Secret 생성

각 서비스 디렉토리의 `secret.yaml.template`을 복사하여 실제 값을 입력합니다.

```bash
# 개별 생성
cd applications/auth-server/
cp secret.yaml.template secret.yaml
vi secret.yaml

# 또는 스크립트로 일괄 생성
./scripts/create-secrets.sh
```

Secret 생성 후 검증:

```bash
./scripts/validate-secrets.sh
```

### 2. External Service IP 설정

`base/external-mysql.yaml`과 `base/external-redis.yaml`에서 미니PC IP를 실제 값으로 변경합니다.

```yaml
# base/external-mysql.yaml
subsets:
- addresses:
  - ip: "192.168.0.28"   # 실제 미니PC IP
```

### 3. Kustomize 빌드 확인

```bash
# 빌드 결과 확인 (실제 적용 전 검증)
kubectl kustomize environments/dev/
kubectl kustomize environments/prod/
```

### 4. 배포

**전체 환경 배포** (모든 서비스):

```bash
kubectl apply -k environments/dev/
kubectl apply -k environments/prod/
```

**개별 서비스 배포**:

```bash
kubectl apply -k applications/auth-server/overlays/dev/
kubectl apply -k applications/auth-server/overlays/prod/
```

---

## 배포 방식

### 정상 운영 (Jenkins CI/CD)

Jenkins 파이프라인이 이 리포지토리를 클론하여 자동으로 배포합니다.
파이프라인 상세: `krgeobuk-deployment/jenkins/README.md`

```
Jenkins 파이프라인
    ↓
이 리포 클론 (krgeobuk-k8s)
    ↓
kustomize edit set image {서비스명}:{태그}
    ↓
kubectl apply -k applications/{서비스명}/overlays/{env}/
```

### 수동 배포 / 긴급 핫픽스

```bash
# 특정 서비스 수동 재배포
kubectl apply -k applications/auth-server/overlays/dev/

# 롤백
./scripts/rollback.sh

# 전체 헬스체크
./scripts/health-check.sh
```

---

## 환경 정보

### Dev 환경 (`krgeobuk-dev` namespace)

| 항목 | 값 |
|---|---|
| Replicas | 서비스당 1개 |
| imagePullPolicy | Never (k3s containerd 로컬 이미지 사용) |
| Resources | 최소 (CPU: 50~100m, Memory: 128~256Mi) |
| Log Level | debug |

### Prod 환경 (`krgeobuk-prod` namespace)

| 항목 | 값 |
|---|---|
| Replicas | 서비스당 2개 |
| imagePullPolicy | Always (Docker Registry pull) |
| Resources | 고성능 (CPU: 200~500m, Memory: 256~512Mi) |
| Log Level | info / error |

---

## Dev 환경 이미지 관리

dev 환경은 `imagePullPolicy: Never`로 설정되어 있어 Docker Registry를 사용하지 않습니다.
k3s는 containerd를 이미지 스토어로 사용하며 Docker 데몬과 분리되어 있기 때문에,
`docker build`로 만든 이미지를 별도로 k3s containerd에 적재해야 합니다.

### 방식 1: 파이프로 직접 import (Jenkins 파이프라인 방식)

```bash
# 빌드 후 바로 k3s containerd에 적재 (파일 저장 없음)
docker build -t auth-server:latest .
docker save auth-server:latest | k3s ctr images import --namespace k8s.io -
```

### 방식 2: tar.gz로 압축 후 import (수동 방식)

이미지를 파일로 보관하거나 다른 서버로 전송할 때 사용합니다.

```bash
# 1. 이미지 빌드
docker build -t auth-server:latest .

# 2. tar.gz로 압축 저장
docker save auth-server:latest | gzip > auth-server.tar.gz

# 3. k3s containerd에 import
k3s ctr images import --namespace k8s.io auth-server.tar.gz

# 4. 압축 파일 정리 (선택)
rm auth-server.tar.gz
```

### 전체 서비스 일괄 처리

```bash
SERVICES=(
  auth-server
  auth-client
  authz-server
  portal-client
  portal-server
  mypick-server
  mypick-client
  portal-admin-client
  mypick-admin-client
)

for svc in "${SERVICES[@]}"; do
  echo ">>> $svc"
  docker save ${svc}:latest | k3s ctr images import --namespace k8s.io -
done
```

### 이미지 확인 및 정리

```bash
# k3s containerd에 적재된 이미지 목록 확인
k3s ctr images list --namespace k8s.io

# 특정 서비스 이미지 확인
k3s ctr images list --namespace k8s.io | grep auth-server

# 불필요한 이미지 삭제
k3s ctr images rm --namespace k8s.io docker.io/library/auth-server:latest
```

> **참고**: `k3s ctr` 명령은 미니PC 호스트 또는 Jenkins Pod(k3s 바이너리/소켓 마운트 필요)에서 실행 가능합니다.
> Jenkins Pod 설정: `krgeobuk-deployment/jenkins/k8s/deployment.yaml`

---

## 클러스터 애드온

### cert-manager (TLS 인증서 자동 발급)

```bash
# cert-manager 설치 (최초 1회)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# ClusterIssuer 적용
kubectl apply -k cluster-addons/cert-manager/
```

상세 가이드: [cluster-addons/cert-manager/README.md](./cluster-addons/cert-manager/README.md)

### ingress-nginx

```bash
kubectl apply -k cluster-addons/ingress-nginx/
```

상세 가이드: [cluster-addons/ingress-nginx/README.md](./cluster-addons/ingress-nginx/README.md)

---

## 주요 kubectl 명령어

### 상태 확인

```bash
# Pod 전체 상태
kubectl get pods -n krgeobuk-dev
kubectl get pods -n krgeobuk-prod

# 특정 서비스 로그
kubectl logs -f deployment/auth-server -n krgeobuk-dev

# 롤아웃 상태
kubectl rollout status deployment/auth-server -n krgeobuk-dev

# 리소스 사용량
kubectl top pods -n krgeobuk-dev
```

### 배포 업데이트

```bash
# 설정 변경 후 재적용
kubectl apply -k environments/dev/

# 롤링 업데이트 확인
kubectl rollout status deployment/auth-server -n krgeobuk-dev
```

### 롤백

```bash
# 바로 이전 버전으로 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-prod

# 특정 리비전으로 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-prod --to-revision=2

# 리비전 히스토리 확인
kubectl rollout history deployment/auth-server -n krgeobuk-prod
```

### 디버깅

```bash
# Pod 상세 정보 (이벤트, 오류 원인 확인)
kubectl describe pod <pod-name> -n krgeobuk-dev

# Pod 내부 접속
kubectl exec -it deployment/auth-server -n krgeobuk-dev -- /bin/sh

# 클러스터 이벤트 확인
kubectl get events -n krgeobuk-dev --sort-by='.lastTimestamp'
```

---

## 문제 해결

### Pod가 시작되지 않을 때

```bash
kubectl describe pod <pod-name> -n krgeobuk-dev
kubectl logs <pod-name> -n krgeobuk-dev
```

### DB 연결 실패

- `base/external-mysql.yaml`, `base/external-redis.yaml`의 IP 주소 확인
- `krgeobuk-infrastructure`의 MySQL, Redis 컨테이너 실행 여부 확인
- 해당 서비스 Secret의 비밀번호 확인

### 이미지 로드 실패 (dev)

dev 환경은 `imagePullPolicy: Never`로 k3s containerd 로컬 이미지를 사용합니다.
Jenkins 파이프라인이 `docker save | k3s ctr images import`로 이미지를 적재합니다.

```bash
# k3s containerd 이미지 목록 확인
k3s ctr images list --namespace k8s.io | grep {서비스명}
```

### Secret 누락 또는 오류

```bash
# Secret 존재 여부 확인
kubectl get secret -n krgeobuk-dev

# Secret 재생성
./scripts/create-secrets.sh
./scripts/validate-secrets.sh
```

---

## 주의사항

- `secret.yaml` 파일은 Git에 커밋하지 마세요 (`.gitignore`에 포함)
- `base/external-*.yaml`의 IP는 환경에 맞게 반드시 변경하세요
- prod 배포 전 dev 환경에서 먼저 검증하세요
