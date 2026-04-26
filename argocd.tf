resource "kubernetes_namespace" "argocd_ns" {
  metadata {
    name = "argocd"
  }
    depends_on = [
    kubectl_manifest.spot_node_pool
  ]
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

# 3. יצירת ה-Secret בתוך Kubernetes עבור ה-TLS
resource "kubernetes_secret_v1" "argocd_server_tls" {
  depends_on = [kubernetes_namespace.argocd_ns]
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
  # create_namespace = true # Removed since we manage the NS explicitly
  version          = "7.7.0"

  # Added dependency on our new ConfigMap (and TLS secret)
  depends_on = [
    helm_release.nginx_ingress, 
    kubernetes_secret_v1.argocd_server_tls, 
  ]

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
          nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
          nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"
          nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
          nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
        
        tls: true
    EOT
  ]
}

# 4. יצירת ה-Secret עבור ה-Repository בתוך ArgoCD
resource "kubernetes_secret_v1" "argocd_repo_k3sinfra" {
  # This ensures the secret is created ONLY AFTER the Helm release finishes
  depends_on = [helm_release.argocd]

  metadata {
    name      = "my-https-repo-credential"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  # In Terraform, 'data' acts like 'stringData' in YAML. 
  # Terraform automatically handles the base64 encoding behind the scenes.
  data = {
    url      = "https://github.com/idoshalev058/k3sinfra.git"
    username = ""
    password = ""
    project  = "default"
    insecure = "true"
  }
}