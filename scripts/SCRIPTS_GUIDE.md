# 배포 자동화 스크립트 가이드

Kubernetes 배포, 롤백, 모니터링을 위한 자동화 스크립트 모음입니다.

---

## 📁 스크립트 목록

| 스크립트          | 설명               | 주요 기능                             |
| ----------------- | ------------------ | ------------------------------------- |
| `deploy.sh`       | 환경별 서비스 배포 | Kustomize 기반 배포, 롤아웃 상태 확인 |
| `rollback.sh`     | 이전 버전으로 롤백 | Deployment 롤백, Revision 관리        |
| `health-check.sh` | 서비스 헬스 체크   | Pod/Service 상태, 리소스 사용량       |
| `logs.sh`         | Pod 로그 수집      | 실시간 스트리밍, 로그 필터링          |

---

## 🚀 빠른 시작

### 전체 배포 워크플로우

```bash
# 1. Secret 생성 (최초 1회)
./scripts/generate-jwt-keys.sh
./scripts/validate-secrets.sh .env
./scripts/create-secrets.sh auth-server .env
# ... (다른 서비스도 동일)

# 2. Dev 환경 전체 배포
./scripts/deploy.sh dev all

# 3. 배포 상태 확인
./scripts/health-check.sh dev

# 4. 로그 확인
./scripts/logs.sh dev auth-server -f

# 5. 문제 발생 시 롤백
./scripts/rollback.sh dev auth-server
```

---

## 📖 상세 사용법

### deploy.sh - 서비스 배포

환경별로 서비스를 배포하고 롤아웃 상태를 확인합니다.

#### 기본 사용법

```bash
./scripts/deploy.sh <environment> <service>
```

#### 환경 (Environment)

- `dev` - 개발 환경 (krgeobuk-dev 네임스페이스)
- `prod` - 프로덕션 환경 (krgeobuk-prod 네임스페이스)

#### 서비스 (Service)

- `all` - 모든 서비스 (인프라 + 애플리케이션)
- `infrastructure` - MySQL, Redis, Verdaccio
- `auth-server` - 인증 서버
- `auth-client` - 인증 클라이언트
- `authz-server` - 권한 서버
- `portal-server` - 포털 서버
- `portal-client` - 포털 클라이언트
- `mypick-server` - MyPick 서버
- `mypick-client` - MyPick 클라이언트
- `portal-admin-client` - 포털 관리자 클라이언트
- `mypick-admin-client` - MyPick 관리자 클라이언트

#### 예시

```bash
# Dev 환경 전체 배포
./scripts/deploy.sh dev all

# Prod 환경 auth-server만 배포
./scripts/deploy.sh prod auth-server

# Dev 환경 인프라만 배포
./scripts/deploy.sh dev infrastructure
```

#### 동작 과정

1. **환경 검증** - kubectl 연결, 네임스페이스 확인
2. **배포 확인** - 배포할 서비스 목록 확인 후 사용자 승인
3. **Kustomize 빌드** - 환경별 설정 적용
4. **kubectl apply** - 리소스 배포
5. **롤아웃 확인** - Deployment 롤아웃 상태 모니터링
6. **상태 보고** - Pod, Service 상태 출력

#### 출력 예시

```
========================================
Kubernetes 배포 자동화 스크립트
========================================

배포 환경: dev (krgeobuk-dev)
배포 대상: auth-server

✓ kubectl 연결 확인 완료
✓ 네임스페이스 확인 완료: krgeobuk-dev

배포를 진행하시겠습니까? (y/N): y

========================================
배포 중: auth-server
========================================
경로: applications/auth-server/overlays/dev
Kustomize 빌드 및 적용 중...
✓ auth-server 배포 완료
롤아웃 상태 확인 중...
  ✓ auth-server-deployment 롤아웃 완료

========================================
배포 결과 요약
========================================
성공: 1개
실패: 0개

✓ 모든 서비스 배포가 완료되었습니다!
```

---

### rollback.sh - 배포 롤백

Deployment를 이전 버전 또는 특정 Revision으로 롤백합니다.

#### 기본 사용법

```bash
./scripts/rollback.sh <environment> <service> [revision]
```

#### 인자

- `environment` - dev 또는 prod
- `service` - 롤백할 서비스 이름
- `revision` (선택) - 특정 Revision 번호

#### 예시

```bash
# 이전 버전으로 롤백
./scripts/rollback.sh dev auth-server

# Revision 3으로 롤백
./scripts/rollback.sh prod auth-server 3

# 롤백 시뮬레이션 (실제 롤백 안 함)
./scripts/rollback.sh dev auth-server --dry-run
```

#### 동작 과정

1. **Deployment 확인** - 롤백 가능한 Deployment 확인
2. **히스토리 조회** - 롤아웃 히스토리 표시
3. **현재 Revision** - 현재 실행 중인 버전 확인
4. **롤백 확인** - 사용자 승인 (dry-run 제외)
5. **롤백 실행** - `kubectl rollout undo` 실행
6. **상태 확인** - 롤아웃 완료 대기 및 확인

#### 출력 예시

```
========================================
롤백 대상: auth-server-deployment
========================================

롤아웃 히스토리:
REVISION  CHANGE-CAUSE
1         <none>
2         Update image to v1.2.0
3         Update image to v1.3.0

현재 Revision: 3

롤백을 진행하시겠습니까? (y/N): y

롤백 실행 중...
✓ 이전 버전으로 롤백 시작됨
롤아웃 상태 확인 중...
✓ 롤백 완료

롤백 후 Revision: 4

✓ 롤백이 완료되었습니다!
```

#### Revision 관리 팁

```bash
# 롤아웃 히스토리 확인
kubectl rollout history deployment/auth-server-deployment -n krgeobuk-dev

# 특정 Revision 상세 정보
kubectl rollout history deployment/auth-server-deployment -n krgeobuk-dev --revision=2

# 현재 Revision 확인
kubectl get deployment auth-server-deployment -n krgeobuk-dev -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
```

---

### health-check.sh - 헬스 체크

전체 또는 특정 서비스의 헬스 상태를 확인합니다.

#### 기본 사용법

```bash
./scripts/health-check.sh <environment> [service]
```

#### 인자

- `environment` - dev 또는 prod
- `service` (선택) - 특정 서비스만 체크, 생략 시 전체

#### 예시

```bash
# Dev 환경 전체 체크
./scripts/health-check.sh dev

# Prod 환경 auth-server만 체크
./scripts/health-check.sh prod auth-server
```

#### 체크 항목

1. **Pod 상태**

   - Running/Ready 상태
   - Restart 횟수
   - Container 상태

2. **Service 엔드포인트**

   - Endpoint IP 확인
   - Service 연결 상태

3. **Deployment 상태**

   - Desired vs Ready 비교
   - Available replicas

4. **리소스 사용량**

   - 노드 리소스 (CPU, Memory)
   - Pod 리소스 사용량

5. **이벤트 확인**
   - 최근 Warning/Error 이벤트

#### 출력 예시

```
========================================
서비스: auth-server
========================================
  ✓ auth-server-deployment-abc123 - Healthy (Restarts: 0)
  ⚠ auth-server-deployment-def456 - Running with restarts (Restarts: 2)

Endpoints:
  ✓ Endpoints: 10.244.0.10 10.244.0.11

Deployment 상태:
  ✓ auth-server-deployment: 2/2 ready

✓ auth-server: Healthy

========================================
헬스 체크 요약
========================================
환경: dev (krgeobuk-dev)
체크 시간: 2024-12-23 10:30:00

서비스 상태:
  총 서비스: 8
  Healthy: 7
  Unhealthy: 1

Pod 상태:
  총 Pods: 16
  Healthy: 15
  Unhealthy: 1

✗ 일부 서비스에 문제가 있습니다.
```

#### 헬스 체크 자동화

```bash
# Cron으로 정기 헬스 체크 (5분마다)
*/5 * * * * /path/to/scripts/health-check.sh prod > /var/log/k8s-health.log 2>&1
```

---

### logs.sh - 로그 수집

Pod 로그를 조회하고 분석합니다.

#### 기본 사용법

```bash
./scripts/logs.sh <environment> <service> [options]
```

#### 옵션

| 옵션                 | 설명                              |
| -------------------- | --------------------------------- |
| `-f, --follow`       | 실시간 로그 스트리밍              |
| `-p, --previous`     | 이전 컨테이너 로그 (crashed pod)  |
| `--tail N`           | 마지막 N줄만 표시 (기본: 100)     |
| `--timestamps`       | 타임스탬프 표시                   |
| `--all-pods`         | 모든 Pod 로그 병합                |
| `--pod <name>`       | 특정 Pod만 조회                   |
| `--container <name>` | 특정 컨테이너만 조회              |
| `--since <duration>` | 특정 시간 이후 로그 (예: 1h, 30m) |

#### 예시

```bash
# 기본 로그 조회 (마지막 100줄)
./scripts/logs.sh dev auth-server

# 실시간 로그 스트리밍
./scripts/logs.sh dev auth-server -f

# 마지막 500줄
./scripts/logs.sh dev auth-server --tail 500

# 최근 1시간 로그
./scripts/logs.sh dev auth-server --since 1h

# 이전 컨테이너 로그 (Crashed Pod)
./scripts/logs.sh dev auth-server -p

# 모든 Pod 로그
./scripts/logs.sh dev auth-server --all-pods

# 특정 Pod 로그
./scripts/logs.sh dev auth-server --pod auth-server-deployment-abc123

# 타임스탬프 포함
./scripts/logs.sh dev auth-server --timestamps
```

#### 로그 필터링

```bash
# 로그에서 에러만 필터링
./scripts/logs.sh dev auth-server --tail 1000 | grep -i error

# 특정 키워드 검색
./scripts/logs.sh dev auth-server --since 1h | grep "JWT"

# 여러 Pod 로그를 시간순으로 정렬 (stern 권장)
stern auth-server -n krgeobuk-dev --since 1h
```

#### 출력 예시

```
========================================
Pod: auth-server-deployment-abc123
========================================
상태: Running | Ready: True

컨테이너: auth-server

로그 (컨테이너: auth-server):
[2024-12-23 10:25:30] INFO: Application started
[2024-12-23 10:25:31] INFO: Database connected
[2024-12-23 10:25:32] INFO: Redis connected
[2024-12-23 10:25:33] INFO: Server listening on port 8000
[2024-12-23 10:26:00] DEBUG: GET /health - 200
```

---

## 🎯 실전 시나리오

### 시나리오 1: 새 버전 배포

```bash
# 1. Secret 업데이트 (필요한 경우)
./scripts/create-secrets.sh auth-server .env
kubectl apply -f applications/auth-server/secret.yaml -n krgeobuk-dev

# 2. 배포 전 헬스 체크
./scripts/health-check.sh dev auth-server

# 3. 배포 실행
./scripts/deploy.sh dev auth-server

# 4. 배포 후 헬스 체크
./scripts/health-check.sh dev auth-server

# 5. 로그 모니터링
./scripts/logs.sh dev auth-server -f
```

### 시나리오 2: 배포 실패 대응

```bash
# 1. 문제 확인
./scripts/health-check.sh dev auth-server

# 2. 로그 확인
./scripts/logs.sh dev auth-server --tail 500

# 3. 이전 컨테이너 로그 확인 (Pod가 재시작된 경우)
./scripts/logs.sh dev auth-server -p

# 4. Pod 상세 정보
kubectl describe pod <pod-name> -n krgeobuk-dev

# 5. 롤백 결정
./scripts/rollback.sh dev auth-server

# 6. 롤백 후 확인
./scripts/health-check.sh dev auth-server
```

### 시나리오 3: 프로덕션 배포

```bash
# 1. Dev 환경 테스트
./scripts/deploy.sh dev auth-server
./scripts/health-check.sh dev auth-server

# 2. Dev 환경 로그 확인 (30분 모니터링)
./scripts/logs.sh dev auth-server --since 30m

# 3. Prod 환경 배포
./scripts/deploy.sh prod auth-server

# 4. Prod 환경 실시간 모니터링
./scripts/logs.sh prod auth-server -f

# 5. 별도 터미널에서 헬스 체크
watch -n 10 ./scripts/health-check.sh prod auth-server
```

### 시나리오 4: 전체 시스템 재배포

```bash
# 1. 인프라 먼저 배포
./scripts/deploy.sh dev infrastructure
sleep 30  # 인프라 안정화 대기

# 2. 백엔드 서비스 배포
./scripts/deploy.sh dev auth-server
./scripts/deploy.sh dev authz-server
./scripts/deploy.sh dev portal-server
./scripts/deploy.sh dev mypick-server

# 3. 프론트엔드 배포
./scripts/deploy.sh dev mypick-client
./scripts/deploy.sh dev portal-admin-client
./scripts/deploy.sh dev mypick-admin-client

# 4. 전체 헬스 체크
./scripts/health-check.sh dev

# 5. 각 서비스 로그 확인
for service in auth-server authz-server portal-server mypick-server; do
    echo "=== $service logs ==="
    ./scripts/logs.sh dev $service --tail 50
done
```

---

## 🛠️ 트러블슈팅

### 문제 1: kubectl 연결 실패

**증상**:

```
오류: Kubernetes 클러스터에 연결할 수 없습니다.
```

**해결**:

```bash
# 클러스터 정보 확인
kubectl cluster-info

# Context 확인
kubectl config current-context

# Context 변경
kubectl config use-context <context-name>

# kubeconfig 확인
echo $KUBECONFIG
```

### 문제 2: 배포 타임아웃

**증상**:

```
⚠ auth-server-deployment 롤아웃 타임아웃
```

**해결**:

```bash
# 1. Pod 상태 확인
kubectl get pods -n krgeobuk-dev -l app=auth-server

# 2. Pod 이벤트 확인
kubectl describe pod <pod-name> -n krgeobuk-dev

# 3. 로그 확인
./scripts/logs.sh dev auth-server

# 4. 리소스 부족 확인
kubectl top nodes
kubectl describe nodes

# 5. 이미지 Pull 실패 확인
kubectl get events -n krgeobuk-dev | grep -i pull
```

### 문제 3: Secret 없음

**증상**:

```
Error: secrets "auth-server-secrets" not found
```

**해결**:

```bash
# 1. Secret 존재 확인
kubectl get secrets -n krgeobuk-dev

# 2. Secret 생성
./scripts/create-secrets.sh auth-server .env
kubectl apply -f applications/auth-server/secret.yaml -n krgeobuk-dev

# 3. Secret 적용 확인
kubectl get secret auth-server-secrets -n krgeobuk-dev
```

### 문제 4: Pod CrashLoopBackOff

**증상**:

```
auth-server-deployment-abc123   0/1     CrashLoopBackOff
```

**해결**:

```bash
# 1. 현재 로그 확인
./scripts/logs.sh dev auth-server

# 2. 이전 컨테이너 로그 확인
./scripts/logs.sh dev auth-server -p

# 3. Pod 이벤트 확인
kubectl describe pod <pod-name> -n krgeobuk-dev

# 4. ConfigMap/Secret 확인
kubectl get configmap -n krgeobuk-dev
kubectl get secret -n krgeobuk-dev

# 5. 환경 변수 확인
kubectl exec -it <pod-name> -n krgeobuk-dev -- env
```

### 문제 5: Service 접근 불가

**증상**:

```
⚠ Endpoints가 없습니다.
```

**해결**:

```bash
# 1. Service 확인
kubectl get svc -n krgeobuk-dev

# 2. Endpoints 확인
kubectl get endpoints -n krgeobuk-dev

# 3. Service 상세 정보
kubectl describe svc <service-name> -n krgeobuk-dev

# 4. Selector 확인
kubectl get svc <service-name> -n krgeobuk-dev -o yaml | grep selector

# 5. Pod 레이블 확인
kubectl get pods -n krgeobuk-dev --show-labels
```

---

## 📋 모범 사례

### 1. 배포 전 체크리스트

- [ ] Secret이 최신 상태인지 확인
- [ ] ConfigMap이 업데이트되었는지 확인
- [ ] 리소스 할당이 충분한지 확인 (CPU, Memory)
- [ ] 이미지 태그가 올바른지 확인
- [ ] Dev 환경에서 먼저 테스트
- [ ] 헬스 체크 통과 확인

### 2. 배포 순서

```
1. Infrastructure (MySQL, Redis, Verdaccio)
   ↓
2. Auth Server (다른 서비스가 의존)
   ↓
3. Authz Server (권한 관리)
   ↓
4. Backend Services (Portal, MyPick)
   ↓
5. Frontend Services (클라이언트)
```

### 3. 모니터링 주기

```bash
# 배포 직후: 실시간 모니터링 (5분)
./scripts/logs.sh dev auth-server -f

# 안정화 단계: 정기 헬스 체크 (10분마다)
watch -n 600 ./scripts/health-check.sh dev

# 정상 운영: 자동 헬스 체크 (1시간마다)
# Cron: 0 * * * * /path/to/scripts/health-check.sh prod
```

### 4. 롤백 기준

다음 상황에서 즉시 롤백:

- Pod가 5분 이상 Running 상태로 전환되지 않음
- Restart 횟수가 3회 이상
- 에러 로그가 초당 10개 이상 발생
- CPU/Memory 사용률이 90% 이상
- Health check endpoint가 응답하지 않음

### 5. 로그 보관

```bash
# 배포 로그 저장
./scripts/deploy.sh dev auth-server 2>&1 | tee deploy-$(date +%Y%m%d-%H%M%S).log

# 헬스 체크 결과 저장
./scripts/health-check.sh dev > health-$(date +%Y%m%d-%H%M%S).log

# 에러 로그만 추출
./scripts/logs.sh dev auth-server --since 1h | grep -i error > errors.log
```

---

## 🔗 관련 문서

- [Secret 생성 가이드](./README.md) - JWT 키 생성 및 Secret 관리
- [Phase 1 체크리스트](../docs/phase1/PHASE1_CHECKLIST.md) - Phase 1 배포 가이드
- [Phase 2 체크리스트](../docs/phase2/PHASE2_CHECKLIST.md) - Phase 2 배포 가이드
- [빠른 시작 가이드](../QUICKSTART.md) - 전체 시스템 빠른 시작

---

## 💡 추가 도구

### Stern - 멀티 Pod 로그

여러 Pod의 로그를 동시에 스트리밍:

```bash
# Stern 설치
# macOS
brew install stern

# Linux
wget https://github.com/stern/stern/releases/download/v1.28.0/stern_1.28.0_linux_amd64.tar.gz
tar -xzf stern_1.28.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/

# 사용
stern auth-server -n krgeobuk-dev
stern auth-server -n krgeobuk-dev --since 1h
stern auth-server -n krgeobuk-dev --tail 50
```

### K9s - Kubernetes CLI UI

터미널 기반 Kubernetes UI:

```bash
# K9s 설치
# macOS
brew install k9s

# Linux
wget https://github.com/derailed/k9s/releases/download/v0.31.7/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/

# 사용
k9s -n krgeobuk-dev
```

---

**작성자**: Claude Code
**버전**: 1.0.0
**마지막 업데이트**: 2024-12-23
