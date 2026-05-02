# =============================================================================
# backend.tf — Remote State Configuration
#
# Stores Terraform state in Google Cloud Storage (GCS).
# GCS is the GCP equivalent of AWS S3 + DynamoDB:
#   - State storage  → GCS bucket (cu-online-prod-tfstate)
#   - State locking  → Built into GCS backend natively (no extra resource needed)
#   - Versioning     → Enabled on the bucket — every state change is preserved
#
# The bucket is created once via gcloud CLI (bootstrap) before terraform init,
# because Terraform cannot manage the bucket that stores its own state.
#
# Bootstrap command (already executed — do not re-run):
#   gcloud storage buckets create gs://cu-online-prod-tfstate \
#     --project=cu-online-project \
#     --location=us-central1 \
#     --uniform-bucket-level-access \
#     --public-access-prevention
#   gcloud storage buckets update gs://cu-online-prod-tfstate --versioning
# =============================================================================

terraform {
  backend "gcs" {
    bucket = "cu-online-prod-tfstate"
    prefix = "terraform/state"
  }
}
