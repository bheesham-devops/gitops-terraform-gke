# =============================================================================
# terraform.tfvars  —  Environment-specific variable overrides
# =============================================================================

project_id   = "cu-online-project"
region       = "us-central1"
zone         = "us-central1-a"
environment  = "prod"
project_name = "cu-online"

# Domain — all services will be subdomains of this domain
domain = "nayaratech.online"

# Shared Gateway (single Load Balancer for all services)
gateway_name      = "external-https-gateway"
gateway_namespace = "networking"

# Networking
vpc_cidr      = "10.10.0.0/20"
pods_cidr     = "10.20.0.0/16"
services_cidr = "10.30.0.0/20"

# GKE
cluster_name       = "cu-online-gke"
kubernetes_version = "latest"
node_machine_type  = "e2-standard-2"
node_disk_size_gb  = 50
node_count_initial = 1
node_min_count     = 1
node_max_count     = 3

# Application namespace
app_namespace = "cu-app"

# ArgoCD
argocd_namespace     = "argocd"
argocd_chart_version = "6.7.14"

# Monitoring
monitoring_namespace     = "monitoring"
monitoring_chart_version = "58.6.0"

# Grafana admin password
# SECURITY: Set this via environment variable instead of hardcoding:
#   export TF_VAR_grafana_admin_password="YourStrongPassword123!"
# OR use a secrets manager. The value below is a placeholder only.
grafana_admin_password = "ChangeMe@Grafana2026!"
