# ===================================
# Cluster Configuration
# ===================================
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "control_plane_subnet_ids" {
  description = "List of subnet IDs for the EKS cluster control plane (can include both public and private)"
  type        = list(string)
}

variable "worker_subnet_ids" {
  description = "List of subnet IDs where worker nodes will be placed (usually private subnets)"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# ===================================
# Node Group Configuration
# ===================================
variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
}

variable "instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be either ON_DEMAND or SPOT"
  }
}

variable "disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size >= 20 && var.disk_size <= 1000
    error_message = "disk_size must be between 20 and 1000 GB"
  }
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_size >= 1
    error_message = "desired_size must be at least 1"
  }
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4

  validation {
    condition     = var.max_size >= 1
    error_message = "max_size must be at least 1"
  }
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must be at least 0"
  }
}

variable "max_unavailable_percentage" {
  description = "Maximum percentage of nodes unavailable during update"
  type        = number
  default     = 33

  validation {
    condition     = var.max_unavailable_percentage >= 1 && var.max_unavailable_percentage <= 100
    error_message = "max_unavailable_percentage must be between 1 and 100"
  }
}

# ===================================
# Node Configuration
# ===================================
variable "key_name" {
  description = "EC2 Key Pair name for SSH access to nodes"
  type        = string
  default     = null
}

variable "kubelet_extra_args" {
  description = "Extra arguments to pass to kubelet"
  type        = string
  default     = ""
}

variable "node_labels" {
  description = "Key-value map of Kubernetes labels for nodes"
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "List of Kubernetes taints to apply to nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []

  validation {
    condition = alltrue([
      for taint in var.node_taints : contains(["NoSchedule", "NoExecute", "PreferNoSchedule"], taint.effect)
    ])
    error_message = "taint effect must be one of: NoSchedule, NoExecute, PreferNoSchedule"
  }
}

# ===================================
# Tags
# ===================================
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# ===================================
# Management Instance Security Group
# ===================================
variable "enable_mgmt_sg_rule" {
  description = "Whether to create security group rule for Management Instance"
  type        = bool
  default     = false
}

variable "mgmt_security_group_id" {
  description = "Security Group ID of Management Instance for EKS API access"
  type        = string
  default     = null
}