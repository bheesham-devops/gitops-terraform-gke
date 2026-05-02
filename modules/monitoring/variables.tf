# =============================================================================
# modules/monitoring/variables.tf
# =============================================================================

variable "monitoring_namespace" {
  description = "Kubernetes namespace for Prometheus and Grafana."
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Helm chart version for kube-prometheus-stack."
  type        = string
  default     = "58.6.0"
}

variable "environment" {
  description = "Environment label (dev, staging, prod)."
  type        = string
}

variable "domain" {
  description = "Root domain. Grafana is exposed at grafana.<domain>, Prometheus at prometheus.<domain>."
  type        = string
  default     = "nayaratech.online"
}

variable "gateway_name" {
  description = "Name of the shared GKE Gateway to attach HTTPRoutes to."
  type        = string
  default     = "external-https-gateway"
}

variable "gateway_namespace" {
  description = "Namespace of the shared GKE Gateway."
  type        = string
  default     = "networking"
}

variable "grafana_admin_password" {
  description = "Grafana admin user password. Do not hardcode — pass via tfvars or env."
  type        = string
  sensitive   = true
}
