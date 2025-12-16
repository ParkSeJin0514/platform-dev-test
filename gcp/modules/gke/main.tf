# ============================================================================
# GKE Module - main.tf
# ============================================================================
# GKE Autopilot Cluster 및 Workload Identity 설정
# ============================================================================

# ============================================================================
# GKE Autopilot Cluster
# ============================================================================
resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot 모드 활성화
  enable_autopilot = true

  # 네트워크 설정
  network    = var.network_id
  subnetwork = var.subnetwork_id

  # IP 할당 설정
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private Cluster 설정 (비용 최적화)
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  # Master Authorized Networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.master_authorized_cidr
      display_name = "all"
    }
  }

  # Release Channel
  release_channel {
    channel = var.release_channel
  }

  # Workload Identity 활성화
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # 클러스터 삭제 보호 비활성화 (DR 테스트 환경)
  deletion_protection = false

  # 라벨
  resource_labels = {
    environment = "dr"
    project     = var.project_name
    managed-by  = "terragrunt"
  }

  # Vertical Pod Autoscaling
  vertical_pod_autoscaling {
    enabled = true
  }

  # Binary Authorization (보안)
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
}

# ============================================================================
# Workload Identity - External Secrets Operator
# ============================================================================

# GCP Service Account for External Secrets
resource "google_service_account" "external_secrets" {
  account_id   = var.external_secrets_sa_name
  display_name = "External Secrets Operator"
  description  = "Service account for External Secrets Operator to access Secret Manager"
  project      = var.project_id
}

# Secret Manager 접근 권한
resource "google_project_iam_member" "external_secrets_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

# Workload Identity 바인딩
resource "google_service_account_iam_binding" "external_secrets_workload_identity" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets-sa]"
  ]
}
