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
#   4. IAM roles → CI/CD SA (Terraform + Docker push permissions)
#        - roles/editor                            CRUD on all GCP resources
#        - roles/resourcemanager.projectIamAdmin   Manage IAM bindings
#        - roles/iam.serviceAccountAdmin           Create/manage service accounts
#        - roles/iam.serviceAccountKeyAdmin        Create/manage SA keys
#        - roles/storage.admin                     Read/write GCS Terraform state
#   5. IAM Reader  → GKE node SA (cluster nodes pull images)
#   6. SA JSON key  → output as GCP_SA_KEY GitHub Actions secret
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

# ---------------------------------------------------------------------------
# CI/CD SA IAM Roles — Industry-standard Terraform SA permission set
#
# roles/editor                          → CRUD on all GCP resources (compute,
#                                         GKE, DNS, Certificate Manager, etc.)
#                                         Covers both terraform plan & apply.
# roles/resourcemanager.projectIamAdmin → Required to manage google_project_
#                                         iam_member resources in Terraform.
# roles/iam.serviceAccountAdmin         → Required to create/manage SAs.
# roles/iam.serviceAccountKeyAdmin      → Required to create SA JSON keys.
# roles/storage.admin                   → Read/write the GCS remote state
#                                         bucket (terraform init + plan + apply)
# ---------------------------------------------------------------------------
resource "google_project_iam_member" "cicd_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_sa_key_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountKeyAdmin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
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





