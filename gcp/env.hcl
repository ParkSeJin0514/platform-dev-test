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
  vpc_cidr = "172.16.0.0/16"

  # =========================================================================
  # GKE Standard 설정 (Compute)
  # =========================================================================
  gke_cluster_name    = "petclinic-dr-gke"
  gke_mode            = "standard"  # standard or autopilot
  gke_release_channel = "REGULAR"   # RAPID, REGULAR, STABLE 중 선택

  # Master Authorized Networks (GitHub Actions 등에서 접근)
  gke_master_authorized_cidr = "0.0.0.0/0"

  # =========================================================================
  # GKE Node Pool 설정 (Standard 모드용)
  # =========================================================================
  node_machine_type = "e2-standard-4"
  node_count        = 1   # 초기 노드 수 (리전 클러스터: 존당 노드 수)
  min_node_count    = 1   # 오토스케일링 최소
  max_node_count    = 2   # 오토스케일링 최대

  # =========================================================================
  # ArgoCD 설정 (Bootstrap)
  # =========================================================================
  argocd_chart_version   = "5.51.6"
  argocd_namespace       = "argocd"

  # GitOps 저장소
  gitops_repo_url        = "https://github.com/ParkSeJin0514/platform-gitops-last.git"
  gitops_target_revision = "main"
  gitops_path            = "gcp/apps"  # GCP용 apps 경로

  # =========================================================================
  # Workload Identity 설정
  # =========================================================================
  # External Secrets Operator용 GCP Service Account
  external_secrets_sa_name = "petclinic-dr-external-secrets"

  # =========================================================================
  # VM 설정 (Bastion, Management)
  # =========================================================================
  zone                 = "asia-northeast3-a"
  bastion_machine_type = "e2-micro"
  mgmt_machine_type    = "e2-small"
  ssh_public_key       = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCgvvKgZDr2xb8BdMmvdTxC6EF0nuY17rotsSWGyVoHWQDfqrNPtEDm6qLzuYuVUyVp3/VRR3OHz5lymRwdhUkK4t7V+7wvZdbhCWH85DYPx96cQtgPLI96goV4OkWDoMS24WutvD3ochawdbQvpDQJTz+vAvbHbM4yccNkPbukZoh2xDmiNO4J7QDFA16OAv3PkY1mddDR/xHraz0GJC2XPjP/K7XTLA2usQHmRHyerTL4nBz9vWozpz78gRqbOz6Q+P4jC3JcRvyQfoRdx/dbU08pmsNMO9JLAdnZyKktKkJzirK/jZZSf8rSs+bVEkb9FnNJADg8O4svLhcodtBMKQ5LxSC3+35Gf5N5CNsKeQmCUmOmVO0THM9NernJLEWh04LW6c9SYwfBpqSNgDGfTPYXCIYBqwIF2AQlrPZ9j5pifE/WV45GWKog4CyEagDC0xkcUzo/mAw+NB/jS1wr4Jg+tJix9GLyF4ohdMVmeIcNKxR6ReVmfwsGbivtNpjUTkH/EzKlooOHe0LSq02/H9L9857Z/u0PA2kpiGw/+lPPM1IY6mnh3frUkaMh3zVUrGAmFv0MXqaC4UkqDVnXEXJho8USLNALlSz5g0Cq0m6h5tEsEUc5x+TN3u/PjmglrXYQKG5YViz40f4jyVZk7Og7fefEDvL2Xmq3Cdgh0Q== ubuntu@code-server"

  # =========================================================================
  # Cloud SQL 설정
  # =========================================================================
  database_name   = "petclinic"
  database_user   = "petclinic"
  cloudsql_tier   = "db-f1-micro"  # 최소 비용 (db-g1-small, db-n1-standard-1 등 선택 가능)
}
