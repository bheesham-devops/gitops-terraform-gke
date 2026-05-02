# =============================================================================
# modules/network/variables.tf
# =============================================================================

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the subnet and Cloud Router."
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

variable "vpc_cidr" {
  description = "Primary CIDR range for the subnet."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE Pods."
  type        = string
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE Services."
  type        = string
}
