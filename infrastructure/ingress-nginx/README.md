# NGINX Ingress Controller

Kubernetes 클러스터에 외부 트래픽을 라우팅하기 위한 NGINX Ingress Controller 설치 가이드입니다.

---

## 📋 개요

NGINX Ingress Controller는 Kubernetes 서비스를 외부에 노출하고, HTTP/HTTPS 트래픽을 라우팅합니다.

**주요 기능**:
- 도메인 기반 라우팅 (Virtual Host)
- Path 기반 라우팅
- TLS/SSL 종료
- Load Balancing
- WebSocket 지원
- Rate Limiting
- Authentication

---

## 🚀 설치 방법

### 방법 1: 공식 매니페스트 사용 (권장)

베어메탈 환경용 공식 매니페스트를 사용합니다.

```bash
# 최신 버전 확인
# https://github.com/kubernetes/ingress-nginx/releases

# NGINX Ingress Controller 설치 (v1.11.1)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/baremetal/deploy.yaml

# 설치 확인
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 방법 2: Helm Chart 사용

```bash
# Helm 리포지토리 추가
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 설치
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443

# 확인
helm list -n ingress-nginx
```

---

## 🔧 베어메탈 환경 설정

베어메탈 환경에서는 NodePort 또는 HostNetwork를 사용합니다.

### NodePort 설정 (기본)

공식 매니페스트는 NodePort를 사용합니다:
- HTTP: 30080
- HTTPS: 30443

```bash
# Service 확인
kubectl get svc ingress-nginx-controller -n ingress-nginx

# 예시 출력:
# NAME                       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)
# ingress-nginx-controller   NodePort   10.96.xxx.xxx   <none>        80:30080/TCP,443:30443/TCP
```

### HostNetwork 설정 (선택)

호스트 네트워크를 직접 사용하려면:

```bash
# Deployment 수정
kubectl edit deployment ingress-nginx-controller -n ingress-nginx

# spec.template.spec에 추가:
hostNetwork: true
dnsPolicy: ClusterFirstWithHostNet
```

---

## ✅ 설치 확인

### 1. Pod 상태 확인

```bash
kubectl get pods -n ingress-nginx

# 예상 출력:
# NAME                                        READY   STATUS
# ingress-nginx-controller-xxx                1/1     Running
# ingress-nginx-admission-create-xxx          0/1     Completed
# ingress-nginx-admission-patch-xxx           0/1     Completed
```

### 2. Service 확인

```bash
kubectl get svc -n ingress-nginx

# NodePort 확인
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}'
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}'
```

### 3. Ingress Class 확인

```bash
kubectl get ingressclass

# 예상 출력:
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       1m
```

### 4. 테스트 Ingress 생성

```bash
# 테스트용 Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes
            port:
              number: 443
EOF

# 확인
kubectl get ingress test-ingress
kubectl describe ingress test-ingress

# 테스트 (miniPC IP 또는 노드 IP 사용)
curl -H "Host: test.local" http://<NODE_IP>:30080

# 테스트 완료 후 삭제
kubectl delete ingress test-ingress
```

---

## 🔐 TLS/SSL 설정

TLS/SSL 인증서는 cert-manager를 통해 자동으로 관리합니다.

자세한 내용은 [cert-manager 가이드](../cert-manager/README.md)를 참조하세요.

---

## 📝 Ingress 리소스 생성

각 서비스별 Ingress 리소스는 `applications/*/ingress.yaml`에 정의되어 있습니다.

**예시**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auth-server-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
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

---

## 🛠️ 주요 Annotations

### 기본 설정

```yaml
annotations:
  # Rewrite target
  nginx.ingress.kubernetes.io/rewrite-target: /

  # SSL 리다이렉트
  nginx.ingress.kubernetes.io/ssl-redirect: "true"

  # CORS 설정
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"

  # Proxy 타임아웃
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "60"

  # 요청 크기 제한
  nginx.ingress.kubernetes.io/proxy-body-size: "10m"
```

### 고급 설정

```yaml
annotations:
  # Rate Limiting
  nginx.ingress.kubernetes.io/limit-rps: "10"

  # Whitelist (IP 제한)
  nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,192.168.0.0/16"

  # Basic Auth
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
  nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"

  # WebSocket 지원
  nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
  nginx.ingress.kubernetes.io/websocket-services: "my-service"
```

---

## 🔍 트러블슈팅

### 1. Ingress Controller Pod가 시작되지 않음

```bash
# Pod 로그 확인
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Pod 상세 정보
kubectl describe pod -n ingress-nginx <pod-name>
```

### 2. Ingress가 동작하지 않음

```bash
# Ingress 확인
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>

# Ingress Controller 로그
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=100 -f

# Endpoints 확인
kubectl get endpoints <service-name> -n <namespace>
```

### 3. 503 Service Temporarily Unavailable

원인:
- Backend Service가 존재하지 않음
- Backend Pod가 Ready 상태가 아님
- Service Selector가 Pod Label과 일치하지 않음

해결:
```bash
# Service 확인
kubectl get svc <service-name> -n <namespace>

# Endpoints 확인
kubectl get endpoints <service-name> -n <namespace>

# Pod 상태 확인
kubectl get pods -n <namespace> -l app=<app-name>
```

### 4. 404 Not Found

원인:
- Ingress path가 올바르지 않음
- rewrite-target 설정 오류

해결:
```bash
# Ingress 확인
kubectl describe ingress <ingress-name> -n <namespace>

# Ingress Controller 설정 확인
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -A 20 <host-name>
```

---

## 📊 모니터링

### Metrics

```bash
# Ingress Controller Metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/ingress-nginx/pods

# Prometheus Metrics (9090 포트)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller-metrics 9090:10254
```

### Logs

```bash
# 실시간 로그
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f

# 특정 Host 필터링
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep "auth.krgeobuk.com"

# 에러 로그만
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep -i error
```

---

## 🔄 업그레이드

```bash
# 현재 버전 확인
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- /nginx-ingress-controller --version

# 새 버전 적용
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/baremetal/deploy.yaml

# 롤아웃 확인
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
```

---

## 🗑️ 제거

```bash
# NGINX Ingress Controller 제거
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/baremetal/deploy.yaml

# 또는 Helm으로 설치한 경우
helm uninstall ingress-nginx -n ingress-nginx

# Namespace 제거
kubectl delete namespace ingress-nginx
```

---

## 📚 참고 자료

- [NGINX Ingress Controller 공식 문서](https://kubernetes.github.io/ingress-nginx/)
- [Ingress Annotations 전체 목록](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [TLS/HTTPS 설정](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
- [베어메탈 배포 가이드](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)

---

**작성자**: Claude Code
**버전**: 1.0.0
**마지막 업데이트**: 2024-12-23
