# =============================================================================
# modules/monitoring/main.tf
#
# Installs the kube-prometheus-stack Helm chart which bundles:
#   - Prometheus (metrics collection & alerting)
#   - Grafana (metrics dashboards)
#   - Alertmanager, Node Exporter, kube-state-metrics (bundled)
#
# Both Grafana and Prometheus are exposed via HTTPRoutes that attach to the
# shared GKE L7 Gateway in the "networking" namespace:
#   https://grafana.nayaratech.online    → Grafana dashboard
#   https://prometheus.nayaratech.online → Prometheus UI
# =============================================================================

# ---------------------------------------------------------------------------
# Monitoring Namespace
# All monitoring workloads (Prometheus, Grafana, Alertmanager) run here.
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace

    labels = {
      environment = var.environment
      managed-by  = "terraform"
      purpose     = "observability"
    }
  }
}

# ---------------------------------------------------------------------------
# kube-prometheus-stack Helm Release
#
# fullnameOverride = "monitoring" gives predictable service names:
#   Grafana   : monitoring-grafana      (port 80)
#   Prometheus: monitoring-prometheus   (port 9090)
#
# Both services are ClusterIP — the GKE Gateway handles external access.
# Grafana's root_url is set so links inside the UI use the correct domain.
# ---------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prom-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  timeout          = 600   # Allow 10 min for CRDs + all pods to become ready
  wait             = true

  # Use a predictable fullname so service names are always deterministic
  set {
    name  = "fullnameOverride"
    value = "monitoring"
  }

  # ------- Grafana -------------------------------------------------------

  # Securely pass the admin password (won't appear in plan output)
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # Set the public root URL so Grafana generates correct absolute links
  set {
    name  = "grafana.grafana\\.ini.server.root_url"
    value = "https://grafana.${var.domain}"
  }

  # ClusterIP — external traffic routes via the GKE Gateway, not NodePort
  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  # Disable the built-in Grafana Ingress (we use Gateway API instead)
  set {
    name  = "grafana.ingress.enabled"
    value = "false"
  }

  # ------- Prometheus ----------------------------------------------------

  # ClusterIP — external traffic routes via the GKE Gateway
  set {
    name  = "prometheus.service.type"
    value = "ClusterIP"
  }

  # Disable built-in Prometheus Ingress
  set {
    name  = "prometheus.ingress.enabled"
    value = "false"
  }

  # Increase Prometheus data retention to 30 days
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "30d"
  }

  # ------- Alertmanager --------------------------------------------------
  set {
    name  = "alertmanager.service.type"
    value = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ---------------------------------------------------------------------------
# Grafana HTTPRoute
# Attaches to the shared Gateway HTTPS listener.
# Routes all requests to "grafana.nayaratech.online" → monitoring-grafana:80
# ---------------------------------------------------------------------------
resource "kubernetes_manifest" "grafana_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "grafana-httproute"
      namespace = var.monitoring_namespace
    }

    spec = {
      parentRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          namespace   = var.gateway_namespace
          sectionName = "https"
        }
      ]

      # Route only requests matching this exact hostname
      hostnames = ["grafana.${var.domain}"]

      rules = [
        {
          backendRefs = [
            {
              group  = ""
              kind   = "Service"
              name   = "kube-prom-stack-grafana"  # Helm release name prefix (kube-prom-stack) + subchart
              port   = 80
              weight = 1
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ---------------------------------------------------------------------------
# Prometheus HTTPRoute
# Routes "prometheus.nayaratech.online" → monitoring-prometheus:9090
# ---------------------------------------------------------------------------
resource "kubernetes_manifest" "prometheus_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "prometheus-httproute"
      namespace = var.monitoring_namespace
    }

    spec = {
      parentRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          namespace   = var.gateway_namespace
          sectionName = "https"
        }
      ]

      hostnames = ["prometheus.${var.domain}"]

      rules = [
        {
          backendRefs = [
            {
              group  = ""
              kind   = "Service"
              # fullnameOverride="monitoring" → prometheus service = "monitoring-prometheus"
              name   = "monitoring-prometheus"
              port   = 9090
              weight = 1
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
