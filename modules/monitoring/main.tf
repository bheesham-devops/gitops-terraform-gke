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

  # Persistent storage — prevents metric loss on pod restarts (30d retention needs durable storage)
  # Uses GKE's standard-rwo StorageClass (ReadWriteOnce regional persistent disk)
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "standard-rwo"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "20Gi"
  }

  # Resource requests & limits — prevent Prometheus from causing node memory pressure
  # on e2-standard-2 nodes (8 GB RAM). Requests guarantee scheduling, limits cap runaway usage.
  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "200m"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "512Mi"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "2Gi"
  }

  # ------- GKE Control-Plane Components ----------------------------------
  # GKE manages kube-scheduler, kube-controller-manager and kube-proxy as
  # opaque GCP-side components — their metrics endpoints are not reachable
  # from the data plane. Disabling these prevents the three CRITICAL firing
  # alerts: KubeSchedulerDown, KubeControllerManagerDown, KubeProxyDown.
  set {
    name  = "kubeScheduler.enabled"
    value = "false"
  }
  set {
    name  = "kubeControllerManager.enabled"
    value = "false"
  }
  set {
    name  = "kubeProxy.enabled"
    value = "false"
  }

  # GKE ships kube-dns (not upstream CoreDNS) — the standard CoreDNS
  # ServiceMonitor targeting port 9153 finds no responding container,
  # causing the TargetDown WARNING alert. Disable to stop false-positive.
  set {
    name  = "coreDns.enabled"
    value = "false"
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
