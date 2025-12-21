# ============================================================================
# GKE Module - variables.tf
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

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "subnetwork_id" {
  description = "Subnetwork ID"
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

variable "master_authorized_cidr" {
  description = "CIDR block authorized to access the master"
  type        = string
  default     = "0.0.0.0/0"
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "external_secrets_sa_name" {
  description = "Service account name for External Secrets Operator"
  type        = string
  default     = "petclinic-dr-external-secrets"
}

# ============================================================================
# Node Pool 설정 (Standard 모드용)
# ============================================================================
variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "node_count" {
  description = "Initial node count per zone"
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "Minimum node count for autoscaling per zone"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum node count for autoscaling per zone"
  type        = number
  default     = 2
}
