# ============================================================================
# Bootstrap Layer (GCP) - ArgoCD
# ============================================================================
# 의존성: Foundation, Compute
# ArgoCD 설치 및 Root Application 배포
# ============================================================================

include "root" {
  path = find_in_parent_folders()
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//bootstrap"
}

# ============================================================================
# 의존성 선언
# ============================================================================
dependency "foundation" {
  config_path = "../foundation"

  mock_outputs = {
    project_id   = "mock-project"
    project_name = "mock-name"
    region       = "asia-northeast3"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

dependency "compute" {
  config_path = "../compute"

  mock_outputs = {
    gke_cluster_name           = "mock-cluster"
    gke_cluster_endpoint       = "https://mock.gke.googleapis.com"
    gke_cluster_ca_certificate = "bW9jay1jZXJ0"
    gke_cluster_location       = "asia-northeast3"
    external_secrets_sa_email  = "mock@mock-project.iam.gserviceaccount.com"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

# ============================================================================
# Kubernetes/Helm Provider 추가 생성
# ============================================================================
generate "k8s_provider" {
  path      = "_k8s_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    data "google_client_config" "default" {}

    provider "kubernetes" {
      host                   = "https://${dependency.compute.outputs.gke_cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.compute.outputs.gke_cluster_ca_certificate}")
      token                  = data.google_client_config.default.access_token
    }

    provider "helm" {
      kubernetes {
        host                   = "https://${dependency.compute.outputs.gke_cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.compute.outputs.gke_cluster_ca_certificate}")
        token                  = data.google_client_config.default.access_token
      }
    }

    provider "kubectl" {
      host                   = "https://${dependency.compute.outputs.gke_cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.compute.outputs.gke_cluster_ca_certificate}")
      token                  = data.google_client_config.default.access_token
      load_config_file       = false
    }
  EOF
}

# ============================================================================
# 입력 변수
# ============================================================================
inputs = {
  # Foundation에서 가져온 값
  project_id   = dependency.foundation.outputs.project_id
  project_name = dependency.foundation.outputs.project_name
  region       = dependency.foundation.outputs.region

  # Compute에서 가져온 값
  cluster_name           = dependency.compute.outputs.gke_cluster_name
  cluster_endpoint       = dependency.compute.outputs.gke_cluster_endpoint
  cluster_ca_certificate = dependency.compute.outputs.gke_cluster_ca_certificate

  # ArgoCD 설정
  argocd_chart_version   = local.env.locals.argocd_chart_version
  argocd_namespace       = local.env.locals.argocd_namespace
  gitops_repo_url        = local.env.locals.gitops_repo_url
  gitops_target_revision = local.env.locals.gitops_target_revision
  gitops_path            = local.env.locals.gitops_path
}
