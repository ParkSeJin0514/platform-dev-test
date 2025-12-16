# ============================================================================
# Foundation Module - variables.tf
# ============================================================================

variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "region" {
  type        = string
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록"
}

variable "az_count" {
  type        = number
  description = "사용할 가용영역 개수"
  default     = 2
}
