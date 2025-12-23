# Ingress 설정 가이드

Kubernetes 클러스터에 외부 트래픽을 라우팅하기 위한 Ingress 설정 전체 가이드입니다.

---

## 📋 목차

1. [개요](#개요)
2. [아키텍처](#아키텍처)
3. [설치 순서](#설치-순서)
4. [도메인 설정](#도메인-설정)
5. [테스트 방법](#테스트-방법)
6. [트러블슈팅](#트러블슈팅)

---

## 개요

### Ingress란?

Ingress는 Kubernetes 클러스터 외부에서 내부 서비스로의 HTTP/HTTPS 트래픽을 라우팅합니다.

**주요 기능**:
- **Path 기반 라우팅**: `/auth` → auth-server, `/mypick` → my-pick-client
- **Host 기반 라우팅**: `auth.krgeobuk.com` → auth-server
- **TLS/SSL 종료**: HTTPS 트래픽 처리 및 인증서 관리
- **Load Balancing**: 여러 Pod 간 트래픽 분산

### 구성 요소

1. **NGINX Ingress Controller**: Ingress 규칙을 실제로 처리하는 컨트롤러
2. **cert-manager**: TLS/SSL 인증서 자동 발급 및 갱신
3. **Ingress 리소스**: 라우팅 규칙 정의

---

## 아키텍처

### 트래픽 흐름

```
외부 사용자
    ↓
[NodePort 30080/30443]
    ↓
NGINX Ingress Controller
    ↓
┌─────────────────────────────────────┐
│  Path 기반 라우팅                      │
├─────────────────────────────────────┤
│  /auth/*      → auth-server:8000    │
│  /authz/*     → authz-server:8100   │
│  /portal-api/* → portal-server:8200 │
│  /mypick-api/* → my-pick-server:8300│
│  /mypick/*    → my-pick-client:3300 │
│  /*           → portal-client:3000  │
└─────────────────────────────────────┘
    ↓
Kubernetes Services
    ↓
Backend Pods
```

### URL 구조

#### Development (dev.krgeobuk.local)

```
http://dev.krgeobuk.local/                     → portal-client (메인 포털)
http://dev.krgeobuk.local/auth/login           → auth-server
http://dev.krgeobuk.local/authz/permissions    → authz-server
http://dev.krgeobuk.local/portal-api/users     → portal-server
http://dev.krgeobuk.local/mypick-api/feeds     → my-pick-server
http://dev.krgeobuk.local/mypick/              → my-pick-client
http://dev.krgeobuk.local/portal-admin/        → portal-admin-client
http://dev.krgeobuk.local/mypick-admin/        → my-pick-admin-client
```

#### Production (krgeobuk.com)

```
https://krgeobuk.com/                          → portal-client
https://krgeobuk.com/auth/login                → auth-server
https://krgeobuk.com/authz/permissions         → authz-server
https://krgeobuk.com/portal-api/users          → portal-server
https://krgeobuk.com/mypick-api/feeds          → my-pick-server
https://krgeobuk.com/mypick/                   → my-pick-client
https://krgeobuk.com/portal-admin/             → portal-admin-client
https://krgeobuk.com/mypick-admin/             → my-pick-admin-client
```

---

## 설치 순서

### 1. NGINX Ingress Controller 설치

```bash
# 공식 매니페스트 설치 (베어메탈 환경)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/baremetal/deploy.yaml

# 설치 확인
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# NodePort 확인
kubectl get svc ingress-nginx-controller -n ingress-nginx
# HTTP: 30080, HTTPS: 30443
```

**상세 가이드**: [infrastructure/ingress-nginx/README.md](../../infrastructure/ingress-nginx/README.md)

### 2. cert-manager 설치

```bash
# cert-manager 설치
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 설치 확인
kubectl get pods -n cert-manager

# ClusterIssuer 생성
kubectl apply -f infrastructure/cert-manager/cluster-issuer-staging.yaml
kubectl apply -f infrastructure/cert-manager/cluster-issuer-prod.yaml

# ClusterIssuer 확인
kubectl get clusterissuer
```

**상세 가이드**: [infrastructure/cert-manager/README.md](../../infrastructure/cert-manager/README.md)

### 3. Ingress 리소스 배포

#### Development 환경

```bash
# Dev Ingress 배포
kubectl apply -f environments/dev/ingress.yaml

# 확인
kubectl get ingress -n krgeobuk-dev
kubectl describe ingress krgeobuk-dev-ingress -n krgeobuk-dev
```

#### Production 환경

```bash
# Prod Ingress 배포
kubectl apply -f environments/prod/ingress.yaml

# 확인
kubectl get ingress -n krgeobuk-prod
kubectl describe ingress krgeobuk-prod-ingress -n krgeobuk-prod

# TLS 인증서 확인
kubectl get certificate -n krgeobuk-prod
kubectl describe certificate krgeobuk-prod-tls -n krgeobuk-prod
```

---

## 도메인 설정

### 로컬 테스트 (hosts 파일)

개발 환경에서 도메인 없이 테스트하려면 hosts 파일을 수정합니다.

#### Windows

```
# C:\Windows\System32\drivers\etc\hosts
192.168.0.100  dev.krgeobuk.local
```

#### Linux/macOS

```bash
# /etc/hosts
192.168.0.100  dev.krgeobuk.local

# 권한 필요
sudo nano /etc/hosts
```

### DNS 설정 (실제 도메인)

도메인 제공자(예: Cloudflare, Route53)에서 A 레코드 추가:

```
A  @               192.168.0.100  # krgeobuk.com
A  www             192.168.0.100  # www.krgeobuk.com
A  *.krgeobuk.com  192.168.0.100  # 서브도메인 와일드카드
```

**주의**:
- `192.168.0.100`은 miniPC의 실제 IP로 변경
- Let's Encrypt는 80 포트로 도메인 소유권을 확인하므로, 방화벽에서 80/443 포트 허용 필요

---

## 테스트 방법

### 1. 기본 연결 테스트

```bash
# NodePort 직접 접근 (Ingress Controller 테스트)
curl http://<NODE_IP>:30080

# 도메인으로 접근 (hosts 파일 설정 후)
curl http://dev.krgeobuk.local/

# 특정 서비스 테스트
curl http://dev.krgeobuk.local/auth/health
curl http://dev.krgeobuk.local/authz/health
curl http://dev.krgeobuk.local/portal-api/health
curl http://dev.krgeobuk.local/mypick-api/health
```

### 2. Path 라우팅 테스트

```bash
# auth-server 테스트
curl -H "Host: dev.krgeobuk.local" http://<NODE_IP>:30080/auth/health

# my-pick-server 테스트
curl -H "Host: dev.krgeobuk.local" http://<NODE_IP>:30080/mypick-api/health

# 프론트엔드 테스트
curl -H "Host: dev.krgeobuk.local" http://<NODE_IP>:30080/mypick/
```

### 3. TLS/SSL 테스트 (Prod)

```bash
# HTTPS 접근
curl https://krgeobuk.com/

# 인증서 정보 확인
openssl s_client -connect krgeobuk.com:443 -servername krgeobuk.com

# SSL 자동 리다이렉트 테스트
curl -L http://krgeobuk.com/  # HTTP → HTTPS 리다이렉트
```

### 4. 브라우저 테스트

```
# Development
http://dev.krgeobuk.local/
http://dev.krgeobuk.local/mypick/
http://dev.krgeobuk.local/portal-admin/

# Production
https://krgeobuk.com/
https://krgeobuk.com/mypick/
https://krgeobuk.com/portal-admin/
```

---

## 트러블슈팅

### 1. 503 Service Unavailable

**증상**:
```
<html>
<head><title>503 Service Temporarily Unavailable</title></head>
</html>
```

**원인**:
- Backend Service가 존재하지 않음
- Backend Pod가 Ready 상태가 아님

**해결**:
```bash
# Service 확인
kubectl get svc -n krgeobuk-dev

# Pod 상태 확인
kubectl get pods -n krgeobuk-dev

# Endpoints 확인
kubectl get endpoints -n krgeobuk-dev

# Ingress Controller 로그
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=100
```

### 2. 404 Not Found

**증상**:
```
<html>
<head><title>404 Not Found</title></head>
</html>
```

**원인**:
- Path 라우팅 규칙이 잘못됨
- rewrite-target 설정 오류

**해결**:
```bash
# Ingress 설정 확인
kubectl describe ingress krgeobuk-dev-ingress -n krgeobuk-dev

# NGINX 설정 확인
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -A 10 "dev.krgeobuk.local"
```

### 3. TLS 인증서 발급 실패

**증상**:
```bash
kubectl get certificate -n krgeobuk-prod
# NAME                READY   SECRET              AGE
# krgeobuk-prod-tls   False   krgeobuk-prod-tls   5m
```

**원인**:
- 도메인이 서버 IP를 가리키지 않음
- 80 포트가 차단됨 (Let's Encrypt Challenge 실패)

**해결**:
```bash
# Certificate 상태 확인
kubectl describe certificate krgeobuk-prod-tls -n krgeobuk-prod

# Challenge 확인
kubectl get challenge -n krgeobuk-prod
kubectl describe challenge <challenge-name> -n krgeobuk-prod

# DNS 확인
nslookup krgeobuk.com

# 80 포트 접근 테스트
curl -v http://krgeobuk.com/.well-known/acme-challenge/test
```

### 4. CORS 에러

**증상**:
```
Access to XMLHttpRequest has been blocked by CORS policy
```

**해결**:
```yaml
# Ingress annotations에 CORS 설정 추가
annotations:
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"  # 또는 특정 도메인
  nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
  nginx.ingress.kubernetes.io/cors-allow-headers: "Authorization, Content-Type"
```

### 5. Ingress가 External IP를 받지 못함

**증상**:
```bash
kubectl get ingress -n krgeobuk-dev
# ADDRESS 필드가 비어있음
```

**원인**:
- Ingress Controller가 아직 준비되지 않음
- LoadBalancer 타입이 지원되지 않음 (베어메탈)

**해결**:
```bash
# Ingress Controller 확인
kubectl get svc ingress-nginx-controller -n ingress-nginx

# 베어메탈 환경에서는 NodePort 사용
# External IP 대신 <NODE_IP>:30080/30443으로 접근
```

---

## 고급 설정

### 서브도메인 기반 라우팅

각 서비스를 서브도메인으로 분리:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auth-server-ingress
  namespace: krgeobuk-prod
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - auth.krgeobuk.com
    secretName: auth-server-tls
  rules:
  - host: auth.krgeobuk.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: auth-server
            port:
              number: 8000
```

### Rate Limiting

특정 경로에 Rate Limit 적용:

```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "10"
  nginx.ingress.kubernetes.io/limit-whitelist: "192.168.0.0/16"
```

### Basic Auth

관리자 페이지에 Basic Auth 적용:

```bash
# htpasswd Secret 생성
htpasswd -c auth admin
kubectl create secret generic basic-auth --from-file=auth -n krgeobuk-prod

# Ingress annotations 추가
annotations:
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
  nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
```

---

## 모니터링

### Ingress Controller 메트릭

```bash
# Prometheus 메트릭
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller-metrics 10254:10254
curl http://localhost:10254/metrics
```

### 로그 확인

```bash
# 실시간 로그
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f

# 특정 Host 필터링
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep "krgeobuk.com"

# 에러만 확인
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep -i error
```

---

## 참고 자료

- [NGINX Ingress Controller 상세 가이드](../../infrastructure/ingress-nginx/README.md)
- [cert-manager 상세 가이드](../../infrastructure/cert-manager/README.md)
- [NGINX Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [Let's Encrypt 문서](https://letsencrypt.org/docs/)

---

**작성자**: Claude Code
**버전**: 1.0.0
**마지막 업데이트**: 2024-12-23
