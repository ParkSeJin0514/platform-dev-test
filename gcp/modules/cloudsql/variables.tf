# ============================================================================
# Cloud SQL Module - variables.tf
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

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "database_version" {
  description = "MySQL version"
  type        = string
  default     = "MYSQL_8_0"
}

variable "tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"  # 최소 비용
}

variable "availability_type" {
  description = "Availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "ZONAL"  # 비용 절감
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false  # 테스트용이므로 false
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = false  # 비용 절감
}

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

variable "external_secrets_sa_email" {
  description = "External Secrets Service Account email"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dr"
}
