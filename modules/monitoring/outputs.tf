# =============================================================================
# modules/monitoring/outputs.tf
# =============================================================================

output "monitoring_namespace" {
  description = "Kubernetes namespace where monitoring stack is installed."
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_url" {
  description = "Public URL for the Grafana dashboard."
  value       = "https://grafana.${var.domain}"
}

output "prometheus_url" {
  description = "Public URL for the Prometheus UI."
  value       = "https://prometheus.${var.domain}"
}

output "grafana_service_name" {
  description = "Kubernetes service name for Grafana (set by fullnameOverride)."
  value       = "monitoring-grafana"
}

output "prometheus_service_name" {
  description = "Kubernetes service name for Prometheus (set by fullnameOverride)."
  value       = "monitoring-prometheus"
}
