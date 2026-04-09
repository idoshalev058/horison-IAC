resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.12.0"

# הנה החלק שביקשת:
  depends_on = [
    kubectl_manifest.spot_node_pool
  ]
  # המנגנון שגורם לריסטרט אוטומטי בכל שינוי בערכים
  values = [
    <<-EOT
    controller:
      podAnnotations:
        # פונקציית ה-sha256 מחשבת קוד ייחודי לתוכן ה-values
        # בכל פעם שתשנה פסיק בטקסט למטה, ה-Hash ישתנה והפודים יתרסטו
        config-checksum: ${sha256(<<-INNER_EOT
          service:
            type: ClusterIP
          config:
            use-forwarded-headers: "true"
            compute-full-forward-for: "true"
          admissionWebhooks:
            enabled: false
        INNER_EOT
        )}
      
      # כאן נכנסות ההגדרות האמיתיות (חייבות להיות זהות למה שבתוך ה-Hash)
      service:
        type: ClusterIP
      config:
        use-forwarded-headers: "true"
        compute-full-forward-for: "true"
      admissionWebhooks:
        enabled: false
    EOT
  ]
}
