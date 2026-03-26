# Phase 2 배포 체크리스트

Phase 2 서비스를 Kubernetes에 배포하기 위한 단계별 체크리스트입니다.

---

## 📋 사전 준비

### 1. 환경 확인
- [ ] Kubernetes 클러스터 실행 중
- [ ] kubectl 설치 및 클러스터 연결 확인
- [ ] Phase 1 서비스 정상 작동 확인 (auth-server, authz-server 등)
- [ ] MySQL 및 Redis 정상 작동 확인

### 2. 필요한 도구
- [ ] kubectl (v1.25+)
- [ ] kustomize (v4.0+) 또는 kubectl의 내장 kustomize
- [ ] git (서브모듈 관리용)

### 3. 리포지토리 확인
```bash
# krgeobuk-k8s 서브모듈 최신 상태로 업데이트
cd /path/to/krgeobuk-infra
git submodule update --remote krgeobuk-k8s
cd krgeobuk-k8s
git status  # Phase 2 변경사항 확인
```

---

## 🔐 1단계: Secret 생성

각 서비스별로 Secret을 생성해야 합니다.

### 1.1 portal-server Secret

```bash
cd applications/portal-server
cp secret.yaml.template secret.yaml
```

**secret.yaml 편집 필요 항목**:
- [ ] `MYSQL_PASSWORD`: krgeobuk-infrastructure의 MySQL 비밀번호와 동일하게
- [ ] `REDIS_PASSWORD`: krgeobuk-infrastructure의 Redis 비밀번호와 동일하게
- [ ] `auth-server-jwt-keys`에서 JWT 공개키 복사
  - [ ] `access-public.key` (auth-server에서 생성된 키)
  - [ ] `refresh-public.key` (auth-server에서 생성된 키)

**적용**:
```bash
# Dev 환경
kubectl apply -f secret.yaml -n krgeobuk-dev

# Prod 환경
kubectl apply -f secret.yaml -n krgeobuk-prod
```

### 1.2 mypick-server Secret

```bash
cd applications/mypick-server
cp secret.yaml.template secret.yaml
```

**secret.yaml 편집 필요 항목**:
- [ ] `MYSQL_PASSWORD`: krgeobuk-infrastructure의 MySQL 비밀번호
- [ ] `REDIS_PASSWORD`: krgeobuk-infrastructure의 Redis 비밀번호
- [ ] `YOUTUBE_API_KEY`: YouTube Data API v3 키 ([발급 방법](#youtube-api-키-발급))
- [ ] `TWITTER_BEARER_TOKEN`: Twitter API v2 Bearer Token ([발급 방법](#twitter-api-키-발급))
- [ ] JWT 공개키 복사 (auth-server에서)
  - [ ] `access-public.key`
  - [ ] `refresh-public.key`

**적용**:
```bash
kubectl apply -f secret.yaml -n krgeobuk-dev
kubectl apply -f secret.yaml -n krgeobuk-prod
```

### 1.3 mypick-client Secret

**⚠️ 현재 mypick-client는 별도의 Secret이 필요하지 않습니다.**
- YouTube, Twitter API 관련 환경 변수는 레거시로 제거되었습니다.
- Secret 생성 및 적용을 건너뛰어도 됩니다.

### 1.4 portal-admin-client Secret

- [ ] 현재 Secret 불필요 (내부 서비스만 사용)
- [ ] 미래 확장을 위해 템플릿만 제공됨

### 1.5 mypick-admin-client Secret

- [ ] 현재 Secret 불필요 (내부 서비스만 사용)
- [ ] 미래 확장을 위해 템플릿만 제공됨

---

## 🚀 2단계: 서비스 배포

### 2.1 Dev 환경 배포

```bash
# krgeobuk-k8s 루트에서 실행
cd /path/to/krgeobuk-infra/krgeobuk-k8s

# Kustomize로 일괄 배포
kubectl apply -k environments/dev
```

**배포 확인**:
```bash
# Pod 상태 확인 (모두 Running이 되어야 함)
kubectl get pods -n krgeobuk-dev

# 예상 출력:
# NAME                                    READY   STATUS    RESTARTS
# auth-server-xxx                         1/1     Running   0
# authz-server-xxx                        1/1     Running   0
# portal-server-xxx                       1/1     Running   0
# mypick-server-xxx                      1/1     Running   0
# mypick-client-xxx                      1/1     Running   0
# portal-admin-client-xxx                 1/1     Running   0
# mypick-admin-client-xxx                1/1     Running   0
```

**체크리스트**:
- [ ] `portal-server` Pod가 Running 상태
- [ ] `mypick-server` Pod가 Running 상태
- [ ] `mypick-client` Pod가 Running 상태
- [ ] `portal-admin-client` Pod가 Running 상태
- [ ] `mypick-admin-client` Pod가 Running 상태

### 2.2 Prod 환경 배포

```bash
# Prod 환경 배포
kubectl apply -k environments/prod
```

**배포 확인**:
```bash
# Pod 상태 확인 (각 서비스당 2개씩)
kubectl get pods -n krgeobuk-prod -o wide

# Pod가 서로 다른 노드에 분산되었는지 확인
# NODE 컬럼에서 확인
```

**체크리스트**:
- [ ] 각 서비스당 2개의 Pod가 Running
- [ ] Pod Anti-Affinity가 작동하여 다른 노드에 분산 배치됨
- [ ] 모든 Pod의 READY가 1/1 상태

---

## ✅ 3단계: 배포 검증

### 3.1 Pod 상태 검증

```bash
# 모든 Pod 확인
kubectl get pods -n krgeobuk-dev

# 특정 Pod 상세 정보
kubectl describe pod portal-server-xxx -n krgeobuk-dev
```

**확인 사항**:
- [ ] `STATUS`가 모두 `Running`
- [ ] `READY`가 모두 `1/1`
- [ ] `RESTARTS`가 0 또는 낮은 숫자
- [ ] Events에 에러 없음

### 3.2 Service 확인

```bash
# Service 목록
kubectl get svc -n krgeobuk-dev

# Service Endpoints 확인
kubectl get endpoints -n krgeobuk-dev
```

**확인 사항**:
- [ ] `portal-server` Service 존재 (8200, 8210 포트)
- [ ] `mypick-server` Service 존재 (8300, 8310 포트)
- [ ] `mypick-client` Service 존재 (3300 포트)
- [ ] `portal-admin-client` Service 존재 (3210 포트)
- [ ] `mypick-admin-client` Service 존재 (3310 포트)
- [ ] Endpoints에 Pod IP가 정상적으로 등록됨

### 3.3 로그 확인

```bash
# 각 서비스 로그 확인
kubectl logs -f portal-server-xxx -n krgeobuk-dev
kubectl logs -f mypick-server-xxx -n krgeobuk-dev
kubectl logs -f mypick-client-xxx -n krgeobuk-dev
kubectl logs -f portal-admin-client-xxx -n krgeobuk-dev
kubectl logs -f mypick-admin-client-xxx -n krgeobuk-dev
```

**확인 사항**:
- [ ] 데이터베이스 연결 성공 로그
- [ ] Redis 연결 성공 로그
- [ ] 서버 시작 완료 로그
- [ ] 에러 메시지 없음

---

## 🔍 4단계: 기능 검증

### 4.1 Health Check 엔드포인트

```bash
# Pod 안에서 직접 테스트
kubectl exec -it portal-server-xxx -n krgeobuk-dev -- sh
curl http://localhost:8200/health
# 예상 응답: {"status":"ok"}

# 또는 Port Forward로 로컬에서 테스트
kubectl port-forward svc/portal-server 8200:8200 -n krgeobuk-dev
curl http://localhost:8200/health
```

**체크리스트**:
- [ ] portal-server `/health` 응답 정상
- [ ] mypick-server `/health` 응답 정상
- [ ] mypick-client `/` 응답 정상 (Next.js 페이지)
- [ ] portal-admin-client `/` 응답 정상
- [ ] mypick-admin-client `/` 응답 정상

### 4.2 데이터베이스 연결

```bash
# portal-server 로그에서 MySQL 연결 확인
kubectl logs portal-server-xxx -n krgeobuk-dev | grep -i mysql

# mypick-server 로그에서 MySQL 연결 확인
kubectl logs mypick-server-xxx -n krgeobuk-dev | grep -i mysql
```

**확인 사항**:
- [ ] portal-server → MySQL `portal` DB 연결 성공
- [ ] mypick-server → MySQL `mypick` DB 연결 성공
- [ ] Redis 연결 성공

### 4.3 서비스 간 통신

```bash
# portal-server가 auth-server와 통신하는지 확인
kubectl exec -it portal-server-xxx -n krgeobuk-dev -- sh
nc -zv auth-server 8010  # TCP 통신 확인

# mypick-server가 authz-server와 통신하는지 확인
kubectl exec -it mypick-server-xxx -n krgeobuk-dev -- sh
nc -zv authz-server 8110  # TCP 통신 확인
```

**체크리스트**:
- [ ] portal-server → auth-server:8010 연결 가능
- [ ] portal-server → authz-server:8110 연결 가능
- [ ] mypick-server → auth-server:8010 연결 가능
- [ ] mypick-server → authz-server:8110 연결 가능

### 4.4 외부 API 연동 (mypick-server)

```bash
# mypick-server 로그에서 YouTube API 호출 확인
kubectl logs mypick-server-xxx -n krgeobuk-dev | grep -i youtube

# Twitter API 호출 확인
kubectl logs mypick-server-xxx -n krgeobuk-dev | grep -i twitter
```

**확인 사항**:
- [ ] YouTube Data API v3 연동 정상 (쿼터 확인)
- [ ] Twitter API v2 연동 정상 (쿼터 확인)
- [ ] API 키 인증 성공

### 4.5 JWT 키 확인

```bash
# 각 서비스에서 JWT 공개키 파일 확인
kubectl exec -it portal-server-xxx -n krgeobuk-dev -- sh
ls -la /etc/jwt-keys/
cat /etc/jwt-keys/access-public.key
```

**확인 사항**:
- [ ] `/etc/jwt-keys/access-public.key` 파일 존재
- [ ] `/etc/jwt-keys/refresh-public.key` 파일 존재
- [ ] 파일 권한이 400 (읽기 전용)
- [ ] 파일 내용이 auth-server의 키와 일치

---

## 🧪 5단계: 통합 테스트

### 5.1 프론트엔드 → 백엔드 통신

```bash
# Port Forward로 프론트엔드 접근
kubectl port-forward svc/mypick-client 3300:3300 -n krgeobuk-dev

# 브라우저에서 http://localhost:3300 접속
# 개발자 도구(F12) → Network 탭에서 API 호출 확인
```

**확인 사항**:
- [ ] mypick-client → mypick-server API 호출 성공
- [ ] portal-admin-client → portal-server API 호출 성공
- [ ] JWT 토큰 인증 정상 작동

### 5.2 관리자 권한 검증

```bash
# portal-admin-client 접근
kubectl port-forward svc/portal-admin-client 3210:3210 -n krgeobuk-dev

# 브라우저에서 http://localhost:3210 접속
# AdminAuthGuard 동작 확인
```

**확인 사항**:
- [ ] 비관리자 접근 시 차단
- [ ] 관리자 권한 확인 정상
- [ ] 권한 부족 시 적절한 에러 메시지

---

## 📊 6단계: 리소스 사용량 확인

```bash
# Pod별 리소스 사용량
kubectl top pods -n krgeobuk-dev

# Node별 리소스 사용량
kubectl top nodes
```

**확인 사항**:
- [ ] CPU 사용량이 limit 이하
- [ ] Memory 사용량이 limit 이하
- [ ] Node에 여유 리소스 충분

---

## 🔧 7단계: 설정 검증

### 7.1 ConfigMap 확인

```bash
# ConfigMap 확인
kubectl get configmap -n krgeobuk-dev
kubectl describe configmap portal-server-config -n krgeobuk-dev
```

**확인 사항**:
- [ ] 환경 변수가 올바르게 설정됨
- [ ] 환경별 오버라이드가 적용됨 (dev vs prod)

### 7.2 Secret 확인

```bash
# Secret 존재 확인 (내용은 보안상 확인 불가)
kubectl get secrets -n krgeobuk-dev

# Secret이 Pod에 제대로 마운트되었는지 확인
kubectl exec -it mypick-server-xxx -n krgeobuk-dev -- sh
env | grep YOUTUBE
env | grep TWITTER
```

**확인 사항**:
- [ ] Secret이 모두 생성됨
- [ ] Pod에서 Secret 환경변수 접근 가능
- [ ] JWT 키 파일이 올바른 경로에 마운트됨

---

## 📝 8단계: 문서화

### 8.1 배포 기록

- [ ] 배포 일시 기록
- [ ] 배포한 서비스 버전 기록
- [ ] 발생한 이슈 및 해결 방법 기록

### 8.2 운영 문서 작성

- [ ] Secret 관리 절차 문서화
- [ ] 롤백 절차 문서화
- [ ] 트러블슈팅 가이드 작성

---

## 🚨 트러블슈팅

### 문제 1: Pod가 Pending 상태

**증상**:
```bash
kubectl get pods -n krgeobuk-dev
# NAME                    READY   STATUS    RESTARTS
# portal-server-xxx       0/1     Pending   0
```

**원인 및 해결**:
- [ ] 리소스 부족: `kubectl describe pod portal-server-xxx -n krgeobuk-dev`에서 Events 확인
- [ ] PVC 문제: Persistent Volume 확인
- [ ] Node Affinity 문제: 노드 라벨 확인

### 문제 2: Pod가 CrashLoopBackOff

**증상**:
```bash
kubectl get pods -n krgeobuk-dev
# NAME                    READY   STATUS             RESTARTS
# mypick-server-xxx      0/1     CrashLoopBackOff   5
```

**원인 및 해결**:
- [ ] 로그 확인: `kubectl logs mypick-server-xxx -n krgeobuk-dev`
- [ ] Secret 누락: Secret이 제대로 생성되었는지 확인
- [ ] 데이터베이스 연결 실패: MySQL/Redis 상태 확인
- [ ] 환경 변수 오류: ConfigMap 확인

### 문제 3: Service Endpoint가 없음

**증상**:
```bash
kubectl get endpoints portal-server -n krgeobuk-dev
# NAME            ENDPOINTS   AGE
# portal-server   <none>      5m
```

**원인 및 해결**:
- [ ] Pod Selector 불일치: Service의 selector와 Pod의 label 확인
- [ ] Readiness Probe 실패: Pod 로그에서 health check 확인
- [ ] Pod가 Running이 아님: Pod 상태 확인

### 문제 4: 외부 API 연동 실패

**증상**:
- YouTube/Twitter API 호출 실패

**원인 및 해결**:
- [ ] API 키 확인: Secret에 올바른 키가 설정되었는지 확인
- [ ] 쿼터 초과: YouTube/Twitter 개발자 콘솔에서 쿼터 확인
- [ ] 네트워크 문제: Pod에서 외부 인터넷 접근 가능한지 확인
  ```bash
  kubectl exec -it mypick-server-xxx -n krgeobuk-dev -- sh
  curl https://www.googleapis.com/youtube/v3/search
  ```

### 문제 5: JWT 인증 실패

**증상**:
- 서비스 간 JWT 인증 실패

**원인 및 해결**:
- [ ] JWT 공개키 불일치: auth-server의 키와 다른 서비스의 키가 동일한지 확인
- [ ] 키 파일 경로 오류: `/etc/jwt-keys/` 확인
- [ ] 키 파일 권한 문제: 파일 권한이 400인지 확인

---

## 🎯 완료 체크리스트

Phase 2 배포가 완전히 완료되었는지 최종 확인:

### Dev 환경
- [ ] 모든 Pod가 Running 상태
- [ ] 모든 Service가 정상 작동
- [ ] Health Check 모두 통과
- [ ] 데이터베이스 연결 정상
- [ ] 서비스 간 통신 정상
- [ ] 로그에 에러 없음

### Prod 환경
- [ ] 모든 Pod가 Running 상태 (각 서비스당 2개)
- [ ] Pod Anti-Affinity 정상 작동 (노드 분산)
- [ ] 모든 Service가 정상 작동
- [ ] Health Check 모두 통과
- [ ] 데이터베이스 연결 정상
- [ ] 서비스 간 통신 정상
- [ ] 로그에 에러 없음
- [ ] 리소스 사용량 정상 범위

### 보안
- [ ] Secret 파일이 Git에 커밋되지 않음
- [ ] JWT 공개키만 공유되고 Private Key는 auth-server만 보유
- [ ] 외부 API 키에 도메인/IP 제한 설정
- [ ] HTTPS 준비 완료 (Ingress 설정 시)

### 문서화
- [ ] 배포 일시 및 버전 기록
- [ ] Secret 관리 절차 문서화
- [ ] 트러블슈팅 가이드 작성
- [ ] 운영 매뉴얼 업데이트

---

## 📚 부록

### YouTube API 키 발급

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 프로젝트 생성 또는 선택
3. "API 및 서비스" → "라이브러리"
4. "YouTube Data API v3" 검색 및 활성화
5. "사용자 인증 정보" → "사용자 인증 정보 만들기" → "API 키"
6. API 키 제한 설정:
   - **애플리케이션 제한사항**: HTTP 리퍼러 또는 IP 주소
   - **API 제한사항**: YouTube Data API v3만 선택
7. 키 복사 후 Secret에 추가

### Twitter API 키 발급

1. [Twitter Developer Portal](https://developer.twitter.com/) 접속
2. 앱 생성 또는 선택
3. "Keys and tokens" 탭
4. "Bearer Token" 생성
5. 토큰 복사 후 Secret에 추가

**주의사항**:
- Free tier는 월 500,000 트윗 제한
- API v2 사용 (v1.1은 deprecated)

### JWT 키 생성 (auth-server)

```bash
# auth-server 리포지토리에서
cd scripts
./generate-jwt-keys.sh

# 생성된 키 확인
ls -la ../keys/
# access-private.key
# access-public.key
# refresh-private.key
# refresh-public.key

# 공개키만 다른 서비스에 복사
cat ../keys/access-public.key
cat ../keys/refresh-public.key
```

---

**작성자**: Claude Code
**마지막 업데이트**: 2024-12-22
**버전**: Phase 2 Complete
