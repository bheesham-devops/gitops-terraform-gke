# =============================================================================
# providers.tf  —  Root Module
# Declares all required Terraform providers and their versions.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Google Cloud provider — manages all GCP resources
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }

    # Google Beta provider — needed for some GKE advanced features
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }

    # Kubernetes provider — manages K8s resources (Namespaces, Deployments, etc.)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }

    # Helm provider — deploys ArgoCD via Helm chart
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    # Random provider — generates unique name suffixes
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    # Null provider — used by the gcr module to trigger gcloud init via local-exec
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote State (GCS backend)
  # Store Terraform state in a GCS bucket for team collaboration and locking.
  # Create the bucket manually once before running `terraform init`:
  #   gcloud storage buckets create gs://cu-online-tfstate \
  #     --project=cu-online-project --location=us-central1 \
  #     --uniform-bucket-level-access
  # Then uncomment the block below:
  # ---------------------------------------------------------------------------
  # backend "gcs" {
  #   bucket = "cu-online-tfstate"
  #   prefix = "gke-platform/terraform.tfstate"
  # }
}

# ---------------------------------------------------------------------------
# Google Provider
# Credentials are sourced from Application Default Credentials (ADC).
# Run: gcloud auth application-default login
# Never hardcode credentials in provider blocks.
# ---------------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------
# Kubernetes Provider
# Authenticates to GKE using the cluster endpoint and a short-lived token
# obtained from the google_client_config data source.
# ---------------------------------------------------------------------------
provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

# ---------------------------------------------------------------------------
# Helm Provider
# Uses the same GKE credentials as the Kubernetes provider above.
# ---------------------------------------------------------------------------
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}

# ---------------------------------------------------------------------------
# Data Source: current authenticated GCP client
# Provides a short-lived OAuth2 access token for Kubernetes/Helm providers.
# ---------------------------------------------------------------------------
data "google_client_config" "default" {}
