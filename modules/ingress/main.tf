# =============================================================================
# modules/ingress/main.tf
#
# Provisions everything needed for a SINGLE shared GCP L7 HTTPS Load Balancer:
#   - A reserved global static IP (all DNS A records point here)
#   - Google Certificate Manager DNS authorization (wildcard DNS challenge)
#   - Wildcard managed certificate  (*.nayaratech.online + nayaratech.online)
#   - Certificate Map that binds the cert to the Gateway
#   - GKE L7 Global External Managed Gateway  (HTTPS:443 + HTTP:80)
#   - HTTP → HTTPS permanent redirect HTTPRoute
#   - "networking" and "cu-app" Kubernetes namespaces
#
# All application HTTPRoutes (ArgoCD, Grafana, Prometheus, App) live in their
# own modules but attach to this single Gateway.
# =============================================================================

# ---------------------------------------------------------------------------
# Global Static IP Address
# All DNS A records point to this single IP.
# Reserve it before adding DNS records so the IP never changes.
# ---------------------------------------------------------------------------
resource "google_compute_global_address" "ingress_ip" {
  name        = "${var.project_name}-${var.environment}-ingress-ip"
  project     = var.project_id
  description = "Shared static IP for all services behind nayaratech.online"
}

# ---------------------------------------------------------------------------
# Certificate Manager: DNS Authorization
# Google creates a DNS CNAME challenge record under your domain.
# You MUST add this CNAME to Namecheap BEFORE the certificate becomes ACTIVE.
#
# After terraform apply, run:
#   terraform output dns_cname_instructions
# and add the CNAME record shown there to Namecheap.
#
# A single authorization for "nayaratech.online" covers the wildcard
# *.nayaratech.online per Google Certificate Manager policy.
# ---------------------------------------------------------------------------
resource "google_certificate_manager_dns_authorization" "root" {
  name        = "${var.project_name}-${var.environment}-dns-auth"
  project     = var.project_id
  domain      = var.domain
  description = "DNS authorization for ${var.domain} (covers wildcard *.${var.domain})"
}

# ---------------------------------------------------------------------------
# Certificate Manager: Wildcard Managed Certificate
# Covers both "*.nayaratech.online" and "nayaratech.online".
# Status remains PROVISIONING until the DNS CNAME challenge is satisfied.
# Once the CNAME is added to Namecheap, provisioning takes ~10-20 minutes.
# ---------------------------------------------------------------------------
resource "google_certificate_manager_certificate" "wildcard" {
  name        = "${var.project_name}-${var.environment}-wildcard-cert"
  project     = var.project_id
  description = "Wildcard TLS certificate for *.${var.domain}"

  managed {
    domains = [
      "*.${var.domain}", # Covers argocd.*, grafana.*, prometheus.*, app.*
      var.domain,        # Covers the root domain itself
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.root.id,
    ]
  }
}

# ---------------------------------------------------------------------------
# Certificate Manager: Certificate Map
# The Gateway references a Certificate Map (not a cert directly).
# The PRIMARY matcher applies the wildcard cert to all unmatched hostnames.
# ---------------------------------------------------------------------------
resource "google_certificate_manager_certificate_map" "cert_map" {
  name        = "${var.project_name}-${var.environment}-cert-map"
  project     = var.project_id
  description = "Certificate map binding the wildcard cert to all ${var.domain} subdomains"
}

resource "google_certificate_manager_certificate_map_entry" "wildcard" {
  name         = "${var.project_name}-${var.environment}-wildcard-entry"
  project      = var.project_id
  map          = google_certificate_manager_certificate_map.cert_map.name
  certificates = [google_certificate_manager_certificate.wildcard.id]
  # PRIMARY matcher = default fallback entry, applies to all unmatched hostnames
  matcher     = "PRIMARY"
  description = "Wildcard cert entry — applies to all *.${var.domain} hostnames"
}

# ---------------------------------------------------------------------------
# Kubernetes Namespace: networking
# Hosts the Gateway resource. Keeping it separate from workloads ensures
# clear ownership and avoids accidental deletion with app namespaces.
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "networking" {
  metadata {
    name = var.gateway_namespace

    labels = {
      environment = var.environment
      managed-by  = "terraform"
      purpose     = "ingress-gateway"
    }
  }
}

# ---------------------------------------------------------------------------
# Kubernetes Namespace: cu-app
# Placeholder namespace for the user's application.
# The user deploys their app here and adds an HTTPRoute targeting this namespace.
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "cu_app" {
  metadata {
    name = var.app_namespace

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# GKE L7 Global External Managed HTTPS Gateway
#
# This single Gateway resource creates ONE GCP HTTP(S) Load Balancer that
# serves ALL services: ArgoCD, Grafana, Prometheus, and the user's app.
#
# Key design decisions:
#   gatewayClassName: gke-l7-global-external-managed
#     → GKE's globally-distributed, Google-managed HTTPS LB (anycast IP)
#   networking.gke.io/certmap annotation
#     → Links the Certificate Manager cert map for automatic TLS
#   spec.addresses[].type = "NamedAddress"
#     → Binds the Gateway to our reserved static IP by GCP resource name
#   allowedRoutes.namespaces.from = "All"
#     → HTTPRoute objects in argocd, monitoring, cu-app namespaces can
#       all attach to this single Gateway
#   HTTPS listener (443) — TLS terminated here, plain HTTP forwarded to backends
#   HTTP  listener (80)  — Used only for HTTP→HTTPS permanent redirect
# ---------------------------------------------------------------------------
resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"

    metadata = {
      name      = var.gateway_name
      namespace = var.gateway_namespace
      # For GKE Gateway API + Certificate Manager, the cert map is referenced
      # via a Gateway annotation. The HTTPS listener must have NO tls block.
      annotations = {
        "networking.gke.io/certmap" = google_certificate_manager_certificate_map.cert_map.name
      }
    }

    spec = {
      # GKE's globally-distributed L7 external HTTPS load balancer
      gatewayClassName = "gke-l7-global-external-managed"

      # Bind to our reserved static IP by GCP resource name (not IP string)
      addresses = [
        {
          type  = "NamedAddress"
          value = google_compute_global_address.ingress_ip.name
        }
      ]

      listeners = [
        # ----- HTTPS listener: TLS terminated by cert map annotation ---------
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          allowedRoutes = {
            namespaces = {
              # Allow HTTPRoutes from ALL namespaces to attach to this listener
              from = "All"
            }
          }
        },

        # ----- HTTP listener: redirect only ----------------------------------
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.networking,
    google_certificate_manager_certificate_map_entry.wildcard,
    google_compute_global_address.ingress_ip,
  ]
}

# ---------------------------------------------------------------------------
# HTTP → HTTPS Redirect HTTPRoute
# Any request arriving on port 80 (any hostname) is permanently redirected
# (HTTP 301) to the same URL on HTTPS.
# This HTTPRoute lives in the "networking" namespace alongside the Gateway.
# ---------------------------------------------------------------------------
resource "kubernetes_manifest" "http_redirect" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "http-to-https-redirect"
      namespace = var.gateway_namespace
    }

    spec = {
      parentRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          namespace   = var.gateway_namespace
          sectionName = "http" # Attach to the HTTP (port 80) listener only
        }
      ]

      # Match all hostnames on port 80
      rules = [
        {
          filters = [
            {
              type = "RequestRedirect"
              requestRedirect = {
                scheme     = "https"
                statusCode = 301 # Permanent redirect
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}
