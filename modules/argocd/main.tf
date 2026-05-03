# =============================================================================
# modules/argocd/main.tf
# Installs ArgoCD via Helm and exposes it through a GKE Ingress /
# GCP HTTP(S) Load Balancer.
# =============================================================================

# ---------------------------------------------------------------------------
# Namespace
# ArgoCD runs in its own namespace for isolation and RBAC scoping.
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# ArgoCD Helm Release
# Installs ArgoCD from the official Argo Helm repository.
# Key config choices:
#   - server.insecure=true: Disable ArgoCD's own TLS so the GCP LB handles it.
#   - server.service.type=NodePort: Required for GKE Ingress to work.
#   - Replicas set to 2 for HA (requires HA Redis; adjust for dev/test).
# ---------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false # Namespace already created above
  timeout          = 600   # 10-minute timeout for chart installation
  wait             = true  # Block until all pods are Running/Ready

  # ---------------------------------------------------------------------------
  # ArgoCD Configuration Values
  # ---------------------------------------------------------------------------

  # Run ArgoCD server without TLS — the GCP Load Balancer handles TLS termination
  set {
    name  = "server.insecure"
    value = "true"
  }

  # NodePort service is required for GKE Ingress to route traffic
  set {
    name  = "server.service.type"
    value = "NodePort"
  }

  # Expose the ArgoCD server on port 80 (Ingress will forward to this)
  set {
    name  = "server.service.servicePortHttp"
    value = "80"
  }

  # Run 2 ArgoCD server replicas for availability
  set {
    name  = "server.replicas"
    value = "2"
  }

  # Resource limits for the ArgoCD server container
  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "server.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "server.resources.limits.memory"
    value = "512Mi"
  }

  # Enable Redis HA for production resilience (set to false for dev/staging)
  set {
    name  = "redis-ha.enabled"
    value = "false"
  }

  # Application controller resource settings
  set {
    name  = "controller.resources.requests.cpu"
    value = "250m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }

  depends_on = [kubernetes_namespace.argocd]
}

# ---------------------------------------------------------------------------
# ArgoCD Server Ingress (REMOVED)
# The old GCE HTTP-only ingress was manually deleted and replaced by a
# Gateway API HTTPRoute managed in cuonline-gitops/manifests/argocd-httproute.yaml.
# ArgoCD is now served over HTTPS via the shared external Gateway with a
# wildcard certificate — no separate GCE Ingress is needed.
# ---------------------------------------------------------------------------
