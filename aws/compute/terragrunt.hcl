# ============================================================================
# Compute Layer (EKS, RDS, EC2, IRSA)
# ============================================================================
# 의존성: Foundation (VPC, Subnet)
# 출력값: cluster_endpoint, IRSA ARNs → Bootstrap에서 사용
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
# ⭐ 핵심: Foundation 의존성 선언
# ============================================================================
dependency "foundation" {
  config_path = "../foundation"

  # terragrunt plan 시 Foundation이 없어도 동작하도록 Mock 값 설정
  mock_outputs = {
    vpc_id                  = "vpc-mock-12345"
    vpc_cidr                = "10.0.0.0/16"
    public_subnet_ids       = ["subnet-mock-pub-1", "subnet-mock-pub-2"]
    private_eks_subnet_ids  = ["subnet-mock-eks-1", "subnet-mock-eks-2"]
    private_mgmt_subnet_ids = ["subnet-mock-mgmt-1", "subnet-mock-mgmt-2"]
    private_db_subnet_ids   = ["subnet-mock-db-1", "subnet-mock-db-2"]
    nat_gateway_ids         = ["nat-mock-1", "nat-mock-2"]
    project_name            = "mock-project"
    region                  = "ap-northeast-2"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

# ============================================================================
# 입력 변수
# ============================================================================
inputs = {
  # Foundation에서 가져온 값 (의존성 자동 해결)
  vpc_id                  = dependency.foundation.outputs.vpc_id
  vpc_cidr                = dependency.foundation.outputs.vpc_cidr
  public_subnet_ids       = dependency.foundation.outputs.public_subnet_ids
  private_eks_subnet_ids  = dependency.foundation.outputs.private_eks_subnet_ids
  private_mgmt_subnet_ids = dependency.foundation.outputs.private_mgmt_subnet_ids
  private_db_subnet_ids   = dependency.foundation.outputs.private_db_subnet_ids
  project_name            = dependency.foundation.outputs.project_name
  region                  = dependency.foundation.outputs.region

  # EC2 설정
  bastion_instance_type = local.env.locals.bastion_instance_type
  mgmt_instance_type    = local.env.locals.mgmt_instance_type
  key_name              = local.env.locals.key_name
  ubuntu_ami_filters    = local.env.locals.ubuntu_ami_filters

  # EKS 설정
  eks_version                    = local.env.locals.eks_version
  eks_instance_types             = local.env.locals.eks_instance_types
  eks_capacity_type              = local.env.locals.eks_capacity_type
  eks_disk_size                  = local.env.locals.eks_disk_size
  eks_desired_size               = local.env.locals.eks_desired_size
  eks_min_size                   = local.env.locals.eks_min_size
  eks_max_size                   = local.env.locals.eks_max_size
  eks_max_unavailable_percentage = local.env.locals.eks_max_unavailable_percentage
  eks_kubelet_extra_args         = local.env.locals.eks_kubelet_extra_args
  eks_node_labels                = local.env.locals.eks_node_labels
  eks_node_taints                = local.env.locals.eks_node_taints
  eks_cluster_log_types          = local.env.locals.eks_cluster_log_types

  # RDS 설정
  db_engine                 = local.env.locals.db_engine
  db_engine_version         = local.env.locals.db_engine_version
  db_parameter_group_family = local.env.locals.db_parameter_group_family
  db_instance_class         = local.env.locals.db_instance_class
  db_allocated_storage      = local.env.locals.db_allocated_storage
  db_max_allocated_storage  = local.env.locals.db_max_allocated_storage
  db_storage_type           = local.env.locals.db_storage_type
  db_storage_encrypted      = local.env.locals.db_storage_encrypted
  db_name                   = local.env.locals.db_name
  db_username               = local.env.locals.db_username
  db_password               = local.env.locals.db_password
  db_port                   = local.env.locals.db_port
  db_multi_az               = local.env.locals.db_multi_az
  db_deletion_protection    = local.env.locals.db_deletion_protection
  db_skip_final_snapshot    = local.env.locals.db_skip_final_snapshot

  ssh_public_key = file("${get_repo_root()}/keys/test.pub")
}
