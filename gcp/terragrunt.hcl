# ============================================================================
# Terragrunt Root Configuration (GCP)
# ============================================================================
# 모든 하위 모듈에서 상속받는 공통 설정
# - GCS Backend (State 저장)
# - Google Provider
# - 공통 라벨
# ============================================================================

locals {
  # env.hcl에서 환경 변수 로드
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project_id   = local.env_vars.locals.project_id
  project_name = local.env_vars.locals.project_name
  region       = local.env_vars.locals.region

  # GCS Backend 설정
  bucket_name = local.env_vars.locals.tfstate_bucket
}

# ============================================================================
# Remote State (GCS Backend)
# ============================================================================
# GCS 버킷이 이미 존재해야 합니다.
#
# gsutil mb -l asia-northeast3 gs://kdt2-final-project-t1-tfstate
# ============================================================================

remote_state {
  backend = "gcs"

  config = {
    bucket   = local.bucket_name
    prefix   = "${path_relative_to_include()}/terraform.tfstate"
    project  = local.project_id
    location = local.region
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
        google = {
          source  = "hashicorp/google"
          version = "~> 5.0"
        }
        google-beta = {
          source  = "hashicorp/google-beta"
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
      }
    }

    provider "google" {
      project = "${local.project_id}"
      region  = "${local.region}"

      default_labels = {
        environment = "dr"
        project     = "${local.project_name}"
        managed-by  = "terragrunt"
      }
    }

    provider "google-beta" {
      project = "${local.project_id}"
      region  = "${local.region}"

      default_labels = {
        environment = "dr"
        project     = "${local.project_name}"
        managed-by  = "terragrunt"
      }
    }
  EOF
}

# ============================================================================
# 공통 입력 변수
# ============================================================================
inputs = {
  project_id   = local.project_id
  project_name = local.project_name
  region       = local.region
}
