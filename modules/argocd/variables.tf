# =============================================================================
# modules/argocd/variables.tf
# =============================================================================

variable "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD will be installed."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Helm chart version for ArgoCD (argo/argo-cd)."
  type        = string
  default     = "6.7.14"
}

variable "project_name" {
  description = "Short project name used for labelling resources."
  type        = string
}

variable "environment" {
  description = "Environment label (dev, staging, prod)."
  type        = string
}

variable "domain" {
  description = "Root domain. ArgoCD will be exposed at argocd.<domain>."
  type        = string
  default     = "nayaratech.online"
}

variable "gateway_name" {
  description = "Name of the shared GKE Gateway to attach the HTTPRoute to."
  type        = string
  default     = "external-https-gateway"
}

variable "gateway_namespace" {
  description = "Namespace of the shared GKE Gateway."
  type        = string
  default     = "networking"
}
