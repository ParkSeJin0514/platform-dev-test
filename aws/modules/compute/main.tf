# ============================================================================
# Compute Module - main.tf
# ============================================================================
# EKS, EC2, RDS 및 IRSA Roles 생성
# ============================================================================

# ============================================================================
# Data Sources
# ============================================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  dynamic "filter" {
    for_each = var.ubuntu_ami_filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Key Pair
# ============================================================================
resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

# ============================================================================
# EC2 모듈 - Bastion & Management Instance
# ============================================================================
module "ec2" {
  source = "../ec2"

  project_name = var.project_name
  vpc_id       = var.vpc_id
  ami          = data.aws_ami.ubuntu.id
  key_name     = aws_key_pair.this.key_name

  # Bastion - Public Subnet
  bastion_instance_type = var.bastion_instance_type
  public_subnet_id      = var.public_subnet_ids[0]

  # Mgmt - Private Subnet
  mgmt_instance_type = var.mgmt_instance_type
  private_subnet_id  = var.private_mgmt_subnet_ids[0]

  # IAM Instance Profile
  mgmt_iam_instance_profile = aws_iam_instance_profile.mgmt.name

  # kubeconfig 설정용
  region       = var.region
  cluster_name = "${var.project_name}-eks"

  # NAT Gateway 의존성 (없으면 빈 리스트)
  nat_gateway_ids = {}
}

# ============================================================================
# EKS 모듈 - Kubernetes Cluster
# ============================================================================
module "eks" {
  source = "../eks"

  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.eks_version
  vpc_id          = var.vpc_id

  # Control Plane 서브넷 (Public + Private)
  control_plane_subnet_ids = concat(
    var.public_subnet_ids,
    var.private_eks_subnet_ids
  )

  # Worker Node는 Private Subnet에만
  worker_subnet_ids = var.private_eks_subnet_ids

  # API Server 접근 설정
  endpoint_private_access = true
  endpoint_public_access  = true

  # Control Plane 로깅
  cluster_log_types = var.eks_cluster_log_types

  # Node Group 설정
  node_group_name = "${var.project_name}-workers"
  instance_types  = var.eks_instance_types
  capacity_type   = var.eks_capacity_type

  disk_size    = var.eks_disk_size
  desired_size = var.eks_desired_size
  max_size     = var.eks_max_size
  min_size     = var.eks_min_size

  max_unavailable_percentage = var.eks_max_unavailable_percentage

  key_name = aws_key_pair.this.key_name

  # Management Instance SG 연결
  enable_mgmt_sg_rule    = true
  mgmt_security_group_id = module.ec2.mgmt_security_group_id

  # ALB → Node 트래픽 허용 (VPC CIDR 기반)
  vpc_cidr = var.vpc_cidr

  # 노드 레이블 & Taint
  node_labels = merge(
    {
      Environment = "production"
      Application = var.project_name
      ManagedBy   = "terragrunt"
    },
    var.eks_node_labels
  )

  node_taints        = var.eks_node_taints
  kubelet_extra_args = var.eks_kubelet_extra_args

  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# ============================================================================
# RDS 모듈 - MySQL Database
# ============================================================================
module "db" {
  source = "../db"

  identifier = "${var.project_name}-db"
  vpc_id     = var.vpc_id
  subnet_ids = var.private_db_subnet_ids

  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  parameter_group_family = var.db_parameter_group_family

  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = var.db_storage_type
  storage_encrypted     = var.db_storage_encrypted

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  publicly_accessible = false
  multi_az            = var.db_multi_az

  # EKS Worker Node, Karpenter Node, Mgmt Instance에서 접근 허용
  allowed_security_group_ids = [
    module.eks.node_security_group_id,         # EKS 관리형 노드
    module.eks.cluster_security_group_id,      # Karpenter 노드 (EKS Cluster SG 사용)
    module.ec2.mgmt_security_group_id          # Management Instance
  ]

  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.project_name}-mysql-final"

  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }

  depends_on = [module.eks]
}

# ============================================================================
# Kubernetes/Helm Provider 설정
# ============================================================================
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# ============================================================================
# kube-prometheus-stack Helm Chart (petclinic namespace)
# ============================================================================
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_stack_version
  namespace        = "petclinic"
  create_namespace = true

  values = [
    <<-EOT
    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        podMonitorSelectorNilUsesHelmValues: false
        retention: 7d
        storageSpec:
          volumeClaimTemplate:
            spec:
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: ${var.prometheus_storage_size}

    grafana:
      enabled: true
      adminPassword: ${var.grafana_admin_password}
      persistence:
        enabled: true
        size: ${var.grafana_storage_size}
      sidecar:
        datasources:
          enabled: true
        dashboards:
          enabled: true

    alertmanager:
      alertmanagerSpec:
        storage:
          volumeClaimTemplate:
            spec:
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 5Gi

    nodeExporter:
      enabled: true
    kubeStateMetrics:
      enabled: true
    EOT
  ]

  depends_on = [module.eks]
}

# ============================================================================
# Cluster Monitoring Ingress는 petclinic-gitops에서 관리
# ============================================================================
# Ingress 리소스는 petclinic-gitops/overlays/aws/cluster-monitoring-ingress.yaml에서 관리
# Terraform은 kube-prometheus-stack Helm Chart만 설치
