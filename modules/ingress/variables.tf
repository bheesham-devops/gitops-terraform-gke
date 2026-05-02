# =============================================================================
# modules/ingress/variables.tf
# =============================================================================

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "project_name" {
  description = "Short project name used as a prefix in resource names."
  type        = string
}

variable "environment" {
  description = "Environment label (dev, staging, prod)."
  type        = string
}

variable "domain" {
  description = "Root domain name. Certificate covers this domain and all subdomains (wildcard)."
  type        = string
  default     = "nayaratech.online"
}

variable "gateway_name" {
  description = "Name of the GKE Gateway resource (the shared L7 HTTPS Load Balancer)."
  type        = string
  default     = "external-https-gateway"
}

variable "gateway_namespace" {
  description = "Kubernetes namespace where the Gateway resource will be created."
  type        = string
  default     = "networking"
}

variable "app_namespace" {
  description = "Kubernetes namespace for the user's application (cu-app)."
  type        = string
  default     = "cu-app"
}
