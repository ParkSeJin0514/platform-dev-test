# ============================================================================
# Compute Module - outputs.tf
# ============================================================================
# Bootstrap 레이어 및 GitOps에서 사용할 출력값
# ============================================================================

# ============================================================================
# EKS Outputs
# ============================================================================
output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS 클러스터 CA 인증서"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_cluster_oidc_issuer_url" {
  description = "EKS OIDC Issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_cluster_version" {
  description = "EKS Kubernetes 버전"
  value       = module.eks.cluster_version
}

output "eks_node_iam_role_arn" {
  description = "EKS Node IAM Role ARN"
  value       = module.eks.node_iam_role_arn
}

# ============================================================================
# EC2 Outputs
# ============================================================================
output "bastion_public_ip" {
  description = "Bastion Host Public IP"
  value       = module.ec2.bastion_public_ip
}

output "mgmt_private_ip" {
  description = "Management Instance Private IP"
  value       = module.ec2.mgmt_private_ip
}

output "mgmt_iam_role_arn" {
  description = "Management Instance IAM Role ARN"
  value       = aws_iam_role.mgmt.arn
}

# ============================================================================
# RDS Outputs
# ============================================================================
output "rds_endpoint" {
  description = "RDS 엔드포인트"
  value       = module.db.address
}

output "rds_port" {
  description = "RDS 포트"
  value       = module.db.port
}

output "rds_database_name" {
  description = "데이터베이스 이름"
  value       = module.db.db_name
}

# ============================================================================
# IRSA Role ARNs (GitOps ServiceAccount annotation에 사용)
# ============================================================================
output "alb_controller_role_arn" {
  description = "ALB Controller IRSA Role ARN"
  value       = module.alb_controller_irsa.iam_role_arn
}

output "efs_csi_driver_role_arn" {
  description = "EFS CSI Driver IRSA Role ARN"
  value       = module.efs_csi_irsa.iam_role_arn
}

output "external_secrets_role_arn" {
  description = "External Secrets IRSA Role ARN"
  value       = module.external_secrets_irsa.iam_role_arn
}

# ============================================================================
# Secrets Manager
# ============================================================================
output "secrets_manager_secret_arn" {
  description = "AWS Secrets Manager Secret ARN"
  value       = aws_secretsmanager_secret.db.arn
}

output "secrets_manager_secret_name" {
  description = "AWS Secrets Manager Secret Name"
  value       = aws_secretsmanager_secret.db.name
}

# ============================================================================
# OIDC Provider
# ============================================================================
output "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

# ============================================================================
# Karpenter Outputs
# ============================================================================
output "karpenter_controller_role_arn" {
  description = "Karpenter Controller IRSA Role ARN"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_name" {
  description = "Karpenter Node IAM Role Name (EC2NodeClass에서 사용)"
  value       = aws_iam_role.karpenter_node.name
}

output "karpenter_node_instance_profile_name" {
  description = "Karpenter Node Instance Profile Name"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  description = "Karpenter Spot Interruption SQS Queue Name"
  value       = aws_sqs_queue.karpenter_interruption.name
}

# ============================================================================
# 접속 가이드
# ============================================================================
output "connection_guide" {
  description = "접속 가이드"
  value       = <<-EOT

  ============================================
  📋 접속 가이드
  ============================================

  1️⃣  Bastion Host SSH 접속
      ssh -i keys/test ubuntu@${module.ec2.bastion_public_ip}

  2️⃣  Management Instance 접속 (Bastion 경유)
      ssh -i keys/test -J ubuntu@${module.ec2.bastion_public_ip} ubuntu@${module.ec2.mgmt_private_ip}

  3️⃣  kubeconfig 설정 (Management Instance에서)
      aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.region}

  4️⃣  RDS 접속 정보
      Host: ${module.db.address}
      Port: ${module.db.port}
      Database: ${module.db.db_name}

  ============================================
  📋 IRSA Role ARNs (GitOps에서 사용)
  ============================================

  ALB Controller:     ${module.alb_controller_irsa.iam_role_arn}
  EFS CSI Driver:     ${module.efs_csi_irsa.iam_role_arn}
  External Secrets:   ${module.external_secrets_irsa.iam_role_arn}
  Karpenter:          ${aws_iam_role.karpenter_controller.arn}

  ============================================
  📋 Karpenter 설정값
  ============================================

  Controller Role:    ${aws_iam_role.karpenter_controller.arn}
  Node Role:          ${aws_iam_role.karpenter_node.name}
  Instance Profile:   ${aws_iam_instance_profile.karpenter_node.name}
  SQS Queue:          ${aws_sqs_queue.karpenter_interruption.name}

  EOT
}
