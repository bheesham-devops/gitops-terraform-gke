# GitOps Terraform GKE Platform

A **production-ready, modular Terraform** Infrastructure-as-Code solution that provisions a complete GKE-based application platform on Google Cloud from scratch.

---

## Architecture Overview

```
GitOps-Terraform-GKE/
├── providers.tf          # Provider declarations (google, kubernetes, helm)
├── variables.tf          # Root module input variables
├── terraform.tfvars      # Environment-specific values
├── main.tf               # Root orchestration (calls all modules)
├── outputs.tf            # Exposes key infrastructure values
├── .gitignore
└── modules/
    ├── network/          # VPC, Subnet, Cloud NAT, Firewall rules
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── gke/              # GKE Cluster, Node Pool, SA, IAM
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── app/              # Sample nginx app + GCP Load Balancer Ingress
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── argocd/           # ArgoCD via Helm + GCP Load Balancer Ingress
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### What Gets Provisioned

| Layer | Resource |
|---|---|
| **APIs** | Compute, GKE, IAM, Logging, Monitoring, DNS |
| **Network** | Custom VPC, Subnet (primary + 2 secondary ranges), Cloud Router, Cloud NAT, 5 Firewall rules |
| **GKE** | Regional cluster (us-central1), dedicated node pool (e2-standard-2), autoscaling (2–3 nodes/zone), Workload Identity, Cloud Logging/Monitoring |
| **IAM** | Dedicated node SA with least-privilege roles (logWriter, metricWriter, artifactregistry.reader) |
| **App** | nginx Deployment (2 replicas), NodePort Service, GCP HTTP LB via Ingress |
| **ArgoCD** | Helm release (argo-cd), GCP HTTP LB via Ingress |

---

## Prerequisites

### 1. Install Google Cloud CLI (gcloud)

**macOS (Homebrew):**
```bash
brew install --cask google-cloud-sdk
```

**Manual download:**
```bash
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz
tar -xf google-cloud-cli-darwin-arm.tar.gz
./google-cloud-sdk/install.sh
```

Verify:
```bash
gcloud version
```

### 2. Install Terraform

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Verify:
```bash
terraform version   # Must be >= 1.5.0
```

### 3. Install kubectl

```bash
brew install kubectl
```

---

## Step 1 — Authenticate with Google Cloud

```bash
# Log in with your Google account
gcloud auth login

# Set up Application Default Credentials (used by Terraform providers)
gcloud auth application-default login

# Set the active project
gcloud config set project cu-online-project

# Verify the active project
gcloud config get-value project
```

---

## Step 2 — (Optional) Enable Remote State

Remote state in GCS enables collaboration and prevents state conflicts.

> Skip this step to use local state during initial development.

```bash
# Create the GCS bucket for Terraform state
gcloud storage buckets create gs://cu-online-tfstate \
  --project=cu-online-project \
  --location=us-central1 \
  --uniform-bucket-level-access

# Then uncomment the backend block in providers.tf:
# backend "gcs" {
#   bucket = "cu-online-tfstate"
#   prefix = "gke-platform/terraform.tfstate"
# }
```

---

## Step 3 — Initialize Terraform

```bash
cd GitOps-Terraform-GKE/

terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

---

## Step 4 — Review the Plan

```bash
terraform plan -out=tfplan
```

Review the output carefully. You should see ~30+ resources to be created.

---

## Step 5 — Apply

```bash
terraform apply tfplan
```

> ⏱️ This takes **10–15 minutes** — GKE cluster provisioning takes the longest.

When complete, Terraform prints all outputs:
```
Outputs:

argocd_admin_password_command = "kubectl -n argocd get secret argocd-initial-admin-secret ..."
argocd_ingress_ip             = "34.x.x.x"
argocd_url                    = "http://34.x.x.x"
app_ingress_ip                = "34.x.x.x"
app_url                       = "http://34.x.x.x"
gke_cluster_name              = "cu-online-gke"
kubeconfig_command            = "gcloud container clusters get-credentials ..."
vpc_network_name              = "cu-online-prod-vpc"
vpc_subnet_name               = "cu-online-prod-subnet"
```

---

## Step 6 — Access the GKE Cluster

```bash
# Configure kubectl (copy the exact command from Terraform output)
gcloud container clusters get-credentials cu-online-gke \
  --region us-central1 \
  --project cu-online-project

# Verify cluster connectivity
kubectl get nodes

# Expected output — 6 nodes (2 per zone × 3 zones in us-central1):
# NAME                                          STATUS   ROLES    AGE   VERSION
# gke-cu-online-gke-node-pool-xxxxx-xxxxx       Ready    <none>   5m    v1.xx.x
```

---

## Step 7 — Access the Sample Application

> ⏱️ Load Balancer IP assignment can take **2–5 minutes** after `terraform apply`.

```bash
# Get the application IP from Terraform output
terraform output app_url

# Or fetch it directly from Kubernetes
kubectl get ingress -n demo-app

# Open in browser
open $(terraform output -raw app_url)
```

You should see the **nginx welcome page**.

---

## Step 8 — Access ArgoCD

### Get the External IP

```bash
terraform output argocd_url

# Or directly:
kubectl get ingress -n argocd
```

### Retrieve the Admin Password

```bash
# Copy and run the command from Terraform output:
terraform output -raw argocd_admin_password_command | bash

# Or manually:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### Log in to ArgoCD

| Field | Value |
|---|---|
| **URL** | `http://<argocd_ingress_ip>` |
| **Username** | `admin` |
| **Password** | Output from command above |

> ⚠️ **Change the admin password immediately** after first login in production:
> ```bash
> argocd login <argocd_ingress_ip> --username admin --password <password>
> argocd account update-password
> ```

---

## Verify Everything is Running

```bash
# All nodes Ready
kubectl get nodes

# All pods Running across namespaces
kubectl get pods -A

# Check demo app
kubectl get all -n demo-app

# Check ArgoCD
kubectl get all -n argocd

# Check Ingresses and their assigned IPs
kubectl get ingress -A
```

---

## Destroying the Infrastructure

> ⚠️ This will permanently delete ALL resources including the cluster and all data.

```bash
terraform destroy
```

Confirm with `yes` when prompted.

---

## Customisation

All values can be overridden in `terraform.tfvars`:

| Variable | Default | Description |
|---|---|---|
| `project_id` | `cu-online-project` | GCP Project ID |
| `region` | `us-central1` | GCP Region |
| `node_machine_type` | `e2-standard-2` | Node VM type |
| `node_min_count` | `2` | Min nodes per zone |
| `node_max_count` | `3` | Max nodes per zone |
| `argocd_chart_version` | `6.7.14` | ArgoCD Helm version |
| `app_replicas` | `2` | nginx replica count |

---

## Security Notes

- ✅ No credentials are hardcoded — uses Application Default Credentials
- ✅ Dedicated node SA with least-privilege IAM roles
- ✅ SSH access restricted to Google IAP IP range only
- ✅ Workload Identity enabled (no key files needed for pods)
- ✅ Shielded nodes with Secure Boot enabled
- ✅ Private Google Access enabled on subnet
- ✅ Cloud NAT for private node outbound internet access
- ⚠️ Set `deletion_protection = true` in `modules/gke/main.tf` once stable
- ⚠️ Add TLS certificate to Ingress resources for production HTTPS

---

## Module Reference

### `modules/network`
Creates the VPC, subnet, Cloud Router, Cloud NAT, and firewall rules.

### `modules/gke`
Creates the GKE regional cluster, dedicated node pool, node service account, and IAM bindings.

### `modules/app`
Deploys the nginx application, exposes it via a Kubernetes Ingress triggering a GCP HTTP(S) Load Balancer.

### `modules/argocd`
Installs ArgoCD via Helm, exposes it via a Kubernetes Ingress triggering a GCP HTTP(S) Load Balancer.
