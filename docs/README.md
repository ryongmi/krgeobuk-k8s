# krgeobuk-k8s 문서

krgeobuk Kubernetes 인프라 구축 프로젝트의 전체 문서입니다.

---

## 📚 문서 구조

```
docs/
├── README.md              # 이 파일 (문서 인덱스)
├── phase1/                # Phase 1 문서
│   ├── PHASE1_SUMMARY.md      # Phase 1 완료 보고서
│   └── PHASE1_CHECKLIST.md    # Phase 1 배포 체크리스트
└── phase2/                # Phase 2 문서
    ├── PHASE2_SUMMARY.md      # Phase 2 완료 보고서
    └── PHASE2_CHECKLIST.md    # Phase 2 배포 체크리스트
```

---

## 🎯 Phase별 문서

### Phase 1: 기본 서비스 (4개)

**서비스**:
- auth-server (인증 서버)
- auth-client (인증 클라이언트)
- authz-server (권한 서버)
- portal-client (포털 클라이언트)

**문서**:
- [📄 Phase 1 완료 보고서](phase1/PHASE1_SUMMARY.md) - Phase 1 작업 내용 및 성과
- [✅ Phase 1 체크리스트](phase1/PHASE1_CHECKLIST.md) - Phase 1 배포 가이드

### Phase 2: 추가 서비스 (5개)

**서비스**:
- portal-server (포털 백엔드)
- my-pick-server (MyPick 백엔드)
- my-pick-client (MyPick 클라이언트)
- portal-admin-client (포털 관리자)
- my-pick-admin-client (MyPick 관리자)

**문서**:
- [📄 Phase 2 완료 보고서](phase2/PHASE2_SUMMARY.md) - Phase 2 작업 내용 및 성과
- [✅ Phase 2 체크리스트](phase2/PHASE2_CHECKLIST.md) - Phase 2 배포 가이드

---

## 🚀 빠른 시작

### 1. 전체 배포 (Phase 1 + Phase 2)

```bash
# Dev 환경 배포
kubectl apply -k environments/dev

# Prod 환경 배포
kubectl apply -k environments/prod
```

### 2. 배포 순서 (처음 배포하는 경우)

1. **Phase 1 배포 및 검증**
   - [Phase 1 체크리스트](phase1/PHASE1_CHECKLIST.md) 참고
   - auth-server, authz-server 정상 작동 확인

2. **Phase 2 배포 및 검증**
   - [Phase 2 체크리스트](phase2/PHASE2_CHECKLIST.md) 참고
   - 모든 서비스 통합 테스트

### 3. Secret 생성 우선순위

**필수 (Phase 1)**:
1. auth-server JWT 키 생성
2. auth-server Secret 생성
3. authz-server Secret 생성 (auth-server JWT 공개키 포함)

**필수 (Phase 2)**:
4. portal-server Secret 생성 (auth-server JWT 공개키 포함)
5. my-pick-server Secret 생성 (auth-server JWT 공개키 + YouTube/Twitter API 키)
6. my-pick-client Secret 생성 (클라이언트 사이드 API 키)

**선택 (미래 확장)**:
- portal-admin-client Secret (현재 불필요)
- my-pick-admin-client Secret (현재 불필요)

---

## 📖 주요 개념

### Kubernetes 리소스

- **ConfigMap**: 일반 환경 변수 저장 (DB 호스트, 포트 등)
- **Secret**: 민감한 정보 저장 (비밀번호, API 키 등)
- **Deployment**: Pod 배포 정의 (replicas, 리소스, health check)
- **Service**: 네트워크 엔드포인트 (고정 DNS, 로드밸런싱)
- **Kustomize**: 환경별 설정 관리 (Base + Overlay 패턴)

### 환경 구분

| 환경 | Namespace | Replicas | 리소스 | 로그 레벨 |
|------|-----------|----------|--------|-----------|
| **Dev** | krgeobuk-dev | 1 | 최소 | debug |
| **Prod** | krgeobuk-prod | 2+ | 최대 | info/error |

### 서비스 포트 맵

| 서비스 | HTTP | TCP | 데이터베이스 |
|--------|------|-----|-------------|
| auth-server | 8000 | 8010 | auth |
| authz-server | 8100 | 8110 | authz |
| portal-server | 8200 | 8210 | portal |
| my-pick-server | 8300 | 8310 | mypick |
| auth-client | 3000 | - | - |
| portal-client | 3200 | - | - |
| portal-admin-client | 3210 | - | - |
| my-pick-client | 3300 | - | - |
| my-pick-admin-client | 3310 | - | - |

---

## 🔍 문서 찾기

### 배포 관련
- Phase 1 처음 배포: [Phase 1 체크리스트](phase1/PHASE1_CHECKLIST.md)
- Phase 2 처음 배포: [Phase 2 체크리스트](phase2/PHASE2_CHECKLIST.md)
- Secret 생성 방법: Phase별 체크리스트의 "Secret 생성" 섹션

### 아키텍처 관련
- Phase 1 아키텍처: [Phase 1 보고서](phase1/PHASE1_SUMMARY.md)
- Phase 2 아키텍처: [Phase 2 보고서](phase2/PHASE2_SUMMARY.md)
- 전체 서비스 맵: [Phase 2 보고서 - 아키텍처 개요](phase2/PHASE2_SUMMARY.md#-아키텍처-개요)

### 트러블슈팅
- 배포 문제: Phase별 체크리스트의 "트러블슈팅" 섹션
- Pod 상태 이슈: [Phase 2 체크리스트 - 트러블슈팅](phase2/PHASE2_CHECKLIST.md#-트러블슈팅)

### 운영 가이드
- 리소스 사용량 확인: Phase별 체크리스트의 "리소스 사용량 확인" 섹션
- 로그 확인 방법: Phase별 체크리스트의 "로그 확인" 섹션

---

## 🛠️ 자주 사용하는 명령어

### 배포 및 업데이트

```bash
# Dev 환경 배포
kubectl apply -k environments/dev

# Prod 환경 배포
kubectl apply -k environments/prod

# 특정 서비스만 재배포
kubectl rollout restart deployment portal-server -n krgeobuk-dev
```

### 상태 확인

```bash
# Pod 상태
kubectl get pods -n krgeobuk-dev
kubectl get pods -n krgeobuk-prod -o wide

# Service 확인
kubectl get svc -n krgeobuk-dev

# 로그 확인
kubectl logs -f <pod-name> -n krgeobuk-dev

# 리소스 사용량
kubectl top pods -n krgeobuk-dev
```

### 디버깅

```bash
# Pod 상세 정보
kubectl describe pod <pod-name> -n krgeobuk-dev

# Pod 내부 접속
kubectl exec -it <pod-name> -n krgeobuk-dev -- sh

# Port Forward (로컬 테스트)
kubectl port-forward svc/portal-server 8200:8200 -n krgeobuk-dev
```

---

## 📅 버전 히스토리

| Phase | 완료일 | 서비스 수 | 파일 수 | 주요 내용 |
|-------|--------|----------|---------|-----------|
| Phase 1 | 2024-12-21 | 4개 | ~30개 | 기본 인증/권한 서비스 |
| Phase 2 | 2024-12-22 | 5개 | 37개 | 포털/MyPick 서비스 |
| **합계** | - | **9개** | **~67개** | **전체 생태계 완성** |

---

## 🔜 다음 단계 (Phase 3)

### 계획 중인 기능

1. **Ingress**: 외부에서 HTTPS 접근
2. **Monitoring**: Prometheus + Grafana
3. **CI/CD**: GitHub Actions 자동 배포
4. **Auto Scaling**: HPA (Horizontal Pod Autoscaler)
5. **Database Migration**: 스키마 자동 생성

---

## 📞 문의 및 기여

- **이슈 제기**: GitHub Issues
- **문서 개선**: Pull Request 환영
- **질문**: 각 Phase별 체크리스트의 트러블슈팅 섹션 참고

---

**프로젝트**: krgeobuk-k8s
**관리자**: krgeobuk team
**마지막 업데이트**: 2024-12-22
