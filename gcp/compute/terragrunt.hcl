# ============================================================================
# Compute Layer (GCP) - GKE Autopilot, Workload Identity
# ============================================================================
# 의존성: Foundation (VPC, Subnet)
# 출력값: cluster_endpoint, Workload Identity → Bootstrap에서 사용
# ============================================================================

include "root" {
  path = find_in_parent_folders()
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//compute"
}

# ============================================================================
# Foundation 의존성 선언
# ============================================================================
dependency "foundation" {
  config_path = "../foundation"

  # terragrunt plan 시 Foundation이 없어도 동작하도록 Mock 값 설정
  mock_outputs = {
    project_id                    = "mock-project"
    project_name                  = "mock-name"
    region                        = "asia-northeast3"
    vpc_id                        = "projects/mock/global/networks/mock-vpc"
    vpc_name                      = "mock-vpc"
    gke_subnet_id                 = "projects/mock/regions/asia-northeast3/subnetworks/mock-subnet"
    gke_subnet_name               = "mock-subnet"
    pods_secondary_range_name     = "pods"
    services_secondary_range_name = "services"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

# ============================================================================
# 입력 변수
# ============================================================================
inputs = {
  # Foundation에서 가져온 값 (의존성 자동 해결)
  project_id          = dependency.foundation.outputs.project_id
  project_name        = dependency.foundation.outputs.project_name
  region              = dependency.foundation.outputs.region
  vpc_id              = dependency.foundation.outputs.vpc_id
  gke_subnet_id       = dependency.foundation.outputs.gke_subnet_id
  pods_range_name     = dependency.foundation.outputs.pods_secondary_range_name
  services_range_name = dependency.foundation.outputs.services_secondary_range_name

  # GKE 설정
  gke_cluster_name            = local.env.locals.gke_cluster_name
  gke_release_channel         = local.env.locals.gke_release_channel
  gke_enable_private_nodes    = local.env.locals.gke_enable_private_nodes
  gke_enable_private_endpoint = local.env.locals.gke_enable_private_endpoint
  gke_master_ipv4_cidr        = local.env.locals.gke_master_ipv4_cidr
  gke_master_authorized_cidr  = local.env.locals.gke_master_authorized_cidr

  # Workload Identity 설정
  external_secrets_sa_name = local.env.locals.external_secrets_sa_name
}
