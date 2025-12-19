# ============================================================================
# GKE Module - outputs.tf
# ============================================================================

output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.autopilot.id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.autopilot.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.autopilot.location
}

output "cluster_self_link" {
  description = "GKE cluster self link"
  value       = google_container_cluster.autopilot.self_link
}

# Workload Identity Pool
output "workload_identity_pool" {
  description = "Workload Identity Pool"
  value       = "${var.project_id}.svc.id.goog"
}

# External Secrets Service Account
output "external_secrets_sa_email" {
  description = "External Secrets Service Account email"
  value       = google_service_account.external_secrets.email
}

output "external_secrets_sa_name" {
  description = "External Secrets Service Account name"
  value       = google_service_account.external_secrets.name
}
