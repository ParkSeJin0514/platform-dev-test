# ============================================================================
# Compute Module - karpenter.tf
# ============================================================================
# Karpenter 설치 및 운영에 필요한 AWS 리소스
#
# 생성 리소스:
#   - Karpenter Controller IRSA Role
#   - Karpenter Node IAM Role & Instance Profile
#   - SQS Queue (Spot 중단 알림용)
#   - EventBridge Rules (Spot/상태 이벤트)
#
# 참고: https://karpenter.sh/docs/getting-started/
# ============================================================================

# ============================================================================
# 1. Karpenter Controller IRSA Role
# ============================================================================
# Karpenter Controller Pod가 AWS API를 호출하기 위한 권한
# - EC2 인스턴스 생성/삭제
# - 가격 정보 조회
# - SQS 메시지 처리
# ============================================================================

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.project_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:karpenter"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-karpenter-controller"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# Karpenter Controller Policy
resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.project_name}-karpenter-controller"
  description = "Policy for Karpenter Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 인스턴스 관리
      {
        Sid    = "EC2NodeManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      # IAM Instance Profile 전달
      {
        Sid    = "PassNodeIAMRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
      },
      # EKS 클러스터 정보 조회
      {
        Sid    = "EKSClusterEndpointLookup"
        Effect = "Allow"
        Action = "eks:DescribeCluster"
        Resource = module.eks.cluster_arn
      },
      # SSM Parameter (AMI 조회)
      {
        Sid    = "SSMGetParameter"
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${data.aws_region.current.name}::parameter/aws/service/*"
      },
      # Pricing API (비용 최적화)
      {
        Sid    = "PricingAPI"
        Effect = "Allow"
        Action = "pricing:GetProducts"
        Resource = "*"
      },
      # SQS (Spot 중단 알림)
      {
        Sid    = "SQSInterruptionQueue"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      # IAM Instance Profile 관리 (Karpenter 1.0+ 필수)
      # Karpenter가 자체적으로 Instance Profile 생성/관리
      {
        Sid    = "IAMInstanceProfileManagement"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ============================================================================
# 2. Karpenter Node IAM Role & Instance Profile
# ============================================================================
# Karpenter가 프로비저닝하는 EC2 노드가 사용할 IAM Role
# Managed Node Group의 노드 Role과 동일한 권한 필요
# ============================================================================

resource "aws_iam_role" "karpenter_node" {
  name = "${var.project_name}-karpenter-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-karpenter-node"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# 필수 정책 연결
resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile (EC2가 Role을 사용하기 위해 필요)
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.project_name}-karpenter-node"
  role = aws_iam_role.karpenter_node.name

  tags = {
    Name        = "${var.project_name}-karpenter-node"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# EKS Access Entry - Karpenter Node가 EKS에 자동 접근
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = module.eks.cluster_id
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}

# ============================================================================
# 3. SQS Queue - Spot 중단 알림 처리
# ============================================================================
# AWS가 Spot 중단 2분 전에 알림을 보내면 Karpenter가 이를 감지하고
# 새 노드를 프로비저닝하여 Pod를 안전하게 이동시킴
# ============================================================================

resource "aws_sqs_queue" "karpenter_interruption" {
  name                       = "${var.project_name}-karpenter-interruption"
  message_retention_seconds  = 300  # 5분
  visibility_timeout_seconds = 30
  sqs_managed_sse_enabled    = true

  tags = {
    Name        = "${var.project_name}-karpenter-interruption"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# SQS Queue Policy - EventBridge가 메시지를 보낼 수 있도록 허용
resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEventBridge"
      Effect = "Allow"
      Principal = {
        Service = ["events.amazonaws.com", "sqs.amazonaws.com"]
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# ============================================================================
# 4. EventBridge Rules - 인스턴스 상태 이벤트
# ============================================================================
# Spot 중단, 인스턴스 상태 변경, 헬스 체크 이벤트를 SQS로 전달
# ============================================================================

# Spot Instance 중단 경고
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.project_name}-karpenter-spot-interruption"
  description = "Spot Instance Interruption Warning for Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = {
    Name        = "${var.project_name}-karpenter-spot-interruption"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# Rebalance 권고 (Spot 중단 가능성 높을 때)
resource "aws_cloudwatch_event_rule" "rebalance" {
  name        = "${var.project_name}-karpenter-rebalance"
  description = "EC2 Instance Rebalance Recommendation for Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = {
    Name        = "${var.project_name}-karpenter-rebalance"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

resource "aws_cloudwatch_event_target" "rebalance" {
  rule      = aws_cloudwatch_event_rule.rebalance.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# 인스턴스 상태 변경 (terminating 등)
resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${var.project_name}-karpenter-state-change"
  description = "EC2 Instance State Change for Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = {
    Name        = "${var.project_name}-karpenter-state-change"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule      = aws_cloudwatch_event_rule.instance_state_change.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# Scheduled Change (유지보수 이벤트)
resource "aws_cloudwatch_event_rule" "scheduled_change" {
  name        = "${var.project_name}-karpenter-scheduled-change"
  description = "AWS Health Event for Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = {
    Name        = "${var.project_name}-karpenter-scheduled-change"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

resource "aws_cloudwatch_event_target" "scheduled_change" {
  rule      = aws_cloudwatch_event_rule.scheduled_change.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# ============================================================================
# 5. Subnet & Security Group 태그 (Karpenter Discovery용)
# ============================================================================
# Karpenter가 서브넷과 Security Group을 찾기 위해 태그 필요
# ============================================================================

# Private EKS Subnet에 Karpenter Discovery 태그 추가
resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  count       = length(var.private_eks_subnet_ids)
  resource_id = var.private_eks_subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = "${var.project_name}-eks"
}

# EKS 클러스터 Security Group에 Karpenter Discovery 태그 추가
resource "aws_ec2_tag" "karpenter_security_group_discovery" {
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = "${var.project_name}-eks"
}

# Node Security Group에도 태그 추가
resource "aws_ec2_tag" "karpenter_node_sg_discovery" {
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = "${var.project_name}-eks"
}

# ============================================================================
# 6. Spot Instance Service-Linked Role
# ============================================================================
# EC2 Spot Instance를 사용하기 위한 Service-Linked Role
# 계정당 한 번만 생성하면 됨 (이미 존재하면 생성 스킵)
# ============================================================================

# 기존 Spot SLR 존재 여부 확인
data "aws_iam_roles" "spot_fleet_slr" {
  name_regex = "AWSServiceRoleForEC2Spot"
}

resource "aws_iam_service_linked_role" "spot" {
  # 이미 존재하면 생성하지 않음
  count            = length(data.aws_iam_roles.spot_fleet_slr.names) == 0 ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
  description      = "Service-linked role for EC2 Spot Instances"
}