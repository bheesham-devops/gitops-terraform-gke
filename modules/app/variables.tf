# =============================================================================
# modules/app/variables.tf
# =============================================================================

variable "app_namespace" {
  description = "Kubernetes namespace for the user's application."
  type        = string
  default     = "cu-app"
}

variable "environment" {
  description = "Environment label (dev, staging, prod)."
  type        = string
}
