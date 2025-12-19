# ============================================================================
# GKE Module - main.tf
# ============================================================================
# GKE Standard Cluster 및 Workload Identity 설정
# ============================================================================

# ============================================================================
# GKE Standard Cluster
# ============================================================================
data "google_service_account" "gke_cluster_sa" {
  account_id = "gke-cluster-sa"
  project    = var.project_id
}

resource "google_container_cluster" "standard" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Standard 모드 (Autopilot 비활성화)
  # 초기 노드 풀 삭제 (별도 노드 풀 사용)
  remove_default_node_pool = true
  initial_node_count       = 1

  # 초기 노드 설정 (default SA 대신 커스텀 SA 사용)
  node_config {
    service_account = data.google_service_account.gke_cluster_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # 네트워크 설정
  network    = var.network_id
  subnetwork = var.subnetwork_id

  # IP 할당 설정
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private Cluster 설정
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

  # Cluster Autoscaling 설정 (노드 자동 프로비저닝)
  cluster_autoscaling {
    enabled = var.cluster_autoscaling_enabled

    dynamic "resource_limits" {
      for_each = var.cluster_autoscaling_enabled ? [1] : []
      content {
        resource_type = "cpu"
        minimum       = var.autoscaling_cpu_min
        maximum       = var.autoscaling_cpu_max
      }
    }

    dynamic "resource_limits" {
      for_each = var.cluster_autoscaling_enabled ? [1] : []
      content {
        resource_type = "memory"
        minimum       = var.autoscaling_memory_min
        maximum       = var.autoscaling_memory_max
      }
    }

    auto_provisioning_defaults {
      service_account = data.google_service_account.gke_cluster_sa.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}

# ============================================================================
# GKE Node Pool
# ============================================================================
resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.standard.name
  project    = var.project_id

  # 노드 수 설정
  initial_node_count = var.node_count

  # Autoscaling 설정
  autoscaling {
    min_node_count = var.node_min_count
    max_node_count = var.node_max_count
  }

  # 노드 관리 설정
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # 노드 설정
  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size
    disk_type    = var.node_disk_type

    # 서비스 계정
    service_account = data.google_service_account.gke_cluster_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity 활성화
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # 라벨
    labels = {
      environment = "dr"
      project     = var.project_name
      node-pool   = "primary"
    }

    # 태그 (방화벽용)
    tags = ["gke-node", "${var.cluster_name}-node"]

    # Shielded Instance 설정 (보안)
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # 업그레이드 설정
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
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
