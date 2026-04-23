resource "kubernetes_namespace" "argocd_ns" {
  metadata {
    name = "argocd"
  }
}

# 1. יצירת מפתח פרטי (Private Key)
resource "tls_private_key" "argocd_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. יצירת תעודה חתומה עצמית (Self-Signed Certificate)
resource "tls_self_signed_cert" "argocd_cert" {
  private_key_pem = tls_private_key.argocd_key.private_key_pem

  subject {
    common_name  = "argo.idos-labs.com"
    organization = "Idos Labs"
  }

  validity_period_hours = 17520 # שנתיים

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 3. יצירת ה-Secret בתוך Kubernetes
resource "kubernetes_secret_v1" "argocd_server_tls" {
  metadata {
    name      = "argocd-server-tls"
    namespace = "argocd"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.argocd_cert.cert_pem
    "tls.key" = tls_private_key.argocd_key.private_key_pem
  }
}
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.0" # גרסה יציבה ועדכנית

  # מבטיח ש-Argo יותקן רק אחרי שהאינגרס קונטרולר למעלה
  depends_on = [helm_release.nginx_ingress, kubernetes_secret_v1.argocd_server_tls]

  values = [
    <<-EOT
    global:
      domain: argo.idos-labs.com

    server:
      ingress:
        enabled: true
        ingressClassName: nginx
        hostname: argo.idos-labs.com
        servicePort: 443
        annotations:
          # אנומציות חיוניות כדי ש-NGINX ידע לדבר עם ה-Internal HTTPS של Argo
          nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
          nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"
          nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
          nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
        
        # אנחנו משתמשים ב-TLS של Cloudflare (Edge), אז פנימית נעבוד ב-HTTP/HTTPS רגיל
        tls: true

    EOT
  ]
}