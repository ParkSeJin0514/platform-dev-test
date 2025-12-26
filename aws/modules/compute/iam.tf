# ============================================================================
# Compute Module - iam.tf
# ============================================================================
# IRSA (IAM Roles for Service Accounts) 및 Management Instance IAM
# ============================================================================

# ============================================================================
# OIDC Provider (IRSA 필수)
# ============================================================================
data "tls_certificate" "cluster" {
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = module.eks.cluster_oidc_issuer_url

  tags = {
    Name        = "${var.project_name}-eks-oidc"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# ============================================================================
# 1. ALB Controller IRSA
# ============================================================================
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.48"

  role_name                              = "${var.project_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# ============================================================================
# 2. EBS CSI Driver IRSA
# ============================================================================
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.48"

  role_name             = "${var.project_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# ============================================================================
# 3. EFS CSI Driver IRSA
# ============================================================================
module "efs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.48"

  role_name             = "${var.project_name}-efs-csi-driver"
  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }

  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# ============================================================================
# 3. External Secrets IRSA
# ============================================================================

# Secrets Manager에 DB 자격증명 저장
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}/db"
  description             = "Database credentials for External Secrets"
  recovery_window_in_days = 0 # 즉시 삭제 가능 (운영에서는 7~30 권장)

  tags = {
    Name        = "${var.project_name}-db-secret"
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:mysql://${module.db.address}:${module.db.port}/${var.db_name}?useSSL=false&serverTimezone=UTC"
    SPRING_DATASOURCE_USERNAME = var.db_username
    SPRING_DATASOURCE_PASSWORD = var.db_password
  })
}

# External Secrets IAM Policy
resource "aws_iam_policy" "external_secrets" {
  name        = "${var.project_name}-external-secrets"
  description = "Policy for External Secrets Operator to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          aws_secretsmanager_secret.db.arn,
          "${aws_secretsmanager_secret.db.arn}*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:ListSecrets"
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

# External Secrets IRSA Role
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.48"

  role_name = "${var.project_name}-external-secrets"

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["external-secrets:external-secrets-sa"]
    }
  }

  role_policy_arns = {
    external_secrets = aws_iam_policy.external_secrets.arn
  }

  tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}

# ============================================================================
# Management Instance IAM
# ============================================================================
resource "aws_iam_role" "mgmt" {
  name = "${var.project_name}-mgmt-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-mgmt-role"
    Project     = var.project_name
    Environment = "production"
  }
}

resource "aws_iam_policy" "mgmt_eks_full" {
  name        = "${var.project_name}-mgmt-eks-full"
  description = "Full EKS permissions for mgmt EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mgmt_eks_full_attach" {
  role       = aws_iam_role.mgmt.name
  policy_arn = aws_iam_policy.mgmt_eks_full.arn
}

resource "aws_iam_role_policy_attachment" "mgmt_admin" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "mgmt_efs" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
}

resource "aws_iam_role_policy_attachment" "mgmt_ec2_readonly" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "mgmt_ecr_full" {
  role       = aws_iam_role.mgmt.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "mgmt" {
  name = "${var.project_name}-mgmt-instance-profile"
  role = aws_iam_role.mgmt.name
}

# ============================================================================
# EKS Access Entry - Management Instance 자동 접근 권한
# ============================================================================

resource "aws_eks_access_entry" "mgmt" {
  cluster_name  = module.eks.cluster_id
  principal_arn = aws_iam_role.mgmt.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "mgmt_admin" {
  cluster_name  = module.eks.cluster_id
  principal_arn = aws_iam_role.mgmt.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.mgmt]
}

# ============================================================================
# EKS Access Entry - GitHub Actions OIDC 자동 접근 권한
# ============================================================================

resource "aws_eks_access_entry" "github_oidc" {
  cluster_name  = module.eks.cluster_id
  principal_arn = "arn:aws:iam::946775837287:role/github-actions-terraform"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_oidc_admin" {
  cluster_name  = module.eks.cluster_id
  principal_arn = "arn:aws:iam::946775837287:role/github-actions-terraform"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_oidc]
}