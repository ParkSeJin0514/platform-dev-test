# ============================================================================
# Bootstrap Module - variables.tf (GCP)
# ============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

# ============================================================================
# GKE 클러스터 정보
# ============================================================================
variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "GKE cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  type        = string
}

# ============================================================================
# ArgoCD 설정
# ============================================================================
variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "argocd_namespace" {
  description = "ArgoCD namespace"
  type        = string
  default     = "argocd"
}

variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
}

variable "gitops_target_revision" {
  description = "GitOps target revision (branch)"
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Path to apps in GitOps repository"
  type        = string
  default     = "gcp/apps"
}
