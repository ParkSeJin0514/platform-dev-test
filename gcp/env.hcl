# ============================================================================
# Environment Configuration (env.hcl) - GCP
# ============================================================================
# GCP DR 환경을 위한 설정
# AWS Primary 환경의 재해복구(DR)용
# ============================================================================

locals {
  # =========================================================================
  # 기본 설정
  # =========================================================================
  project_id   = "kdt2-final-project-t1"
  project_name = "petclinic-dr"
  region       = "asia-northeast3"  # 서울

  # =========================================================================
  # GCS Backend 설정
  # =========================================================================
  tfstate_bucket = "kdt2-final-project-t1-tfstate"

  # =========================================================================
  # Network 설정 (Foundation)
  # =========================================================================
  # AWS VPC CIDR (10.0.0.0/16)와 다르게 설정
  # 추후 VPN 연결 시 충돌 방지
  vpc_cidr = "10.1.0.0/16"

  # =========================================================================
  # GKE Autopilot 설정 (Compute)
  # =========================================================================
  gke_cluster_name    = "petclinic-dr-gke"
  gke_release_channel = "REGULAR"  # RAPID, REGULAR, STABLE 중 선택

  # Private Cluster 설정
  gke_enable_private_nodes    = true
  gke_enable_private_endpoint = false  # kubectl 접근 허용
  gke_master_ipv4_cidr        = "172.16.0.0/28"

  # Master Authorized Networks (GitHub Actions 등에서 접근)
  gke_master_authorized_cidr = "0.0.0.0/0"

  # =========================================================================
  # ArgoCD 설정 (Bootstrap)
  # =========================================================================
  argocd_chart_version   = "5.51.6"
  argocd_namespace       = "argocd"

  # GitOps 저장소 (기존 platform-gitops 사용)
  gitops_repo_url        = "https://github.com/ParkSeJin0514/platform-gitops.git"
  gitops_target_revision = "main"
  gitops_path            = "gcp/apps"  # GCP용 apps 경로

  # =========================================================================
  # Workload Identity 설정
  # =========================================================================
  # External Secrets Operator용 GCP Service Account
  external_secrets_sa_name = "petclinic-dr-external-secrets"

  # =========================================================================
  # AWS RDS 연결 정보 (DR 시 사용)
  # =========================================================================
  # 실제 값은 GCP Secret Manager에 저장
  aws_rds_endpoint = ""  # DR 전환 시 설정
  aws_rds_port     = 3306
  aws_region       = "ap-northeast-2"
}
