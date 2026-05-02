# =============================================================================
# variables.tf  —  Root Module Input Variables
# =============================================================================

# ---------------------------------------------------------------------------
# Project & Region
# ---------------------------------------------------------------------------
variable "project_id" {
  description = "The GCP project ID where all resources will be created."
  type        = string
  default     = "cu-online-project"
}

variable "region" {
  description = "GCP region for all regional resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "A GCP zone within the region."
  type        = string
  default     = "us-central1-a"
}

# ---------------------------------------------------------------------------
# Environment / Naming
# ---------------------------------------------------------------------------
variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Short project name used as a prefix in all resource names."
  type        = string
  default     = "cu-online"
}

# ---------------------------------------------------------------------------
# Domain & DNS
# ---------------------------------------------------------------------------
variable "domain" {
  description = "Root domain name for all services. SSL covers *.domain and domain itself."
  type        = string
  default     = "nayaratech.online"
}

# ---------------------------------------------------------------------------
# Gateway (Shared L7 HTTPS Load Balancer)
# ---------------------------------------------------------------------------
variable "gateway_name" {
  description = "Name of the shared GKE Gateway resource."
  type        = string
  default     = "external-https-gateway"
}

variable "gateway_namespace" {
  description = "Kubernetes namespace where the Gateway resource lives."
  type        = string
  default     = "networking"
}

# ---------------------------------------------------------------------------
# Networking (VPC)
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Primary CIDR range for the custom VPC subnet."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range allocated to GKE Pods (VPC-native)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range allocated to GKE Services (VPC-native)."
  type        = string
  default     = "10.30.0.0/20"
}

# ---------------------------------------------------------------------------
# GKE Cluster
# ---------------------------------------------------------------------------
variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "cu-online-gke"
}

variable "kubernetes_version" {
  description = "Minimum Kubernetes master version. 'latest' resolves to the latest stable release."
  type        = string
  default     = "latest"
}

variable "node_machine_type" {
  description = "Compute machine type for GKE worker nodes."
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Boot disk size (GB) per GKE node."
  type        = number
  default     = 50
}

variable "node_count_initial" {
  description = "Initial number of nodes per zone when the node pool is first created."
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum nodes per zone for the cluster autoscaler."
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum nodes per zone for the cluster autoscaler."
  type        = number
  default     = 3
}

# ---------------------------------------------------------------------------
# Application Namespace
# ---------------------------------------------------------------------------
variable "app_namespace" {
  description = "Kubernetes namespace for the user's application."
  type        = string
  default     = "cu-app"
}

# ---------------------------------------------------------------------------
# ArgoCD
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Monitoring (Prometheus + Grafana)
# ---------------------------------------------------------------------------
variable "monitoring_namespace" {
  description = "Kubernetes namespace for the monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "monitoring_chart_version" {
  description = "Helm chart version for kube-prometheus-stack."
  type        = string
  default     = "58.6.0"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Set via TF_VAR_grafana_admin_password env var — do not hardcode."
  type        = string
  sensitive   = true
}
