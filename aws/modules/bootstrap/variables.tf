# ============================================================================
# Bootstrap Module - variables.tf
# ============================================================================

# ============================================================================
# Foundation/Compute에서 받아오는 변수
# ============================================================================
variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "region" {
  type        = string
  description = "AWS 리전"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "cluster_name" {
  type        = string
  description = "EKS 클러스터 이름"
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS 클러스터 엔드포인트"
}

variable "cluster_certificate_authority_data" {
  type        = string
  description = "EKS 클러스터 CA 인증서"
  sensitive   = true
}

variable "node_iam_role_arn" {
  type        = string
  description = "EKS Node IAM Role ARN"
}

variable "mgmt_iam_role_arn" {
  type        = string
  description = "Management Instance IAM Role ARN"
}

# ============================================================================
# IRSA Role ARNs (GitOps에서 사용)
# ============================================================================
variable "alb_controller_role_arn" {
  type        = string
  description = "ALB Controller IRSA Role ARN"
}

variable "efs_csi_driver_role_arn" {
  type        = string
  description = "EFS CSI Driver IRSA Role ARN"
}

variable "external_secrets_role_arn" {
  type        = string
  description = "External Secrets IRSA Role ARN"
}

# ============================================================================
# ArgoCD 설정
# ============================================================================
variable "argocd_chart_version" {
  type        = string
  description = "ArgoCD Helm Chart 버전"
  default     = "5.51.6"
}

variable "argocd_namespace" {
  type        = string
  description = "ArgoCD 네임스페이스"
  default     = "argocd"
}

variable "gitops_repo_url" {
  type        = string
  description = "GitOps Repository URL"
}

variable "gitops_target_revision" {
  type        = string
  description = "GitOps Repository 브랜치/태그"
  default     = "main"
}

