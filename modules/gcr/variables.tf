# =============================================================================
# modules/gcr/variables.tf
# =============================================================================

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the Artifact Registry repository."
  type        = string
}

variable "project_name" {
  description = "Short project name used as a prefix in resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment label (dev | staging | prod)."
  type        = string
}

variable "gke_node_service_account_email" {
  description = "Email of the GKE node pool SA. Granted artifactregistry.reader so nodes can pull images."
  type        = string
}

