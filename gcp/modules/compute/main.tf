# ============================================================================
# Compute Module - main.tf (GCP)
# ============================================================================
# GKE Autopilot + Workload Identity (DB 없음 - AWS RDS 사용)
# ============================================================================

# ============================================================================
# GKE 모듈 호출
# ============================================================================
module "gke" {
  source = "../gke"

  project_id   = var.project_id
  project_name = var.project_name
  region       = var.region

  cluster_name  = var.gke_cluster_name
  network_id    = var.vpc_id
  subnetwork_id = var.gke_subnet_id

  pods_range_name     = var.pods_range_name
  services_range_name = var.services_range_name

  enable_private_nodes    = var.gke_enable_private_nodes
  enable_private_endpoint = var.gke_enable_private_endpoint
  master_ipv4_cidr        = var.gke_master_ipv4_cidr
  master_authorized_cidr  = var.gke_master_authorized_cidr
  release_channel         = var.gke_release_channel

  external_secrets_sa_name = var.external_secrets_sa_name
}

# ============================================================================
# GCP Secret Manager에 DR 설정 저장 (선택적)
# ============================================================================
# AWS RDS 연결 정보는 DR 전환 시 Secret Manager에 저장
# External Secrets Operator가 이를 Kubernetes Secret으로 동기화

resource "google_secret_manager_secret" "dr_config" {
  secret_id = "${var.project_name}-dr-config"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = "dr"
    project     = var.project_name
    managed-by  = "terragrunt"
  }
}

# Secret 초기 버전 (빈 값, DR 전환 시 업데이트)
resource "google_secret_manager_secret_version" "dr_config" {
  secret      = google_secret_manager_secret.dr_config.id
  secret_data = jsonencode({
    SPRING_DATASOURCE_URL      = ""
    SPRING_DATASOURCE_USERNAME = ""
    SPRING_DATASOURCE_PASSWORD = ""
    AWS_RDS_ENDPOINT           = ""
    AWS_RDS_PORT               = "3306"
    DR_MODE                    = "standby"
  })
}

# Secret 접근 권한 (External Secrets SA)
resource "google_secret_manager_secret_iam_member" "dr_config_accessor" {
  secret_id = google_secret_manager_secret.dr_config.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.gke.external_secrets_sa_email}"
}
