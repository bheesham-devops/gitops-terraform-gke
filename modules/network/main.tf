# =============================================================================
# modules/network/main.tf
# Creates: custom VPC, subnet with secondary ranges, Cloud Router, Cloud NAT,
# and firewall rules for internal traffic, SSH, HTTP, and HTTPS.
# =============================================================================

# ---------------------------------------------------------------------------
# Custom VPC Network
# We explicitly create a VPC instead of using the auto-mode default network
# to have full control over IP ranges and avoid overlapping CIDRs.
# ---------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = "${var.project_name}-${var.environment}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false # Disable auto subnets — we create our own
  routing_mode            = "REGIONAL"

  description = "Custom VPC for ${var.project_name} ${var.environment} environment"
}

# ---------------------------------------------------------------------------
# Primary Subnet
# Hosts GKE nodes. Secondary ranges are used by VPC-native GKE for
# Pod IPs (pods_range) and Service ClusterIPs (services_range).
# Private Google Access allows nodes without external IPs to reach GCP APIs.
# ---------------------------------------------------------------------------
resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.project_name}-${var.environment}-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.vpc_cidr
  private_ip_google_access = true # Allow nodes to reach Google APIs privately

  # Secondary range for GKE Pods
  secondary_ip_range {
    range_name    = "${var.project_name}-pods"
    ip_cidr_range = var.pods_cidr
  }

  # Secondary range for GKE Services
  secondary_ip_range {
    range_name    = "${var.project_name}-services"
    ip_cidr_range = var.services_cidr
  }

  description = "Primary subnet for ${var.project_name} ${var.environment} GKE nodes"
}

# ---------------------------------------------------------------------------
# Cloud Router
# Required by Cloud NAT to provide outbound internet access to nodes that
# do not have external (public) IP addresses.
# ---------------------------------------------------------------------------
resource "google_compute_router" "router" {
  name    = "${var.project_name}-${var.environment}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id

  description = "Cloud Router for Cloud NAT outbound internet access"
}

# ---------------------------------------------------------------------------
# Cloud NAT
# Provides outbound internet access (e.g., pulling container images) to GKE
# nodes that only have private IP addresses.
# ---------------------------------------------------------------------------
resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-${var.environment}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"           # GCP manages NAT IPs
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---------------------------------------------------------------------------
# Firewall: Allow Internal Communication
# Permits all TCP, UDP, and ICMP traffic within the VPC subnet range.
# Required for inter-pod and node-to-node communication.
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_name}-${var.environment}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow all internal traffic within the VPC subnet"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  # Match traffic originating from our VPC CIDR, pod CIDR, and service CIDR
  source_ranges = [var.vpc_cidr, var.pods_cidr, var.services_cidr]
  priority      = 1000
}

# ---------------------------------------------------------------------------
# Firewall: Allow SSH (port 22)
# Restricts SSH access to Google's IAP (Identity-Aware Proxy) IP range so
# that SSH sessions must go through IAP rather than directly from the internet.
# Change source_ranges to ["0.0.0.0/0"] only in development if needed.
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.project_name}-${var.environment}-allow-ssh"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow SSH access via Google IAP only"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # 35.235.240.0/20 is the Google IAP IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["gke-node"]
  priority      = 1000
}

# ---------------------------------------------------------------------------
# Firewall: Allow HTTP (port 80)
# Required for GKE Ingress health checks and HTTP traffic to the Load Balancer.
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_http" {
  name    = "${var.project_name}-${var.environment}-allow-http"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow HTTP traffic from the internet to the Load Balancer"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
  priority      = 1000
}

# ---------------------------------------------------------------------------
# Firewall: Allow HTTPS (port 443)
# Required for TLS termination at the GCP HTTP(S) Load Balancer.
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_https" {
  name    = "${var.project_name}-${var.environment}-allow-https"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow HTTPS traffic from the internet to the Load Balancer"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
  priority      = 1000
}

# ---------------------------------------------------------------------------
# Firewall: Allow GKE Master to Node communication
# GKE masters need to reach nodes on port 8443 (webhooks) and 10250 (kubelet).
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_gke_master" {
  name    = "${var.project_name}-${var.environment}-allow-gke-master"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow GKE control plane to communicate with worker nodes"

  allow {
    protocol = "tcp"
    ports    = ["8443", "9443", "10250"]
  }

  # GKE master CIDR — replace with your cluster's master_ipv4_cidr_block if using private clusters
  source_ranges = ["172.16.0.0/28"]
  target_tags   = ["gke-node"]
  priority      = 1000
}
