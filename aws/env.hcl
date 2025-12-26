# ============================================================================
# Environment Configuration (env.hcl)
# ============================================================================
# 🎯 이 파일 하나만 수정하면 전체 환경 설정 완료!
# 
# 환경별로 이 파일을 복사해서 사용:
#   - dev/env.hcl
#   - stg/env.hcl  
#   - prd/env.hcl
# ============================================================================

locals {
  # =========================================================================
  # 기본 설정
  # =========================================================================
  project_name = "petclinic-kr"
  environment  = "dev"
  region       = "ap-northeast-2"

  # =========================================================================
  # Network 설정 (Foundation)
  # =========================================================================
  vpc_cidr = "10.0.0.0/16"
  az_count = 2

  # =========================================================================
  # EC2 설정 (Compute)
  # =========================================================================
  bastion_instance_type = "t3.micro"
  mgmt_instance_type    = "t3.small"
  key_name              = "aws/keys"

  # Ubuntu AMI 필터
  ubuntu_ami_filters = [
    {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    },
    {
      name   = "root-device-type"
      values = ["ebs"]
    },
    {
      name   = "virtualization-type"
      values = ["hvm"]
    },
    {
      name   = "architecture"
      values = ["x86_64"]
    }
  ]

  # =========================================================================
  # EKS 설정 (Compute)
  # =========================================================================
  # Managed Node Group: 시스템 컴포넌트 전용 (Karpenter, CoreDNS 등)
  # 워크로드는 Karpenter가 프로비저닝하는 노드에서 실행
  # =========================================================================
  eks_version                    = "1.31"
  eks_instance_types             = ["t3.medium"]
  eks_capacity_type              = "ON_DEMAND"  # 시스템 노드는 Spot 사용 안함 (안정성)
  eks_disk_size                  = 50
  eks_desired_size               = 2   # 시스템용 2대 (기존 3대에서 축소)
  eks_min_size                   = 2   # 최소 2대 유지
  eks_max_size                   = 3   # 최대 3대
  eks_max_unavailable_percentage = 33
  eks_kubelet_extra_args         = "--max-pods=110"
  
  # 시스템 노드 전용 레이블
  eks_node_labels = {
    "node-role" = "system"
  }
  
  # 시스템 노드 전용 Taint (선택적)
  # 활성화하면 일반 워크로드는 Karpenter 노드에서만 실행됨
  # 주의: Karpenter 설치 전에는 비활성화 권장
  eks_node_taints = [
    # {
    #   key    = "CriticalAddonsOnly"
    #   value  = "true"
    #   effect = "NoSchedule"
    # }
  ]
  
  eks_cluster_log_types = ["api", "audit", "authenticator"]

  # =========================================================================
  # RDS 설정 (Compute)
  # =========================================================================
  db_engine                 = "mysql"
  db_engine_version         = "8.0"
  db_parameter_group_family = "mysql8.0"
  db_instance_class         = "db.t3.micro"
  db_allocated_storage      = 20
  db_max_allocated_storage  = 100
  db_storage_type           = "gp3"
  db_storage_encrypted      = true
  db_name                   = "petclinic"
  db_username               = "admin"
  # ⚠️ 민감한 정보 - GitHub Secrets에서 가져옴
  db_password               = get_env("TF_VAR_db_password", "")
  db_port                   = 3306
  db_multi_az               = false
  db_deletion_protection    = false
  db_skip_final_snapshot    = true

  # =========================================================================
  # ArgoCD 설정 (Bootstrap)
  # =========================================================================
  argocd_chart_version    = "5.51.6"
  argocd_namespace        = "argocd"
  gitops_repo_url = "https://github.com/ParkSeJin0514/platform-gitops-last.git"
  gitops_target_revision  = "main"

  # =========================================================================
  # kube-prometheus-stack 설정 (Bootstrap)
  # Alertmanager 비활성화됨
  # =========================================================================
  prometheus_stack_version = "58.2.2"
  prometheus_storage_size  = "20Gi"
  grafana_admin_password   = get_env("TF_VAR_grafana_admin_password", "admin123!")
  grafana_storage_size     = "5Gi"
}
