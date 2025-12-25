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

# ============================================================================
# ArgoCD 접속 정보
# ============================================================================
output "argocd_password_command" {
  description = "Command to get ArgoCD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}

# ============================================================================
# mgmt 서버 사용 가이드
# ============================================================================
output "kubectl_setup_command" {
  description = "Command to configure kubectl for GKE (run on mgmt server)"
  value       = "configure-kubectl"
}

output "mgmt_quickstart" {
  description = "Quick start commands for mgmt server"
  sensitive   = true
  value       = <<-EOT
    # 1. kubectl 설정 (OS Login 사용자는 필수)
    configure-kubectl

    # 2. ArgoCD 비밀번호 확인
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo

    # 3. 클러스터 모니터링 Grafana 비밀번호 (kube-prometheus-stack)
    # Username: admin, Password: ${var.grafana_admin_password}
  EOT
}

# ============================================================================
# kube-prometheus-stack 정보
# ============================================================================
output "prometheus_stack_namespace" {
  description = "kube-prometheus-stack namespace"
  value       = "petclinic"
}

output "grafana_cluster_password" {
  description = "Grafana admin password for kube-prometheus-stack"
  value       = var.grafana_admin_password
  sensitive   = true
}
