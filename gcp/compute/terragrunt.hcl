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
    public_subnet_id              = "projects/mock/regions/asia-northeast3/subnetworks/mock-public"
    private_subnet_id             = "projects/mock/regions/asia-northeast3/subnetworks/mock-private"
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

  # GKE Autopilot 설정
  gke_cluster_name           = local.env.locals.gke_cluster_name
  gke_release_channel        = local.env.locals.gke_release_channel
  gke_master_authorized_cidr = local.env.locals.gke_master_authorized_cidr

  # Workload Identity 설정
  external_secrets_sa_name = local.env.locals.external_secrets_sa_name

  # VM 설정
  zone              = local.env.locals.zone
  public_subnet_id  = dependency.foundation.outputs.public_subnet_id
  private_subnet_id = dependency.foundation.outputs.private_subnet_id
  bastion_machine_type = local.env.locals.bastion_machine_type
  mgmt_machine_type    = local.env.locals.mgmt_machine_type
  ssh_public_key       = local.env.locals.ssh_public_key

  # Cloud SQL 설정
  database_name     = local.env.locals.database_name
  database_user     = local.env.locals.database_user
  database_password = get_env("TF_VAR_db_password", "petclinic123!")
  cloudsql_tier     = local.env.locals.cloudsql_tier
}
