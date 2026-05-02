# =============================================================================
# modules/gke/main.tf
# Creates: GKE regional cluster, dedicated node pool, Workload Identity SA,
# and IAM bindings following least-privilege principles.
# =============================================================================

# ---------------------------------------------------------------------------
# Service Account for GKE Nodes
# Nodes use a dedicated SA with minimal permissions instead of the broad
# Compute Engine default SA (least-privilege principle).
# ---------------------------------------------------------------------------
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.project_name}-${var.environment}-gke-sa"
  display_name = "GKE Node Pool Service Account — ${var.project_name} ${var.environment}"
  project      = var.project_id
  description  = "Minimal-permission SA used by GKE worker nodes"
}

# ---------------------------------------------------------------------------
# IAM: Grant the node SA minimum required roles
# ---------------------------------------------------------------------------

# Write logs to Cloud Logging
resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Write metrics to Cloud Monitoring
resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Read monitoring metadata (required by Cloud Monitoring agent)
resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Pull container images from Artifact Registry / GCR
resource "google_project_iam_member" "gke_nodes_artifactregistry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ---------------------------------------------------------------------------
# GKE Regional Cluster
# A regional cluster distributes the control plane across 3 zones for HA.
# VPC-native (alias IPs) is enabled for better networking performance and
# to allow the cluster to scale without consuming extra node addresses.
# ---------------------------------------------------------------------------
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region # Regional cluster — control plane spans all zones in region

  # Remove the default node pool immediately; we manage our own node pool below
  remove_default_node_pool = true
  initial_node_count       = 1

  # Override the bootstrap node's disk type to avoid SSD quota issues on new
  # projects. This node is deleted immediately after the cluster is created
  # (remove_default_node_pool = true), so these settings are temporary.
  # Values are kept in sync with the managed node pool to avoid Terraform drift.
  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = var.node_disk_size_gb
    machine_type = var.node_machine_type
    tags         = ["gke-node", "http-server", "https-server"]
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  network    = var.network_name
  subnetwork = var.subnet_name

  # VPC-native networking — enables alias IPs for Pods and Services
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name    # Pod IPs
    services_secondary_range_name = var.services_range_name # Service IPs
  }

  # ---------------------------------------------------------------------------
  # Kubernetes Version
  # ---------------------------------------------------------------------------
  min_master_version = var.kubernetes_version == "latest" ? null : var.kubernetes_version

  # ---------------------------------------------------------------------------
  # Workload Identity
  # Allows Kubernetes service accounts to impersonate GCP service accounts
  # without needing to export and manage key files.
  # ---------------------------------------------------------------------------
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # ---------------------------------------------------------------------------
  # Logging & Monitoring
  # Sends cluster logs and metrics to Cloud Logging / Cloud Monitoring.
  # ---------------------------------------------------------------------------
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true # Enable Google Managed Prometheus for metrics collection
    }
  }

  # ---------------------------------------------------------------------------
  # Addons
  # ---------------------------------------------------------------------------
  addons_config {
    # HTTP Load Balancing — required for GKE Ingress to create GCP LBs
    http_load_balancing {
      disabled = false
    }

    # Horizontal Pod Autoscaling — scales pods based on CPU/memory metrics
    horizontal_pod_autoscaling {
      disabled = false
    }

    # Network Policy (Calico) — enables K8s NetworkPolicy enforcement
    network_policy_config {
      disabled = false
    }
  }

  # Enable network policy enforcement on the cluster
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # ---------------------------------------------------------------------------
  # Gateway API
  # CHANNEL_STANDARD installs the stable Gateway API CRDs automatically.
  # Required for the GKE L7 Global External Managed Load Balancer Gateway.
  # ---------------------------------------------------------------------------
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # ---------------------------------------------------------------------------
  # Release Channel
  # REGULAR channel provides stable, tested Kubernetes versions with
  # automatic upgrades managed by GKE.
  # ---------------------------------------------------------------------------
  release_channel {
    channel = "REGULAR"
  }

  # ---------------------------------------------------------------------------
  # Maintenance Window
  # GKE requires at least 48h of maintenance availability per 32-day window
  # with >= 4h contiguous blocks. We allow daily 02:00–06:00 UTC to satisfy
  # this requirement while keeping disruption to off-peak hours.
  # ---------------------------------------------------------------------------
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z" # Daily 02:00 UTC
      end_time   = "2024-01-01T06:00:00Z" # Daily 06:00 UTC
      recurrence = "FREQ=DAILY"
    }
  }

  # Prevent accidental deletion of the cluster
  deletion_protection = false # Set to true in production after initial setup

  description = "GKE cluster for ${var.project_name} ${var.environment} environment"
}

# ---------------------------------------------------------------------------
# Node Pool
# Separate node pool with autoscaling, shielded nodes, and Workload Identity.
# Using a separate node pool allows independent upgrades and configuration.
# ---------------------------------------------------------------------------
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-node-pool"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.primary.name

  # Initial node count per zone (regional cluster spreads across 3 zones)
  initial_node_count = var.node_count_initial

  # ---------------------------------------------------------------------------
  # Autoscaling
  # ---------------------------------------------------------------------------
  autoscaling {
    min_node_count = var.node_min_count # Minimum nodes per zone
    max_node_count = var.node_max_count # Maximum nodes per zone
  }

  # ---------------------------------------------------------------------------
  # Node Management
  # Auto-repair: automatically replaces unhealthy nodes.
  # Auto-upgrade: keeps nodes on the latest GKE patch version.
  # ---------------------------------------------------------------------------
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # ---------------------------------------------------------------------------
  # Upgrade Strategy
  # Blue-green upgrades create new nodes before draining old ones,
  # minimising disruption during version upgrades.
  # ---------------------------------------------------------------------------
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1 # One extra node created during upgrade
    max_unavailable = 0 # No nodes taken offline while surge node is not ready
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size_gb
    disk_type    = "pd-standard" # Standard HDD — avoids SSD quota limits on new projects

    # Attach the dedicated minimal-permission service account
    service_account = google_service_account.gke_nodes.email

    # OAuth scopes required by the node SA (minimal set)
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Shielded nodes protect against boot-level and kernel-level malware
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Enable Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Labels for node selection and cost attribution
    labels = {
      environment  = var.environment
      project      = var.project_name
      managed-by   = "terraform"
      node-pool    = "primary"
    }

    # Network tags used by firewall rules
    tags = ["gke-node", "http-server", "https-server"]
  }
}
