# ============================================================================
# GKE Module - main.tf
# ============================================================================
# GKE Standard Cluster + Node Pool + Workload Identity 설정
# ============================================================================

# ============================================================================
# Node Service Account (injung 방식)
# ============================================================================
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node SA for ${var.cluster_name}"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metadata" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ============================================================================
# GKE Standard Cluster
# ============================================================================
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # 네트워크 설정
  network    = var.network_id
  subnetwork = var.subnetwork_id

  # Standard 모드: default node pool 제거 후 별도 node pool 생성
  remove_default_node_pool = true
  initial_node_count       = 1

  # 클러스터 수준 node_config (default pool 생성 시 사용)
  node_config {
    service_account = google_service_account.gke_nodes.email
  }

  # IP 할당 설정 (VPC-native)
  dynamic "ip_allocation_policy" {
    for_each = (var.pods_range_name != null && var.services_range_name != null) ? [1] : []
    content {
      cluster_secondary_range_name  = var.pods_range_name
      services_secondary_range_name = var.services_range_name
    }
  }

  # Public Cluster 설정
  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
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

  # 로깅/모니터링
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

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
}

# ============================================================================
# Node Pool (injung 방식)
# ============================================================================
resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-np"
  location = google_container_cluster.this.location
  cluster  = google_container_cluster.this.name
  project  = var.project_id

  # 리전 클러스터(보통 3존 분산)에서 총 3노드 원하면 node_count=1
  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      environment = "dr"
      project     = var.project_name
    }
  }

  depends_on = [
    google_container_cluster.this,
    google_project_iam_member.gke_nodes_logging,
    google_project_iam_member.gke_nodes_monitoring,
    google_project_iam_member.gke_nodes_metadata,
    google_project_iam_member.gke_nodes_artifact_reader,
  ]
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
