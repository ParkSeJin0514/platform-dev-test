# ============================================================================
# EKS 모듈 - iam.tf
# ============================================================================
# EKS 클러스터와 Worker Node에 필요한 IAM Role과 Policy를 정의합니다.
#
# 생성 리소스:
#   - Cluster IAM Role (EKS 서비스가 사용)
#   - Node IAM Role (Worker Node EC2가 사용)
#   - 각 Role에 필요한 Policy 연결
# ============================================================================

# ============================================================================
# 1. EKS Cluster IAM Role
# ============================================================================
# EKS 서비스(eks.amazonaws.com)가 이 역할을 사용하여
# AWS 리소스를 생성/관리합니다.
# ============================================================================

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  # Trust Policy (누가 이 역할을 사용할 수 있는지)
  # EKS 서비스만 이 역할을 assume할 수 있음
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-role"
    }
  )
}

# -------------------------------------------------------------------------
# Cluster Role에 연결할 Policy
# -------------------------------------------------------------------------

# AmazonEKSClusterPolicy (필수)
# EKS 클러스터가 AWS 리소스를 관리하는 데 필요한 권한
# - EC2, ELB, CloudWatch 등
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# AmazonEKSVPCResourceController (권장)
# Pod 네트워킹을 위해 ENI를 관리하는 권한
# Security Groups for Pods 기능 사용 시 필수
resource "aws_iam_role_policy_attachment" "cluster_vpc_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ============================================================================
# 2. EKS Node IAM Role
# ============================================================================
# Worker Node EC2 인스턴스가 이 역할을 사용합니다.
# kubelet이 EKS API와 통신하고, ECR에서 이미지를 Pull하는 등의 작업에 필요
# ============================================================================

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  # Trust Policy
  # EC2 서비스가 이 역할을 assume할 수 있음
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-role"
    }
  )
}

# -------------------------------------------------------------------------
# Node Role에 연결할 Policy
# -------------------------------------------------------------------------

# AmazonEKSWorkerNodePolicy (필수)
# Worker Node가 EKS 클러스터와 통신하는 데 필요한 권한
# - EC2 DescribeInstances
# - EKS DescribeCluster
resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

# AmazonEKS_CNI_Policy (필수)
# VPC CNI 플러그인이 Pod 네트워킹을 위해 ENI를 관리하는 권한
# - EC2 CreateNetworkInterface, DeleteNetworkInterface
# - EC2 AssignPrivateIpAddresses
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

# AmazonEC2ContainerRegistryReadOnly (필수)
# ECR에서 컨테이너 이미지를 Pull하는 권한
# - ecr:GetDownloadUrlForLayer
# - ecr:BatchGetImage
resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# AmazonSSMManagedInstanceCore (권장)
# AWS Systems Manager Session Manager로 인스턴스 접근 가능
# SSH 대신 사용 가능 (Key Pair 없이도 접근)
resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}