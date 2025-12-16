# ============================================================================
# Terragrunt Root Configuration
# ============================================================================
# 모든 하위 모듈에서 상속받는 공통 설정
# - S3 Backend (State 저장)
# - AWS Provider
# - 공통 태그
# ============================================================================

locals {
  # env.hcl에서 환경 변수 로드
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project_name = local.env_vars.locals.project_name
  environment  = local.env_vars.locals.environment
  region       = local.env_vars.locals.region

  # S3 Backend 설정
  bucket_name = "${local.project_name}-tfstate"
  lock_table  = "${local.project_name}-tflock"
}

# ============================================================================
# Remote State (S3 Backend)
# ============================================================================
# ⚠️ 처음 사용 시 S3 버킷과 DynamoDB 테이블을 먼저 생성해야 합니다.
# 
# aws s3 mb s3://petclinic-kr-tfstate --region ap-northeast-2
# aws dynamodb create-table \
#   --table-name petclinic-kr-tflock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region ap-northeast-2
# ============================================================================

remote_state {
  backend = "s3"

  config = {
    bucket         = local.bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = local.lock_table
    
    # 추가
    skip_bucket_versioning         = true
    skip_bucket_ssencryption       = true
    skip_bucket_accesslogging      = true
    skip_bucket_root_access        = true
    skip_bucket_public_access_blocking = true
    skip_bucket_enforced_tls       = true
  }

  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ============================================================================
# Provider 자동 생성
# ============================================================================
generate "provider" {
  path      = "_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 2.23"
        }
        helm = {
          source  = "hashicorp/helm"
          version = "~> 2.11"
        }
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = "~> 1.14"
        }
        tls = {
          source  = "hashicorp/tls"
          version = "~> 4.0"
        }
      }
    }

    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = {
          Environment = "${local.environment}"
          Project     = "${local.project_name}"
          ManagedBy   = "Terragrunt"
        }
      }
    }
  EOF
}

# ============================================================================
# 공통 입력 변수
# ============================================================================
inputs = {
  project_name = local.project_name
  environment  = local.environment
  region       = local.region
}
