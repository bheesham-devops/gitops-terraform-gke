# =============================================================================
# modules/network/outputs.tf
# Exposes identifiers consumed by the GKE module.
# =============================================================================

output "network_name" {
  description = "Self-link name of the custom VPC network."
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "Full self-link URI of the custom VPC network."
  value       = google_compute_network.vpc.self_link
}

output "subnet_name" {
  description = "Name of the primary VPC subnet."
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_self_link" {
  description = "Full self-link URI of the primary VPC subnet."
  value       = google_compute_subnetwork.subnet.self_link
}

output "pods_range_name" {
  description = "Name of the secondary IP range allocated to GKE Pods."
  value       = "${var.project_name}-pods"
}

output "services_range_name" {
  description = "Name of the secondary IP range allocated to GKE Services."
  value       = "${var.project_name}-services"
}
