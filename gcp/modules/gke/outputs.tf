# ============================================================================
# GKE Module - outputs.tf
# ============================================================================

output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.this.id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.this.location
}

output "cluster_self_link" {
  description = "GKE cluster self link"
  value       = google_container_cluster.this.self_link
}

# Node Pool 정보
output "node_pool_name" {
  description = "GKE node pool name"
  value       = google_container_node_pool.primary.name
}

output "node_sa_email" {
  description = "GKE node service account email"
  value       = google_service_account.gke_nodes.email
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
