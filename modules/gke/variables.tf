# =============================================================================
# modules/gke/variables.tf
# =============================================================================

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the GKE cluster."
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

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Minimum Kubernetes master version. Use 'latest' for latest stable."
  type        = string
  default     = "latest"
}

variable "node_machine_type" {
  description = "Machine type for GKE worker nodes."
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Boot disk size (GB) per node."
  type        = number
  default     = 50
}

variable "node_count_initial" {
  description = "Initial number of nodes per zone."
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum nodes per zone for autoscaling."
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum nodes per zone for autoscaling."
  type        = number
  default     = 3
}

variable "network_name" {
  description = "Name of the VPC network to attach the cluster to."
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnetwork to attach the cluster to."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for Pods."
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary IP range for Services."
  type        = string
}
