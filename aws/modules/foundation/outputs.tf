# ============================================================================
# Foundation Module - outputs.tf
# ============================================================================
# Compute, Bootstrap 레이어에서 dependency로 참조
# ============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR 블록"
  value       = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public Subnet ID 리스트"
  value       = module.network.public_subnet_id
}

output "private_eks_subnet_ids" {
  description = "Private EKS Subnet ID 리스트"
  value       = module.network.private_eks_subnet_id
}

output "private_mgmt_subnet_ids" {
  description = "Private Management Subnet ID 리스트"
  value       = module.network.private_mgmt_subnet_id
}

output "private_db_subnet_ids" {
  description = "Private DB Subnet ID 리스트"
  value       = module.network.private_db_subnet_id
}

output "nat_gateway_ids" {
  description = "NAT Gateway ID 리스트"
  value       = module.network.nat_gateway_ids
}

output "project_name" {
  description = "프로젝트 이름"
  value       = var.project_name
}

output "region" {
  description = "AWS 리전"
  value       = var.region
}
