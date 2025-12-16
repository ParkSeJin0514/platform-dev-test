# ============================================================================
# Foundation Module - main.tf (GCP)
# ============================================================================
# Network 모듈을 래핑하여 Layer 1 제공
# ============================================================================

module "network" {
  source = "../network"

  project_id   = var.project_id
  project_name = var.project_name
  region       = var.region
  vpc_cidr     = var.vpc_cidr
}
