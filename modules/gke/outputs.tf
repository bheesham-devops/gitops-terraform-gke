# =============================================================================
# modules/gke/outputs.tf
# Exposes cluster identifiers consumed by the root module and K8s providers.
# =============================================================================

output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "IP address of the GKE cluster API server endpoint."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded public certificate of the cluster's CA."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_pool_name" {
  description = "Name of the primary node pool."
  value       = google_container_node_pool.primary_nodes.name
}

output "node_service_account_email" {
  description = "Email of the GKE node pool service account."
  value       = google_service_account.gke_nodes.email
}
