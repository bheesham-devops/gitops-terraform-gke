# =============================================================================
# outputs.tf  —  Root Module Outputs
# All key infrastructure values printed after `terraform apply`.
# =============================================================================

# ---------------------------------------------------------------------------
# GKE Cluster
# ---------------------------------------------------------------------------
output "gke_cluster_name" {
  description = "Name of the GKE cluster."
  value       = module.gke.cluster_name
}

output "gke_cluster_region" {
  description = "GCP region of the GKE cluster."
  value       = var.region
}

output "kubeconfig_command" {
  description = "Run this to configure kubectl."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
output "vpc_network_name" {
  description = "Name of the custom VPC network."
  value       = module.network.network_name
}

output "vpc_subnet_name" {
  description = "Name of the primary VPC subnet."
  value       = module.network.subnet_name
}

# ---------------------------------------------------------------------------
# Shared Load Balancer (Gateway)
# ---------------------------------------------------------------------------
output "load_balancer_ip" {
  description = "Global static IP for the single shared HTTPS Load Balancer. All DNS A records point here."
  value       = module.ingress.static_ip_address
}

# ---------------------------------------------------------------------------
# SSL Certificate DNS Validation (Namecheap)
# ---------------------------------------------------------------------------
output "dns_cname_record_name" {
  description = "Add this CNAME record NAME in Namecheap to activate the SSL certificate."
  value       = module.ingress.dns_cname_record_name
}

output "dns_cname_record_value" {
  description = "Add this CNAME record VALUE in Namecheap to activate the SSL certificate."
  value       = module.ingress.dns_cname_record_value
}

output "dns_setup_instructions" {
  description = "Full DNS setup instructions for Namecheap."
  value       = module.ingress.dns_cname_instructions
}

# ---------------------------------------------------------------------------
# Application URLs
# ---------------------------------------------------------------------------
output "argocd_url" {
  description = "HTTPS URL for the ArgoCD UI."
  value       = module.argocd.argocd_url
}

output "grafana_url" {
  description = "HTTPS URL for the Grafana dashboard."
  value       = module.monitoring.grafana_url
}

output "prometheus_url" {
  description = "HTTPS URL for the Prometheus UI."
  value       = module.monitoring.prometheus_url
}

output "app_url" {
  description = "HTTPS URL for the user's application (once deployed and HTTPRoute added)."
  value       = "https://app.${var.domain}"
}

# ---------------------------------------------------------------------------
# Namespaces
# ---------------------------------------------------------------------------
output "namespaces" {
  description = "Summary of all Kubernetes namespaces created."
  value = {
    argocd     = module.argocd.argocd_namespace
    monitoring = module.monitoring.monitoring_namespace
    app        = module.app.app_namespace
    gateway    = var.gateway_namespace
  }
}

# ---------------------------------------------------------------------------
# ArgoCD Credentials
# ---------------------------------------------------------------------------
output "argocd_admin_password_command" {
  description = "Run this command to get the ArgoCD initial admin password."
  value       = module.argocd.argocd_admin_password_command
}

# ---------------------------------------------------------------------------
# Artifact Registry (Docker image repository)
# ---------------------------------------------------------------------------
output "image_registry" {
  description = "Artifact Registry URL. Set this as GCR_REGISTRY GitHub Actions secret."
  value       = module.gcr.image_registry
}

output "cicd_service_account_email" {
  description = "Email of the CI/CD Service Account that pushes images."
  value       = module.gcr.cicd_service_account_email
}

output "cicd_sa_key_base64" {
  description = "Base64-encoded SA key. Run: terraform output -raw cicd_sa_key_base64 → set as GCR_SA_KEY GitHub secret."
  value       = module.gcr.cicd_sa_key_base64
  sensitive   = true
}
