# =============================================================================
# main.tf  —  Root Module
# Orchestrates all child modules: APIs, Network, GKE, Ingress, ArgoCD,
# Monitoring, and the user's application namespace.
#
# Architecture:
#   One GCP L7 Global HTTPS Load Balancer (via GKE Gateway API)
#   └── argocd.nayaratech.online     → ArgoCD (argocd namespace)
#   └── grafana.nayaratech.online    → Grafana (monitoring namespace)
#   └── prometheus.nayaratech.online → Prometheus (monitoring namespace)
#   └── app.nayaratech.online        → User's app (cu-app namespace)
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Enable Required GCP APIs
# ---------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "dns.googleapis.com",
    "certificatemanager.googleapis.com", # Google Certificate Manager (managed SSL)
    "networkservices.googleapis.com",    # Required for GKE Gateway API
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# 2. Network Module
# Custom VPC, subnet (with secondary ranges), Cloud Router, Cloud NAT,
# and firewall rules.
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  project_id    = var.project_id
  region        = var.region
  project_name  = var.project_name
  environment   = var.environment
  vpc_cidr      = var.vpc_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# 3. GKE Module
# Regional cluster with Gateway API enabled, Workload Identity, autoscaling,
# Cloud Logging/Monitoring, and Shielded nodes.
# ---------------------------------------------------------------------------
module "gke" {
  source = "./modules/gke"

  project_id          = var.project_id
  region              = var.region
  project_name        = var.project_name
  environment         = var.environment
  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  node_machine_type   = var.node_machine_type
  node_disk_size_gb   = var.node_disk_size_gb
  node_count_initial  = var.node_count_initial
  node_min_count      = var.node_min_count
  node_max_count      = var.node_max_count
  network_name        = module.network.network_name
  subnet_name         = module.network.subnet_name
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  depends_on = [module.network]
}

# ---------------------------------------------------------------------------
# 4. Ingress Module
# Provisions the shared GCP L7 HTTPS Load Balancer via GKE Gateway API:
#   - Global static IP (all DNS A records point here)
#   - Google Certificate Manager wildcard SSL cert (*.nayaratech.online)
#   - GKE Gateway resource (networking namespace)
#   - HTTP → HTTPS permanent redirect
#   - "networking" and "cu-app" Kubernetes namespaces
# ---------------------------------------------------------------------------
module "ingress" {
  source = "./modules/ingress"

  project_id        = var.project_id
  project_name      = var.project_name
  environment       = var.environment
  domain            = var.domain
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  app_namespace     = var.app_namespace

  depends_on = [module.gke]
}

# ---------------------------------------------------------------------------
# 5. Application Namespace Module
# Creates the "cu-app" namespace for the user's application.
# The user deploys workloads here via ArgoCD or kubectl, then adds an
# HTTPRoute pointing to app.nayaratech.online.
# ---------------------------------------------------------------------------
module "app" {
  source = "./modules/app"

  app_namespace = var.app_namespace
  environment   = var.environment

  depends_on = [module.ingress]
}

# ---------------------------------------------------------------------------
# 6. ArgoCD Module
# Installs ArgoCD via Helm and registers an HTTPRoute on the shared Gateway:
#   https://argocd.nayaratech.online
# ---------------------------------------------------------------------------
module "argocd" {
  source = "./modules/argocd"

  argocd_namespace     = var.argocd_namespace
  argocd_chart_version = var.argocd_chart_version
  project_name         = var.project_name
  environment          = var.environment
  domain               = var.domain
  gateway_name         = var.gateway_name
  gateway_namespace    = var.gateway_namespace

  depends_on = [module.ingress]
}

# ---------------------------------------------------------------------------
# 7. Monitoring Module
# Installs kube-prometheus-stack (Prometheus + Grafana) and registers
# HTTPRoutes on the shared Gateway:
#   https://grafana.nayaratech.online
#   https://prometheus.nayaratech.online
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  monitoring_namespace   = var.monitoring_namespace
  chart_version          = var.monitoring_chart_version
  environment            = var.environment
  domain                 = var.domain
  gateway_name           = var.gateway_name
  gateway_namespace      = var.gateway_namespace
  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.ingress]
}

# ---------------------------------------------------------------------------
# 8. Google Container Registry (GCR) Module
#
# - Enables containerregistry.googleapis.com + storage.googleapis.com APIs
# - Creates a dedicated CI/CD Service Account (least-privilege)
# - Grants the CI/CD SA  storage.admin   on the GCR GCS bucket  (push/pull)
# - Grants the GKE node SA  storage.objectViewer  on the GCR GCS bucket (pull)
# - Generates a SA JSON key exported as a sensitive Terraform output
#
# After `terraform apply`, run:
#   terraform output -raw cicd_sa_key_base64
# Copy the value and add it as the GCR_SA_KEY secret in GitHub Actions.
# ---------------------------------------------------------------------------
module "gcr" {
  source = "./modules/gcr"

  project_id                     = var.project_id
  region                         = var.region
  project_name                   = var.project_name
  environment                    = var.environment
  gke_node_service_account_email = module.gke.node_service_account_email

  depends_on = [google_project_service.apis, module.gke]
}
