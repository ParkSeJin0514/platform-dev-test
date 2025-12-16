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

# ============================================================================
# VM 정보
# ============================================================================
output "bastion_name" {
  description = "Bastion instance name"
  value       = module.vm.bastion_name
}

output "bastion_public_ip" {
  description = "Bastion public IP address"
  value       = module.vm.bastion_public_ip
}

output "bastion_private_ip" {
  description = "Bastion private IP address"
  value       = module.vm.bastion_private_ip
}

output "mgmt_name" {
  description = "Management server instance name"
  value       = module.vm.mgmt_name
}

output "mgmt_private_ip" {
  description = "Management server private IP address"
  value       = module.vm.mgmt_private_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to Bastion"
  value       = module.vm.bastion_ssh_command
}

output "mgmt_ssh_command" {
  description = "SSH command to connect to Management server via Bastion"
  value       = module.vm.mgmt_ssh_command
}

# ============================================================================
# Cloud SQL 정보
# ============================================================================
output "cloudsql_instance_name" {
  description = "Cloud SQL instance name"
  value       = module.cloudsql.instance_name
}

output "cloudsql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.cloudsql.private_ip_address
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.cloudsql.instance_connection_name
}

output "db_credentials_secret_id" {
  description = "Secret Manager secret ID for DB credentials"
  value       = module.cloudsql.db_credentials_secret_id
}
