# ============================================================================
# Compute Module - outputs.tf (GCP)
# ============================================================================

# ============================================================================
# GKE Cluster 정보
# ============================================================================
output "gke_cluster_id" {
  description = "GKE cluster ID"
  value       = module.gke.cluster_id
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "gke_cluster_location" {
  description = "GKE cluster location"
  value       = module.gke.cluster_location
}

# ============================================================================
# Workload Identity 정보
# ============================================================================
output "workload_identity_pool" {
  description = "Workload Identity Pool"
  value       = module.gke.workload_identity_pool
}

output "external_secrets_sa_email" {
  description = "External Secrets Service Account email"
  value       = module.gke.external_secrets_sa_email
}

output "external_secrets_sa_name" {
  description = "External Secrets Service Account name"
  value       = module.gke.external_secrets_sa_name
}

# ============================================================================
# Secret Manager 정보
# ============================================================================
output "dr_config_secret_id" {
  description = "DR config secret ID"
  value       = google_secret_manager_secret.dr_config.secret_id
}
