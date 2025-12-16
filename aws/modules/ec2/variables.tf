variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ami" {
  type = string
}

variable "key_name" {
  type = string
}

variable "public_subnet_id" {
  description = "Bastion용 Public Subnet ID"
  type        = string
}

variable "private_subnet_id" {
  description = "Mgmt용 Private Subnet ID"
  type        = string
}

variable "bastion_instance_type" {
  description = "Bastion 인스턴스 타입"
  type        = string
}

variable "mgmt_instance_type" {
  description = "Mgmt 인스턴스 타입"
  type        = string
}

variable "mgmt_iam_instance_profile" {
  description = "IAM instance profile name for mgmt server"
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region for EKS kubeconfig"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for kubeconfig setup"
  type        = string
}

variable "nat_gateway_ids" {
  description = "NAT Gateway IDs - EC2 생성 전 NAT Gateway 준비 보장용 (암묵적 의존성)"
  type        = map(string)
  default     = {}
}