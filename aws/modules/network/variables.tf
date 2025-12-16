variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "az_count" {
  type        = number
  description = "사용할 가용영역 개수 (1~4)"
  default     = 2
}

variable "project_name" {
  type        = string
  description = "Project Name"
}