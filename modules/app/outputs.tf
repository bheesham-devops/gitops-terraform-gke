# =============================================================================
# modules/app/outputs.tf
# =============================================================================

output "app_namespace" {
  description = "Kubernetes namespace created for the user's application."
  value       = kubernetes_namespace.cu_app.metadata[0].name
}
