# krgeobuk-k8s

krgeobuk 프로젝트의 Kubernetes 매니페스트입니다. Kustomize를 사용하여 환경별 설정을 관리합니다.

**총 9개 마이크로서비스** | **2개 환경 (dev, prod)** | **Phase 2 완료** ✅

## 📚 문서

상세한 문서는 [docs/](docs/README.md) 폴더를 참고하세요:

- [📖 전체 문서 인덱스](docs/README.md)
- [📄 Phase 1 완료 보고서](docs/phase1/PHASE1_SUMMARY.md) - 기본 서비스 4개
- [📄 Phase 2 완료 보고서](docs/phase2/PHASE2_SUMMARY.md) - 추가 서비스 5개
- [✅ Phase 2 배포 체크리스트](docs/phase2/PHASE2_CHECKLIST.md) - 배포 가이드

## 🎯 서비스 개요

| Phase | 서비스 | 포트 | 역할 |
|-------|--------|------|------|
| **Phase 1** | auth-server | 8000/8010 | 인증 서버 (OAuth, JWT) |
| | auth-client | 3000 | 인증 클라이언트 UI |
| | authz-server | 8100/8110 | 권한 관리 서버 (RBAC) |
| | portal-client | 3200 | 통합 포털 UI |
| **Phase 2** | portal-server | 8200/8210 | 포털 백엔드 API |
| | my-pick-server | 8300/8310 | MyPick 백엔드 API |
| | my-pick-client | 3300 | MyPick 사용자 UI |
| | portal-admin-client | 3210 | 포털 관리자 UI |
| | my-pick-admin-client | 3310 | MyPick 관리자 UI |

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
│   ├── auth-server/              # Phase 1: 인증 서버
│   ├── auth-client/              # Phase 1: 인증 클라이언트
│   ├── authz-server/             # Phase 1: 권한 서버
│   ├── portal-client/            # Phase 1: 포털 클라이언트
│   ├── portal-server/            # Phase 2: 포털 백엔드
│   ├── my-pick-server/           # Phase 2: MyPick 백엔드
│   ├── my-pick-client/           # Phase 2: MyPick 클라이언트
│   ├── portal-admin-client/      # Phase 2: 포털 관리자
│   └── my-pick-admin-client/     # Phase 2: MyPick 관리자
│   # 각 서비스는 동일한 구조:
│   #   ├── deployment.yaml
│   #   ├── service.yaml
│   #   ├── configmap.yaml
│   #   ├── secret.yaml.template (백엔드만)
│   #   └── kustomization.yaml
│
├── docs/                         # 📚 문서 폴더
│   ├── README.md                 # 문서 인덱스
│   ├── phase1/                   # Phase 1 문서
│   │   ├── PHASE1_SUMMARY.md
│   │   └── PHASE1_CHECKLIST.md
│   └── phase2/                   # Phase 2 문서
│       ├── PHASE2_SUMMARY.md
│       └── PHASE2_CHECKLIST.md
│
└── environments/                  # 환경별 설정
    ├── dev/                      # 개발 환경
    │   ├── kustomization.yaml    # Phase 1 + Phase 2 통합
    │   └── patches/              # 9개 서비스 패치
    │       ├── auth-server-dev.yaml
    │       ├── auth-client-dev.yaml
    │       ├── authz-server-dev.yaml
    │       ├── portal-client-dev.yaml
    │       ├── portal-server-dev.yaml            # Phase 2
    │       ├── my-pick-server-dev.yaml           # Phase 2
    │       ├── my-pick-client-dev.yaml           # Phase 2
    │       ├── portal-admin-client-dev.yaml      # Phase 2
    │       └── my-pick-admin-client-dev.yaml     # Phase 2
    │
    └── prod/                     # 운영 환경
        ├── kustomization.yaml    # Phase 1 + Phase 2 통합
        └── patches/              # 9개 서비스 패치
            ├── auth-server-prod.yaml
            ├── auth-client-prod.yaml
            ├── authz-server-prod.yaml
            ├── portal-client-prod.yaml
            ├── portal-server-prod.yaml           # Phase 2
            ├── my-pick-server-prod.yaml          # Phase 2
            ├── my-pick-client-prod.yaml          # Phase 2
            ├── portal-admin-client-prod.yaml     # Phase 2
            └── my-pick-admin-client-prod.yaml    # Phase 2
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
- **서비스**: 9개 (Phase 1: 4개 + Phase 2: 5개)
- **Replicas**: 각 서비스 1개
- **Resources**: 최소 리소스 (CPU: 50-100m, Memory: 128-256Mi)
- **Database**: auth_dev, authz_dev, portal, mypick
- **Redis DB**: 0 (auth), 1 (authz), 2 (my-pick)
- **Log Level**: debug
- **Total Resources**: ~650m CPU, ~1.2Gi Memory

### Prod 환경 (krgeobuk-prod namespace)
- **서비스**: 9개 (Phase 1: 4개 + Phase 2: 5개)
- **Replicas**: 각 서비스 2개 (총 18개 Pod)
- **Resources**: 고성능 (CPU: 200-500m, Memory: 256-512Mi)
- **Database**: auth_prod, authz_prod, portal, mypick
- **Redis DB**: 1
- **Log Level**: info/error
- **Pod Anti-Affinity**: 노드 분산 배치 (고가용성)
- **Total Resources**: ~6000m CPU, ~7Gi Memory

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
