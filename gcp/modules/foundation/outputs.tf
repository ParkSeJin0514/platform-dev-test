# ============================================================================
# Foundation Module - outputs.tf (GCP)
# ============================================================================

# Project 정보
output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "region" {
  description = "GCP region"
  value       = var.region
}

# VPC 정보
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "vpc_name" {
  description = "VPC name"
  value       = module.network.vpc_name
}

output "vpc_self_link" {
  description = "VPC self link"
  value       = module.network.vpc_self_link
}

# Subnet 정보
output "gke_subnet_id" {
  description = "GKE subnet ID"
  value       = module.network.gke_subnet_id
}

output "gke_subnet_name" {
  description = "GKE subnet name"
  value       = module.network.gke_subnet_name
}

output "gke_subnet_self_link" {
  description = "GKE subnet self link"
  value       = module.network.gke_subnet_self_link
}

output "gke_subnet_cidr" {
  description = "GKE subnet CIDR"
  value       = module.network.gke_subnet_cidr
}

# Secondary Range 정보 (GKE Pod/Service)
output "pods_secondary_range_name" {
  description = "Pods secondary IP range name"
  value       = module.network.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "Services secondary IP range name"
  value       = module.network.services_secondary_range_name
}

# Cloud NAT 정보
output "router_name" {
  description = "Cloud Router name"
  value       = module.network.router_name
}

output "nat_name" {
  description = "Cloud NAT name"
  value       = module.network.nat_name
}
