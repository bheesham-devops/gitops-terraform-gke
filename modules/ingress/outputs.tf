# =============================================================================
# modules/ingress/outputs.tf
# =============================================================================

output "static_ip_address" {
  description = "The reserved global static IP address. Add DNS A records pointing here."
  value       = google_compute_global_address.ingress_ip.address
}

output "static_ip_name" {
  description = "GCP resource name of the static IP (used internally by the Gateway)."
  value       = google_compute_global_address.ingress_ip.name
}

output "gateway_name" {
  description = "Name of the shared GKE Gateway resource."
  value       = var.gateway_name
}

output "gateway_namespace" {
  description = "Namespace where the Gateway is deployed."
  value       = var.gateway_namespace
}

output "cert_map_name" {
  description = "Name of the Certificate Manager certificate map."
  value       = google_certificate_manager_certificate_map.cert_map.name
}

# ---------------------------------------------------------------------------
# DNS CNAME Challenge
# Add this CNAME record in Namecheap to activate the wildcard certificate.
# ---------------------------------------------------------------------------
output "dns_cname_record_name" {
  description = "CNAME record NAME to add in Namecheap DNS (the _acme-challenge subdomain)."
  value       = google_certificate_manager_dns_authorization.root.dns_resource_record[0].name
}

output "dns_cname_record_value" {
  description = "CNAME record VALUE to add in Namecheap DNS (points to Google's validation server)."
  value       = google_certificate_manager_dns_authorization.root.dns_resource_record[0].data
}

output "dns_cname_instructions" {
  description = "Full step-by-step DNS instructions for Namecheap to activate the SSL certificate."
  value       = <<-EOT

    ============================================================
     NAMECHEAP DNS SETUP — Required for SSL Certificate
    ============================================================

    1. Log in to Namecheap → Domain List → nayaratech.online → Manage → Advanced DNS

    2. Add these DNS records:

       -- SSL Certificate Validation (CNAME) --
       Type  : CNAME Record
       Host  : ${trimprefix(google_certificate_manager_dns_authorization.root.dns_resource_record[0].name, ".${var.domain}")}
       Value : ${google_certificate_manager_dns_authorization.root.dns_resource_record[0].data}
       TTL   : Automatic

       -- Application Routing (A Records) --
       Type  : A Record   Host: argocd       Value: ${google_compute_global_address.ingress_ip.address}
       Type  : A Record   Host: grafana      Value: ${google_compute_global_address.ingress_ip.address}
       Type  : A Record   Host: prometheus   Value: ${google_compute_global_address.ingress_ip.address}
       Type  : A Record   Host: app          Value: ${google_compute_global_address.ingress_ip.address}

    3. Wait ~15 minutes for DNS to propagate.

    4. The SSL certificate will auto-provision once Google validates the CNAME.
       Check status: gcloud certificate-manager certificates describe ${google_certificate_manager_certificate.wildcard.name}

    ============================================================
  EOT
}
