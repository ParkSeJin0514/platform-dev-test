# ============================================================================
# Foundation Module - main.tf
# ============================================================================
# VPC, Subnet, NAT Gateway, Route Table 등 네트워크 인프라 생성
# ============================================================================

module "network" {
  source = "../network"

  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  project_name = var.project_name
}
