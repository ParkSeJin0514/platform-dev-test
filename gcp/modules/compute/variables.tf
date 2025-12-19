# ============================================================================
# Compute Module - variables.tf (GCP)
# ============================================================================

# ============================================================================
# 기본 설정
# ============================================================================
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

# ============================================================================
# Foundation에서 전달받는 값
# ============================================================================
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "gke_subnet_id" {
  description = "GKE subnet ID"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  type        = string
  default     = "pods"
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services"
  type        = string
  default     = "services"
}

# ============================================================================
# GKE Autopilot 설정
# ============================================================================
variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "gke_release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "gke_master_authorized_cidr" {
  description = "CIDR block authorized to access the master"
  type        = string
  default     = "0.0.0.0/0"
}

# ============================================================================
# Workload Identity 설정
# ============================================================================
variable "external_secrets_sa_name" {
  description = "Service account name for External Secrets Operator"
  type        = string
  default     = "petclinic-dr-external-secrets"
}

# ============================================================================
# VM 설정
# ============================================================================
variable "zone" {
  description = "GCP zone for VMs"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for Bastion"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for Management server"
  type        = string
}

variable "bastion_machine_type" {
  description = "Machine type for Bastion"
  type        = string
  default     = "e2-micro"
}

variable "mgmt_machine_type" {
  description = "Machine type for Management server"
  type        = string
  default     = "e2-small"
}

variable "ssh_public_key" {
  description = "SSH public key for VMs"
  type        = string
}

# ============================================================================
# Cloud SQL 설정
# ============================================================================
variable "database_name" {
  description = "Database name"
  type        = string
  default     = "petclinic"
}

variable "database_user" {
  description = "Database user"
  type        = string
  default     = "petclinic"
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "cloudsql_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}
