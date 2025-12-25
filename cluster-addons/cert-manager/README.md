# cert-manager

Kubernetes에서 TLS/SSL 인증서를 자동으로 발급하고 갱신하는 cert-manager 설치 가이드입니다.

---

## 📋 개요

cert-manager는 Kubernetes에서 TLS/SSL 인증서를 자동으로 관리합니다.

**주요 기능**:
- Let's Encrypt를 통한 무료 SSL 인증서 자동 발급
- 인증서 자동 갱신 (만료 전)
- 여러 CA 지원 (Let's Encrypt, HashiCorp Vault 등)
- HTTP-01, DNS-01 Challenge 지원

---

## 🚀 설치 방법

### 방법 1: kubectl apply 사용 (권장)

```bash
# cert-manager 설치 (v1.13.3)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 설치 확인
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

### 방법 2: Helm Chart 사용

```bash
# Helm 리포지토리 추가
helm repo add jetstack https://charts.jetstack.io
helm repo update

# CRDs 설치
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.crds.yaml

# cert-manager 설치
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.3

# 확인
helm list -n cert-manager
```

---

## ✅ 설치 확인

### 1. Pod 상태 확인

```bash
kubectl get pods -n cert-manager

# 예상 출력:
# NAME                                      READY   STATUS
# cert-manager-xxx                          1/1     Running
# cert-manager-cainjector-xxx               1/1     Running
# cert-manager-webhook-xxx                  1/1     Running
```

### 2. CRD 확인

```bash
kubectl get crd | grep cert-manager

# 예상 출력:
# certificaterequests.cert-manager.io
# certificates.cert-manager.io
# challenges.acme.cert-manager.io
# clusterissuers.cert-manager.io
# issuers.cert-manager.io
# orders.acme.cert-manager.io
```

### 3. 테스트 인증서 발급

```bash
# 테스트용 Self-Signed Issuer 생성
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: default
spec:
  selfSigned: {}
EOF

# 테스트 인증서 생성
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: default
spec:
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
  commonName: test.example.com
  dnsNames:
  - test.example.com
EOF

# 인증서 확인
kubectl get certificate -n default
kubectl describe certificate selfsigned-cert -n default

# Secret 확인
kubectl get secret selfsigned-cert-tls -n default

# 테스트 완료 후 삭제
kubectl delete certificate selfsigned-cert -n default
kubectl delete issuer test-selfsigned -n default
kubectl delete secret selfsigned-cert-tls -n default
```

---

## 🔐 ClusterIssuer 설정

### ClusterIssuer란?

ClusterIssuer는 클러스터 전체에서 사용할 수 있는 인증서 발급자입니다.
Let's Encrypt를 사용하여 무료 SSL 인증서를 자동으로 발급합니다.

### Staging Issuer (개발/테스트용)

```bash
# Staging Issuer 적용
kubectl apply -f cluster-issuer-staging.yaml

# 확인
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-staging
```

**특징**:
- Let's Encrypt Staging 서버 사용
- Rate Limit 없음 (테스트에 적합)
- ⚠️ 브라우저에서 신뢰되지 않는 인증서 (테스트용)

### Production Issuer (프로덕션용)

```bash
# Production Issuer 적용
kubectl apply -f cluster-issuer-prod.yaml

# 확인
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

**특징**:
- Let's Encrypt Production 서버 사용
- Rate Limit 있음 (주당 50개 인증서)
- ✅ 브라우저에서 신뢰되는 인증서

**⚠️ 주의사항**:
- Production Issuer는 신중하게 사용하세요
- 테스트는 Staging Issuer로 먼저 진행
- Rate Limit: https://letsencrypt.org/docs/rate-limits/

---

## 📝 Ingress에서 TLS 사용

### 기본 사용법

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    # cert-manager가 인증서를 자동으로 발급하도록 설정
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
    # 또는 프로덕션
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    - www.example.com
    secretName: example-tls  # 인증서가 저장될 Secret 이름
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

### 인증서 발급 과정

1. Ingress 생성 시 cert-manager가 자동으로 감지
2. Certificate 리소스 자동 생성
3. ACME Challenge 시작 (HTTP-01)
4. Let's Encrypt에서 도메인 소유권 확인
5. 인증서 발급 및 Secret 저장
6. Ingress에서 TLS 적용

### 인증서 상태 확인

```bash
# Certificate 확인
kubectl get certificate -A
kubectl describe certificate <cert-name> -n <namespace>

# CertificateRequest 확인
kubectl get certificaterequest -A

# Challenge 확인 (문제 발생 시)
kubectl get challenge -A
kubectl describe challenge <challenge-name> -n <namespace>

# Order 확인
kubectl get order -A

# Secret 확인 (인증서 저장)
kubectl get secret <secret-name> -n <namespace>
kubectl describe secret <secret-name> -n <namespace>
```

---

## 🛠️ 트러블슈팅

### 1. 인증서 발급 실패

#### Challenge가 Pending 상태

```bash
# Challenge 확인
kubectl get challenge -A
kubectl describe challenge <challenge-name> -n <namespace>

# Ingress Controller 로그
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

**원인**:
- 도메인이 서버 IP를 가리키지 않음
- 방화벽에서 80/443 포트 차단
- Ingress Controller가 동작하지 않음

**해결**:
```bash
# DNS 확인
nslookup example.com

# 80 포트 접근 테스트
curl -v http://example.com/.well-known/acme-challenge/test

# Ingress 확인
kubectl get ingress -A
```

#### Rate Limit 초과

```bash
# Certificate 이벤트 확인
kubectl describe certificate <cert-name> -n <namespace>

# 에러 메시지 예시:
# Error: too many certificates already issued for exact set of domains
```

**해결**:
- Staging Issuer로 테스트
- Rate Limit 해제 대기 (1주일)
- 다른 도메인 사용

### 2. 인증서 갱신 실패

```bash
# Certificate 상태 확인
kubectl get certificate -A
kubectl describe certificate <cert-name> -n <namespace>

# cert-manager 로그
kubectl logs -n cert-manager deployment/cert-manager

# Secret 만료일 확인
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
```

### 3. Self-Signed Certificate 경고

**원인**:
- Staging Issuer 사용 중
- 인증서가 아직 발급되지 않음

**확인**:
```bash
# 인증서 확인
kubectl get certificate -A

# Issuer 확인
kubectl get clusterissuer
```

---

## 📊 모니터링

### Certificate 만료일 확인

```bash
# 모든 Certificate 확인
kubectl get certificate -A

# 특정 Certificate 상세 정보
kubectl describe certificate <cert-name> -n <namespace>

# Secret에서 직접 확인
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

### 자동 갱신 확인

cert-manager는 인증서 만료 30일 전에 자동으로 갱신을 시도합니다.

```bash
# cert-manager 로그
kubectl logs -n cert-manager deployment/cert-manager -f

# CertificateRequest 히스토리
kubectl get certificaterequest -A
```

---

## 🔄 업그레이드

```bash
# 현재 버전 확인
kubectl get deployment cert-manager -n cert-manager -o jsonpath='{.spec.template.spec.containers[0].image}'

# 새 버전 적용
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 롤아웃 확인
kubectl rollout status deployment/cert-manager -n cert-manager
```

---

## 🗑️ 제거

```bash
# cert-manager 제거
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 또는 Helm으로 설치한 경우
helm uninstall cert-manager -n cert-manager

# CRDs 제거 (선택)
kubectl delete crd certificaterequests.cert-manager.io
kubectl delete crd certificates.cert-manager.io
kubectl delete crd challenges.acme.cert-manager.io
kubectl delete crd clusterissuers.cert-manager.io
kubectl delete crd issuers.cert-manager.io
kubectl delete crd orders.acme.cert-manager.io

# Namespace 제거
kubectl delete namespace cert-manager
```

---

## 📋 이메일 주소 변경

ClusterIssuer의 이메일 주소를 실제 관리자 이메일로 변경하세요:

```bash
# cluster-issuer-staging.yaml
email: admin@krgeobuk.com  # <- 변경

# cluster-issuer-prod.yaml
email: admin@krgeobuk.com  # <- 변경
```

Let's Encrypt는 인증서 만료 알림과 중요한 공지를 이 이메일로 발송합니다.

---

## 📚 참고 자료

- [cert-manager 공식 문서](https://cert-manager.io/docs/)
- [Let's Encrypt 문서](https://letsencrypt.org/docs/)
- [ACME Challenge Types](https://cert-manager.io/docs/configuration/acme/)
- [Rate Limits](https://letsencrypt.org/docs/rate-limits/)

---

**작성자**: Claude Code
**버전**: 1.0.0
**마지막 업데이트**: 2024-12-23
