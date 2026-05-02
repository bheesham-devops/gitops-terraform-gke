# =============================================================================
# modules/gcr/outputs.tf
# =============================================================================

output "image_registry" {
  description = "Full Artifact Registry hostname + repo. Use as the image registry in the CI pipeline."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "cicd_service_account_email" {
  description = "Email of the CI/CD Service Account."
  value       = google_service_account.cicd.email
}

output "cicd_sa_key_base64" {
  description = "Base64-encoded JSON key. Run: terraform output -raw cicd_sa_key_base64 → set as GCR_SA_KEY GitHub secret."
  value       = google_service_account_key.cicd.private_key
  sensitive   = true
}
