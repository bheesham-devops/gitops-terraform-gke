# =============================================================================
# modules/gcr/main.tf
#
# Google Artifact Registry — Docker repository
# (Official replacement for Google Container Registry)
#
# Resources:
#   1. Enable artifactregistry.googleapis.com API
#   2. Docker repository  : <project_name>-<environment>-docker
#   3. CI/CD Service Account : <project_name>-<environment>-cicd-sa
#   4. IAM Writer  → CI/CD SA   (GitHub Actions pushes images)
#   5. IAM Reader  → GKE node SA (cluster nodes pull images)
#   6. SA JSON key  → output as GCR_SA_KEY GitHub Actions secret
#
# Image URL format:
#   <region>-docker.pkg.dev/<project_id>/<repo_id>/<image>:<tag>
# =============================================================================

resource "google_project_service" "artifact_registry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.project_name}-${var.environment}-docker"
  description   = "Docker image repository for ${var.project_name} ${var.environment}"
  format        = "DOCKER"

  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }

  depends_on = [google_project_service.artifact_registry]
}

resource "google_service_account" "cicd" {
  account_id   = "${var.project_name}-${var.environment}-cicd-sa"
  display_name = "${var.project_name}-${var.environment}-cicd-sa"
  description  = "GitHub Actions CI/CD service account for ${var.project_name} ${var.environment}"
  project      = var.project_id
}

resource "google_artifact_registry_repository_iam_member" "cicd_push" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_artifact_registry_repository_iam_member" "gke_nodes_pull" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_node_service_account_email}"
}

resource "google_service_account_key" "cicd" {
  service_account_id = google_service_account.cicd.name
}





