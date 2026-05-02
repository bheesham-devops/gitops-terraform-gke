# =============================================================================
# modules/app/main.tf
#
# Creates the "cu-app" namespace for the user's application.
# The user deploys their workloads into this namespace (via ArgoCD or kubectl).
#
# To expose the app via the shared Gateway, add an HTTPRoute like this:
# -----------------------------------------------------------------------
# apiVersion: gateway.networking.k8s.io/v1
# kind: HTTPRoute
# metadata:
#   name: my-app-route
#   namespace: cu-app
# spec:
#   parentRefs:
#   - group: gateway.networking.k8s.io
#     kind: Gateway
#     name: external-https-gateway
#     namespace: networking
#     sectionName: https
#   hostnames:
#   - "app.nayaratech.online"
#   rules:
#   - backendRefs:
#     - name: my-app-service
#       port: 80
# -----------------------------------------------------------------------
# =============================================================================

resource "kubernetes_namespace" "cu_app" {
  metadata {
    name = var.app_namespace

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}
