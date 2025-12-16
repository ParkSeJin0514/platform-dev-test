# ============================================================================
# Compute Module - main.tf (GCP)
# ============================================================================
# GKE Autopilot + Workload Identity + Cloud SQL
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

# ============================================================================
# VM 모듈 호출 (Bastion, Management)
# ============================================================================
module "vm" {
  source = "../vm"

  project_id   = var.project_id
  project_name = var.project_name
  region       = var.region
  zone         = var.zone

  network_id        = var.vpc_id
  public_subnet_id  = var.public_subnet_id
  private_subnet_id = var.private_subnet_id

  bastion_machine_type = var.bastion_machine_type
  mgmt_machine_type    = var.mgmt_machine_type
  ssh_public_key       = var.ssh_public_key

  service_account_email = data.google_service_account.gke_cluster_sa.email
}

data "google_service_account" "gke_cluster_sa" {
  account_id = "gke-cluster-sa"
  project    = var.project_id
}

# ============================================================================
# Cloud SQL 모듈 호출
# ============================================================================
module "cloudsql" {
  source = "../cloudsql"

  project_id   = var.project_id
  project_name = var.project_name
  region       = var.region
  network_id   = var.vpc_id

  database_name     = var.database_name
  database_user     = var.database_user
  database_password = var.database_password

  tier              = var.cloudsql_tier
  deletion_protection = false

  external_secrets_sa_email = module.gke.external_secrets_sa_email
}
