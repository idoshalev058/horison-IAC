# יצירת ה-Secret בקוברנטיס
resource "kubernetes_secret_v1" "cloudflare_tunnel_secret" {
  metadata {
    name      = "cloudflare-tunnel-token"
    namespace = "default"
  }

  data = {
    "token" = var.cloudflare_tunnel_token
  }

  type = "Opaque"
}

# יצירת ה-Deployment של הטאנל
resource "kubernetes_deployment_v1" "cloudflare_tunnel" {
  metadata {
    name      = "cloudflare-tunnel"
    namespace = "default"
    labels = {
      app = "cloudflare-tunnel"
    }
  }
# הנה החלק שביקשת:
  depends_on = [
    kubectl_manifest.spot_node_pool
  ]
  spec {
    replicas = 1 # יתירות למקרה ש-Spot node נופל

    selector {
      match_labels = {
        app = "cloudflare-tunnel"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflare-tunnel"
        }
      }

      spec {
        container {
          name  = "tunnel"
          image = "cloudflare/cloudflared:latest"
          args  = ["tunnel", "--no-autoupdate", "run"]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = "cloudflare-tunnel-token"
                key  = "token"
              }
            }
          }
        }
      }
    }
  }
}