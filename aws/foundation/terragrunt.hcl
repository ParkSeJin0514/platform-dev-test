# ============================================================================
# Foundation Layer (VPC, Subnet, NAT Gateway)
# ============================================================================
# 의존성: 없음 (첫 번째 레이어)
# 출력값: vpc_id, subnet_ids → Compute에서 사용
# ============================================================================

include "root" {
  path = find_in_parent_folders()
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//foundation"
}

inputs = {
  project_name = local.env.locals.project_name
  region       = local.env.locals.region
  vpc_cidr     = local.env.locals.vpc_cidr
  az_count     = local.env.locals.az_count
}
