# ============================================================================
# GCP Network Module - main.tf
# ============================================================================
# VPC, Subnet, Cloud NAT, Cloud Router, Firewall 생성
# ============================================================================

# ============================================================================
# VPC
# ============================================================================
resource "google_compute_network" "vpc" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC for ${var.project_name} DR environment"
}

# ============================================================================
# GKE Subnet (Pod, Service Secondary Range 포함)
# ============================================================================
resource "google_compute_subnetwork" "gke" {
  name          = "${var.project_name}-gke-subnet"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 0)  # 10.1.0.0/24
  region        = var.region
  network       = google_compute_network.vpc.id
  description   = "GKE subnet for ${var.project_name}"

  # GKE Pod/Service용 Secondary IP Range
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = cidrsubnet(var.vpc_cidr, 4, 1)  # 10.1.16.0/20
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 32)  # 10.1.32.0/24
  }

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ============================================================================
# Cloud Router (Cloud NAT 필수)
# ============================================================================
resource "google_compute_router" "router" {
  name        = "${var.project_name}-router"
  region      = var.region
  network     = google_compute_network.vpc.id
  description = "Cloud Router for ${var.project_name}"

  bgp {
    asn = 64514
  }
}

# ============================================================================
# Cloud NAT (Private GKE 노드의 인터넷 접근)
# ============================================================================
resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # NAT 타임아웃 설정
  min_ports_per_vm                    = 64
  udp_idle_timeout_sec                = 30
  icmp_idle_timeout_sec               = 30
  tcp_established_idle_timeout_sec    = 1200
  tcp_transitory_idle_timeout_sec     = 30
  tcp_time_wait_timeout_sec           = 120
}

# ============================================================================
# Firewall Rules
# ============================================================================

# Internal 통신 허용
resource "google_compute_firewall" "allow_internal" {
  name        = "${var.project_name}-allow-internal"
  network     = google_compute_network.vpc.id
  description = "Allow internal communication within VPC"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr]
}

# SSH 접근 허용 (IAP 통해)
resource "google_compute_firewall" "allow_iap_ssh" {
  name        = "${var.project_name}-allow-iap-ssh"
  network     = google_compute_network.vpc.id
  description = "Allow SSH via IAP"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP IP 범위
  source_ranges = ["35.235.240.0/20"]
}

# Health Check 허용 (GKE Load Balancer)
resource "google_compute_firewall" "allow_health_check" {
  name        = "${var.project_name}-allow-health-check"
  network     = google_compute_network.vpc.id
  description = "Allow health checks from GCP load balancers"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  # GCP Health Check IP 범위
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}
