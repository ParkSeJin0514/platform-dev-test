# ============================================================================
# GCP Network Module - outputs.tf
# ============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "VPC name"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "VPC self link"
  value       = google_compute_network.vpc.self_link
}

output "gke_subnet_id" {
  description = "GKE subnet ID"
  value       = google_compute_subnetwork.gke.id
}

output "gke_subnet_name" {
  description = "GKE subnet name"
  value       = google_compute_subnetwork.gke.name
}

output "gke_subnet_self_link" {
  description = "GKE subnet self link"
  value       = google_compute_subnetwork.gke.self_link
}

output "gke_subnet_cidr" {
  description = "GKE subnet CIDR"
  value       = google_compute_subnetwork.gke.ip_cidr_range
}

output "pods_secondary_range_name" {
  description = "Pods secondary IP range name"
  value       = "pods"
}

output "services_secondary_range_name" {
  description = "Services secondary IP range name"
  value       = "services"
}

output "router_name" {
  description = "Cloud Router name"
  value       = google_compute_router.router.name
}

output "nat_name" {
  description = "Cloud NAT name"
  value       = google_compute_router_nat.nat.name
}
