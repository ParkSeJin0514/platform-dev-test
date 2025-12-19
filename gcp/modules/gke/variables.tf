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
# Node Pool 설정
# ============================================================================

variable "node_count" {
  description = "Initial number of nodes per zone"
  type        = number
  default     = 1
}

variable "node_min_count" {
  description = "Minimum number of nodes per zone for autoscaling"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of nodes per zone for autoscaling"
  type        = number
  default     = 3
}

variable "node_machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-medium"
}

variable "node_disk_size" {
  description = "Disk size in GB for nodes"
  type        = number
  default     = 50
}

variable "node_disk_type" {
  description = "Disk type for nodes (pd-standard, pd-ssd, pd-balanced)"
  type        = string
  default     = "pd-balanced"
}

# ============================================================================
# Cluster Autoscaling (Node Auto-Provisioning)
# ============================================================================

variable "cluster_autoscaling_enabled" {
  description = "Enable cluster autoscaling (node auto-provisioning)"
  type        = bool
  default     = false
}

variable "autoscaling_cpu_min" {
  description = "Minimum CPU cores for cluster autoscaling"
  type        = number
  default     = 1
}

variable "autoscaling_cpu_max" {
  description = "Maximum CPU cores for cluster autoscaling"
  type        = number
  default     = 10
}

variable "autoscaling_memory_min" {
  description = "Minimum memory (GB) for cluster autoscaling"
  type        = number
  default     = 1
}

variable "autoscaling_memory_max" {
  description = "Maximum memory (GB) for cluster autoscaling"
  type        = number
  default     = 32
}
