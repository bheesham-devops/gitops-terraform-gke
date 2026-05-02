# =============================================================================
# modules/argocd/outputs.tf
# =============================================================================

output "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD is installed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_url" {
  description = "Public HTTPS URL to access the ArgoCD UI."
  value       = "https://argocd.${var.domain}"
}

output "argocd_admin_password_command" {
  description = "Command to retrieve the initial ArgoCD admin password."
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}
