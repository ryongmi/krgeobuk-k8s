# Phase 2 완료 보고서

**작성일**: 2024-12-22
**작업 범위**: 추가 서비스 5개 Kubernetes 배포 구성

---

## 📋 개요

Phase 2에서는 krgeobuk 생태계의 나머지 5개 서비스를 Kubernetes 인프라에 추가했습니다. 이로써 총 9개의 마이크로서비스가 Kubernetes에서 운영 가능한 상태가 되었습니다.

### Phase 1 vs Phase 2

| 구분 | Phase 1 | Phase 2 | 합계 |
|------|---------|---------|------|
| **백엔드 서비스** | 2개 (auth, authz) | 2개 (portal, my-pick) | 4개 |
| **프론트엔드** | 2개 (auth-client, portal-client) | 3개 (my-pick-client, 2개 admin) | 5개 |
| **생성된 파일** | ~30개 | 37개 | ~67개 |
| **코드 라인** | ~1000줄 | 1500+줄 | ~2500줄 |

---

## 🎯 추가된 서비스

### 1. portal-server (포트 8200/8210)

**역할**: 통합 포털 백엔드 서비스

**주요 기능**:
- 서비스 등록 및 관리
- 포털 통합 API 제공
- auth-server, authz-server와 TCP 통신

**기술 스택**:
- NestJS + TypeScript
- MySQL (독립 DB: portal)
- Redis 캐싱
- JWT 공개키 기반 인증

**Kubernetes 구성**:
```yaml
# 리소스
- CPU: 250m (requests) / 500m (limits)
- Memory: 512Mi (requests) / 1Gi (limits)
- Replicas: Dev 1개, Prod 2개

# 네트워크
- HTTP API: 8200
- TCP Service: 8210
- ClusterIP + Session Affinity (3시간)

# 의존성
- auth-server (JWT 공개키)
- authz-server (권한 검증)
- MySQL, Redis
```

**배포 파일**:
- `applications/portal-server/configmap.yaml`
- `applications/portal-server/deployment.yaml`
- `applications/portal-server/service.yaml`
- `applications/portal-server/secret.yaml.template`
- `applications/portal-server/kustomization.yaml`
- `environments/dev/patches/portal-server-dev.yaml`
- `environments/prod/patches/portal-server-prod.yaml`

---

### 2. my-pick-server (포트 8300/8310)

**역할**: MyPick 플랫폼 백엔드 서비스

**주요 기능**:
- 크리에이터 및 플랫폼 계정 관리
- 외부 API 통합 (YouTube Data API v3, Twitter API v2)
- 콘텐츠 자동 동기화
- 사용자 구독 및 상호작용 관리 (북마크, 좋아요, 시청 기록)
- 관리자 도구 및 통계 대시보드
- 신고 및 모더레이션 시스템

**기술 스택**:
- NestJS + TypeScript (ES Modules)
- MySQL (독립 DB: mypick)
- Redis 캐싱 (DB 2, 5분 TTL)
- YouTube Data API v3 연동 완료
- Twitter API v2 연동 완료

**Kubernetes 구성**:
```yaml
# 리소스
- CPU: 250m (requests) / 500m (limits)
- Memory: 512Mi (requests) / 1Gi (limits)
- Replicas: Dev 1개, Prod 2개

# 네트워크
- HTTP API: 8300
- TCP Service: 8310
- ClusterIP + Session Affinity (3시간)

# 환경 변수 (특별)
- YOUTUBE_API_KEY (Secret)
- TWITTER_BEARER_TOKEN (Secret)
- YOUTUBE_QUOTA_LIMIT: 10000
- TWITTER_QUOTA_LIMIT: 2000000
- REDIS_TTL: 300 (5분)

# 의존성
- auth-server (JWT 공개키)
- authz-server (권한 검증)
- MySQL, Redis
- YouTube Data API v3
- Twitter API v2
```

**배포 파일**:
- `applications/my-pick-server/configmap.yaml`
- `applications/my-pick-server/deployment.yaml`
- `applications/my-pick-server/service.yaml`
- `applications/my-pick-server/secret.yaml.template` (YouTube/Twitter API 키 포함)
- `applications/my-pick-server/kustomization.yaml`
- `environments/dev/patches/my-pick-server-dev.yaml`
- `environments/prod/patches/my-pick-server-prod.yaml`

---

### 3. my-pick-client (포트 3300)

**역할**: MyPick 사용자 프론트엔드

**주요 기능**:
- 크리에이터 콘텐츠 통합 피드
- 사용자 구독 관리
- 북마크 및 좋아요 기능
- 콘텐츠 연동 (서버 사이드 API 사용)
- Redux Toolkit 상태 관리

**기술 스택**:
- Next.js 14 App Router
- TypeScript + Redux Toolkit
- Tailwind CSS
- Axios HTTP 클라이언트
- React Hook Form + Zod

**Kubernetes 구성**:
```yaml
# 리소스
- CPU: 100m (requests) / 200m (limits)
- Memory: 256Mi (requests) / 512Mi (limits)
- Replicas: Dev 1개, Prod 2개

# 네트워크
- HTTP: 3300
- ClusterIP + Session Affinity (3시간)

# 환경 변수
- NEXT_PUBLIC_API_URL: http://my-pick-server:8300
- NEXT_PUBLIC_AUTH_SERVER_URL: http://auth-server:8000
- NEXT_PUBLIC_AUTHZ_API_URL: http://authz-server:8100
- NEXT_PUBLIC_MYPICK_API_URL: http://my-pick-server:8300

# Secret (클라이언트 사이드 API 키)
- NEXT_PUBLIC_YOUTUBE_API_KEY
- NEXT_PUBLIC_TWITTER_API_KEY
- NEXT_PUBLIC_TWITTER_BEARER_TOKEN

# HTTP Client 설정
- API_TIMEOUT: 15000 (15초, 콘텐츠 로딩 고려)
- RATE_LIMIT_MAX_ATTEMPTS: 200 (콘텐츠 서비스 높은 제한)
- CSRF, Input Validation, Security Logging 활성화
```

**배포 파일**:
- `applications/my-pick-client/configmap.yaml`
- `applications/my-pick-client/deployment.yaml`
- `applications/my-pick-client/service.yaml`
- `applications/my-pick-client/secret.yaml.template`
- `applications/my-pick-client/kustomization.yaml`
- `environments/dev/patches/my-pick-client-dev.yaml`
- `environments/prod/patches/my-pick-client-prod.yaml`

---

### 4. portal-admin-client (포트 3210)

**역할**: 통합 포털 관리자 인터페이스

**주요 기능**:
- 사용자 관리 (CRUD)
- 역할 및 권한 관리
- 서비스 등록 및 관리
- 실시간 대시보드 및 통계
- AdminAuthGuard를 통한 관리자 권한 검증

**기술 스택**:
- Next.js 15 App Router
- TypeScript + Redux Toolkit
- Tailwind CSS
- @krgeobuk/http-client (멀티서버 통합 클라이언트)
- Lucide React 아이콘

**Kubernetes 구성**:
```yaml
# 리소스
- CPU: 100m (requests) / 200m (limits)
- Memory: 256Mi (requests) / 512Mi (limits)
- Replicas: Dev 1개, Prod 2개

# 네트워크
- HTTP: 3210
- ClusterIP + Session Affinity (3시간)

# 환경 변수 (멀티서버 연동)
- NEXT_PUBLIC_AUTH_SERVER_URL: http://auth-server:8000/api
- NEXT_PUBLIC_AUTHZ_SERVER_URL: http://authz-server:8100/api
- NEXT_PUBLIC_PORTAL_SERVER_URL: http://portal-server:8200/api
- NEXT_PUBLIC_TOKEN_REFRESH_URL: http://auth-server:8000/api/auth/refresh
- NEXT_PUBLIC_ADMIN_CLIENT_URL: http://portal-admin-client:3210
- NEXT_PUBLIC_PORTAL_CLIENT_URL: http://portal-client:3200

# HTTP Client 설정 (관리자용 엄격한 제한)
- API_TIMEOUT: 15000
- RATE_LIMIT_MAX_ATTEMPTS: 50 (관리자는 더 낮은 제한)
- 모든 보안 기능 활성화
```

**배포 파일**:
- `applications/portal-admin-client/configmap.yaml`
- `applications/portal-admin-client/deployment.yaml`
- `applications/portal-admin-client/service.yaml`
- `applications/portal-admin-client/secret.yaml.template` (현재 사용 안 함, 확장용)
- `applications/portal-admin-client/kustomization.yaml`
- `environments/dev/patches/portal-admin-client-dev.yaml`
- `environments/prod/patches/portal-admin-client-prod.yaml`

---

### 5. my-pick-admin-client (포트 3310)

**역할**: MyPick 관리자 인터페이스

**주요 기능**:
- 크리에이터 관리
- 콘텐츠 관리 및 모더레이션
- 플랫폼 계정 관리
- 통계 및 대시보드
- 신고 처리

**기술 스택**:
- Next.js 15 App Router
- TypeScript + Redux Toolkit
- Tailwind CSS
- Axios HTTP 클라이언트

**Kubernetes 구성**:
```yaml
# 리소스
- CPU: 100m (requests) / 200m (limits)
- Memory: 256Mi (requests) / 512Mi (limits)
- Replicas: Dev 1개, Prod 2개

# 네트워크
- HTTP: 3310
- ClusterIP + Session Affinity (3시간)

# 환경 변수
- NEXT_PUBLIC_AUTH_SERVER_URL: http://auth-server:8000
- NEXT_PUBLIC_PICK_SERVER_URL: http://my-pick-server:8300
- NEXT_PUBLIC_ADMIN_CLIENT_URL: http://my-pick-admin-client:3310
- NEXT_PUBLIC_PORTAL_CLIENT_URL: http://portal-client:3200

# 개발 도구
- NEXT_PUBLIC_ENABLE_DEV_TOOLS: Dev true, Prod false
- NEXT_PUBLIC_ENABLE_MOCK_DATA: false
```

**배포 파일**:
- `applications/my-pick-admin-client/configmap.yaml`
- `applications/my-pick-admin-client/deployment.yaml`
- `applications/my-pick-admin-client/service.yaml`
- `applications/my-pick-admin-client/secret.yaml.template` (현재 사용 안 함, 확장용)
- `applications/my-pick-admin-client/kustomization.yaml`
- `environments/dev/patches/my-pick-admin-client-dev.yaml`
- `environments/prod/patches/my-pick-admin-client-prod.yaml`

---

## 🏗️ 아키텍처 개요

### 전체 서비스 맵 (Phase 1 + Phase 2)

```
┌─────────────────── 프론트엔드 ───────────────────┐
│                                                   │
│  auth-client:3000      portal-client:3200        │
│  portal-admin-client:3210                        │
│  my-pick-client:3300   my-pick-admin-client:3310 │
│                                                   │
└───────────────────┬───────────────────────────────┘
                    │ HTTP API
┌───────────────────┴───────────────────────────────┐
│                                                   │
│  auth-server:8000/8010     authz-server:8100/8110│
│  portal-server:8200/8210   my-pick-server:8300/8310
│                                                   │
└───────────────────┬───────────────────────────────┘
                    │
┌───────────────────┴───────────────────────────────┐
│              공유 인프라 (base)                    │
│                                                   │
│  MySQL:3306 (4개 독립 DB)                         │
│  Redis:6379 (DB 분리)                             │
│                                                   │
└───────────────────────────────────────────────────┘
```

### 서비스 포트 맵

| 서비스 | HTTP | TCP | 용도 |
|--------|------|-----|------|
| **인증/권한** | | | |
| auth-server | 8000 | 8010 | 사용자 인증, OAuth |
| authz-server | 8100 | 8110 | 권한 관리 |
| **포털** | | | |
| portal-server | 8200 | 8210 | 포털 API |
| portal-client | 3200 | - | 포털 사용자 UI |
| portal-admin-client | 3210 | - | 포털 관리자 UI |
| **MyPick** | | | |
| my-pick-server | 8300 | 8310 | MyPick API |
| my-pick-client | 3300 | - | MyPick 사용자 UI |
| my-pick-admin-client | 3310 | - | MyPick 관리자 UI |
| **인증 클라이언트** | | | |
| auth-client | 3000 | - | 인증 전용 UI |

---

## 📂 생성된 파일 구조

```
krgeobuk-k8s/
├── applications/
│   ├── portal-server/           # ✨ Phase 2
│   ├── my-pick-server/          # ✨ Phase 2
│   ├── my-pick-client/          # ✨ Phase 2
│   ├── portal-admin-client/     # ✨ Phase 2
│   └── my-pick-admin-client/    # ✨ Phase 2
│
├── environments/
│   ├── dev/
│   │   ├── kustomization.yaml   # ✅ Phase 2 서비스 추가
│   │   └── patches/
│   │       ├── portal-server-dev.yaml           # ✨ Phase 2
│   │       ├── my-pick-server-dev.yaml          # ✨ Phase 2
│   │       ├── my-pick-client-dev.yaml          # ✨ Phase 2
│   │       ├── portal-admin-client-dev.yaml     # ✨ Phase 2
│   │       └── my-pick-admin-client-dev.yaml    # ✨ Phase 2
│   │
│   └── prod/
│       ├── kustomization.yaml   # ✅ Phase 2 서비스 추가
│       └── patches/
│           ├── portal-server-prod.yaml          # ✨ Phase 2
│           ├── my-pick-server-prod.yaml         # ✨ Phase 2
│           ├── my-pick-client-prod.yaml         # ✨ Phase 2
│           ├── portal-admin-client-prod.yaml    # ✨ Phase 2
│           └── my-pick-admin-client-prod.yaml   # ✨ Phase 2
│
└── base/  # Phase 1에서 완료
```

**Phase 2에서 생성된 파일**: 37개
**총 라인 수**: 1,500+줄

---

## 🎨 환경별 설정 차이

### Dev 환경

```yaml
# 특징: 최소 리소스, 디버그 모드
replicas: 1

resources:
  requests:
    cpu: 50-100m
    memory: 128Mi
  limits:
    cpu: 150-300m
    memory: 256-384Mi

env:
  NODE_ENV: development
  LOG_LEVEL: debug
  NEXT_PUBLIC_DEBUG: true
```

### Prod 환경

```yaml
# 특징: 고가용성, 성능 최적화, 보안 강화
replicas: 2

resources:
  requests:
    cpu: 200-500m
    memory: 256-512Mi
  limits:
    cpu: 400-1000m
    memory: 512Mi-1Gi

# Pod Anti-Affinity (노드 분산 배치)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname

env:
  NODE_ENV: production
  LOG_LEVEL: info
  NEXT_PUBLIC_DEBUG: false
```

---

## 🔐 보안 구성

### 1. Secret 관리

각 서비스별로 민감한 정보를 Secret으로 관리:

**백엔드 서비스**:
- MySQL 비밀번호
- Redis 비밀번호
- JWT Private/Public Keys (RSA)

**my-pick-server 특별 추가**:
- YouTube Data API v3 Key
- Twitter Bearer Token

**프론트엔드 (클라이언트 사이드 API 키)**:
- NEXT_PUBLIC_YOUTUBE_API_KEY (도메인 제한 필요)
- NEXT_PUBLIC_TWITTER_API_KEY (도메인 제한 필요)

### 2. JWT 키 관리

```
auth-server (키 생성자)
  ├── access-private.key   (Secret, 본인만)
  ├── access-public.key    (Secret, 다른 서비스와 공유)
  ├── refresh-private.key  (Secret, 본인만)
  └── refresh-public.key   (Secret, 다른 서비스와 공유)

다른 서비스들 (키 사용자)
  ├── access-public.key    (Secret, auth-server에서 복사)
  └── refresh-public.key   (Secret, auth-server에서 복사)
```

### 3. 네트워크 보안

- **ClusterIP**: 모든 서비스는 클러스터 내부에서만 접근 가능
- **Session Affinity**: ClientIP 기반 3시간 세션 유지
- **Health Check**: Liveness/Readiness Probe로 장애 자동 복구

---

## 📊 리소스 할당

### CPU 할당

| 서비스 유형 | Dev (requests/limits) | Prod (requests/limits) |
|------------|----------------------|------------------------|
| **백엔드** | 100m / 300m | 500m / 1000m |
| **프론트엔드** | 50m / 150m | 200m / 400m |

### 메모리 할당

| 서비스 유형 | Dev (requests/limits) | Prod (requests/limits) |
|------------|----------------------|------------------------|
| **백엔드** | 128Mi / 384Mi | 512Mi / 1Gi |
| **프론트엔드** | 128Mi / 256Mi | 256Mi / 512Mi |

### 전체 리소스 합계

**Dev 환경** (9개 서비스):
- CPU: ~650m (requests) / ~2000m (limits)
- Memory: ~1.2Gi (requests) / ~3Gi (limits)

**Prod 환경** (18개 Pod, 각 서비스 2 replica):
- CPU: ~6000m (requests) / ~12000m (limits)
- Memory: ~7Gi (requests) / ~14Gi (limits)

---

## 🚀 배포 프로세스

### 1단계: Secret 생성

```bash
# 각 서비스별로 Secret 생성
cd applications/portal-server
cp secret.yaml.template secret.yaml
# secret.yaml 편집 (비밀번호, API 키 입력)
kubectl apply -f secret.yaml -n krgeobuk-dev
```

**주의사항**:
- `secret.yaml`은 Git에 커밋하지 않음 (.gitignore 등록 필수)
- JWT 공개키는 auth-server에서 생성 후 다른 서비스에 복사
- 외부 API 키는 도메인 제한 설정 권장

### 2단계: Kustomize 배포

```bash
# Dev 환경
kubectl apply -k environments/dev

# Prod 환경
kubectl apply -k environments/prod
```

### 3단계: 배포 확인

```bash
# Pod 상태 확인
kubectl get pods -n krgeobuk-dev

# Service 확인
kubectl get svc -n krgeobuk-dev

# 로그 확인
kubectl logs -f <pod-name> -n krgeobuk-dev

# 상세 정보
kubectl describe pod <pod-name> -n krgeobuk-dev
```

---

## ✅ 테스트 체크리스트

Phase 2 배포 후 확인 사항:

### 서비스 상태
- [ ] 모든 Pod가 Running 상태
- [ ] Readiness Probe 통과
- [ ] Service Endpoint 정상 연결

### 네트워크 통신
- [ ] portal-server ↔ auth-server TCP 통신
- [ ] portal-server ↔ authz-server TCP 통신
- [ ] my-pick-server ↔ auth-server TCP 통신
- [ ] my-pick-server ↔ authz-server TCP 통신

### 데이터베이스 연결
- [ ] portal-server → MySQL (portal DB)
- [ ] my-pick-server → MySQL (mypick DB)
- [ ] Redis 연결 (모든 백엔드 서비스)

### 외부 API 연동
- [ ] my-pick-server → YouTube Data API v3
- [ ] my-pick-server → Twitter API v2
- [ ] my-pick-client → my-pick-server API (서버 사이드 연동)

### 프론트엔드
- [ ] portal-client 로딩
- [ ] portal-admin-client 로딩 및 관리자 권한 검증
- [ ] my-pick-client 로딩
- [ ] my-pick-admin-client 로딩 및 관리자 권한 검증

### 헬스 체크
- [ ] /health 엔드포인트 응답 (백엔드)
- [ ] / 엔드포인트 응답 (프론트엔드)

---

## 🎉 Phase 2 성과

### 정량적 성과

- ✅ **5개 서비스** Kubernetes 배포 구성 완료
- ✅ **37개 파일** 생성 (1,500+줄)
- ✅ **2개 환경** (dev, prod) 설정 완료
- ✅ **외부 API 통합** (YouTube, Twitter)
- ✅ **멀티서버 HTTP 클라이언트** 적용 (portal-admin-client)

### 정성적 성과

- 🎯 **완전한 마이크로서비스 생태계**: 9개 서비스 모두 Kubernetes 준비 완료
- 🔐 **보안 강화**: Secret 분리, JWT 키 관리 체계화
- 📈 **확장성 확보**: 환경별 리소스 조정, Pod Anti-Affinity
- 🌐 **외부 서비스 연동**: YouTube/Twitter API 통합 구조 확립
- 📚 **표준화**: Phase 1 패턴을 Phase 2에 일관되게 적용

---

## 🔄 다음 단계 (Phase 3 계획)

### 우선순위 높음

1. **Ingress 설정** - 외부에서 HTTPS 접근
   - NGINX Ingress Controller
   - Let's Encrypt TLS 인증서
   - 도메인별 라우팅

2. **Secret 배포 가이드** - 운영 편의성
   - JWT 키 생성 스크립트
   - Secret YAML 생성 자동화
   - 배포 체크리스트

### 우선순위 중간

3. **Monitoring & Logging** - 운영 가시성
   - Prometheus + Grafana
   - Loki (로그 수집)
   - Alert Manager

4. **CI/CD Pipeline** - 배포 자동화
   - GitHub Actions
   - Docker 이미지 자동 빌드
   - Rolling Update

### 우선순위 낮음

5. **Database Migration** - 데이터 초기화
   - MySQL 스키마 자동 생성
   - Seed 데이터 주입
   - Kubernetes Job

6. **Horizontal Pod Autoscaler** - 자동 스케일링
   - CPU/메모리 기반 자동 확장
   - 트래픽 증가 대응

---

## 📝 주요 파일 커밋

**커밋 해시**: `258c60c`

**커밋 메시지**:
```
feat: Add Phase 2 services to Kubernetes infrastructure

Phase 2 완료: 5개 추가 서비스 Kubernetes 배포 구성

## 추가된 서비스 (Phase 2)
- portal-server (8200/8210): 포털 백엔드 서비스
- my-pick-server (8300/8310): MyPick 백엔드 서비스
- my-pick-client (3300): MyPick 프론트엔드
- portal-admin-client (3210): 포털 관리자 인터페이스
- my-pick-admin-client (3310): MyPick 관리자 인터페이스

🤖 Generated with Claude Code
```

---

## 🎓 학습 내용

Phase 2를 통해 학습한 Kubernetes 개념:

1. **ConfigMap vs Secret**
   - ConfigMap: 일반 환경 변수
   - Secret: 민감한 정보 (Base64 인코딩)

2. **Volume Mount**
   - Secret을 파일로 마운트
   - 경로 지정 방법

3. **Kustomize Overlay**
   - Base + Patch 패턴
   - 환경별 오버라이드

4. **Pod Anti-Affinity**
   - 고가용성을 위한 노드 분산
   - topologyKey 활용

5. **Session Affinity**
   - ClientIP 기반 세션 유지
   - 캐싱 성능 향상

---

## 📞 문의 및 지원

Phase 2 관련 문의사항은 다음을 참고하세요:

- **Phase 2 체크리스트**: `docs/phase2/PHASE2_CHECKLIST.md`
- **Kubernetes 아키텍처**: `KUBERNETES_ARCHITECTURE.md`
- **빠른 시작 가이드**: `QUICKSTART.md`

---

**작성자**: Claude Code
**프로젝트**: krgeobuk-k8s
**버전**: Phase 2 Complete
