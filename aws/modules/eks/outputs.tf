# ===================================
# Cluster Outputs
# ===================================
output "cluster_id" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.cluster.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.cluster.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.cluster.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.cluster.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.cluster.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster (managed by EKS)"
  value       = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.cluster.identity[0].oidc[0].issuer, null)
}

# ===================================
# Node Group Outputs
# ===================================
output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.node.id
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = aws_eks_node_group.node.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.node.status
}

output "node_group_resources" {
  description = "Resources associated with the node group"
  value       = aws_eks_node_group.node.resources
}

output "node_group_autoscaling_groups" {
  description = "List of Auto Scaling Group names associated with this node group"
  value       = try(aws_eks_node_group.node.resources[0].autoscaling_groups, [])
}

# ===================================
# Launch Template Outputs
# ===================================
output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.worker_nodes.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.worker_nodes.latest_version
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.worker_nodes.arn
}

# ===================================
# IAM Outputs
# ===================================
output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS worker nodes"
  value       = aws_iam_role.node.arn
}

output "node_iam_role_name" {
  description = "IAM role name of the EKS worker nodes"
  value       = aws_iam_role.node.name
}

# ===================================
# Security Group Outputs
# ===================================
output "cluster_security_group_custom_id" {
  description = "Custom security group ID for the cluster control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID for the worker nodes"
  value       = aws_security_group.node.id
}

# ===================================
# AMI Outputs
# ===================================
output "ubuntu_ami_id" {
  description = "Ubuntu 24.04 EKS AMI ID being used"
  value       = data.aws_ssm_parameter.ubuntu_eks_ami.value
}