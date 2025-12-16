# ============================================================================
# EKS 모듈 - main.tf
# ============================================================================
# EKS 클러스터와 Managed Node Group을 생성합니다.
#
# 생성 리소스:
#   - EKS Cluster (Control Plane)
#   - Launch Template (Worker Node 설정)
#   - Managed Node Group (Worker Nodes)
#
# Worker Node 특징:
#   - Ubuntu 24.04 EKS AMI 사용
#   - Private Subnet에 배치
#   - IMDSv2 강제 (보안)
#   - EBS 볼륨 암호화
# ============================================================================

# ============================================================================
# 1. EKS Cluster
# ============================================================================
# Kubernetes Control Plane (AWS가 관리)
# API Server, etcd, Controller Manager, Scheduler 등 포함
# ============================================================================

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  version  = var.cluster_version # 예: "1.33"
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    # Control Plane이 접근할 서브넷
    # Public + Private 모두 포함하여 다양한 접근 경로 확보
    subnet_ids = var.control_plane_subnet_ids

    # API Server 엔드포인트 접근 설정
    endpoint_private_access = var.endpoint_private_access # VPC 내부 접근
    endpoint_public_access  = var.endpoint_public_access  # 인터넷 접근

    # 추가 Security Group (커스텀 규칙용)
    security_group_ids = [aws_security_group.cluster.id]
  }

  # Control Plane 로깅 → CloudWatch Logs로 전송
  # api: API 서버 로그
  # audit: 감사 로그 (누가 무엇을 했는지)
  # authenticator: 인증 로그
  enabled_cluster_log_types = var.cluster_log_types

    access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  # IAM 정책이 먼저 연결되어야 클러스터 생성 가능
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_policy
  ]

  tags = var.tags
}

# ============================================================================
# 2. Ubuntu 24.04 EKS AMI 조회
# ============================================================================
# AWS SSM Parameter Store에서 Canonical이 제공하는 공식 Ubuntu EKS AMI 조회
# 클러스터 버전에 맞는 AMI가 자동 선택됨
# ============================================================================

data "aws_ssm_parameter" "ubuntu_eks_ami" {
  # 경로 형식: /aws/service/canonical/ubuntu/eks/{버전}/{릴리스}/...
  name = "/aws/service/canonical/ubuntu/eks/24.04/${var.cluster_version}/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ============================================================================
# 3. Launch Template
# ============================================================================
# Worker Node EC2 인스턴스의 설정을 정의
# AMI, 네트워크, 스토리지, 보안, 부트스트랩 스크립트 등
# ============================================================================

resource "aws_launch_template" "worker_nodes" {
  name_prefix            = "${var.cluster_name}-worker-"
  description            = "Launch template for EKS worker nodes with Ubuntu 24.04"
  update_default_version = true # 새 버전 생성 시 자동으로 기본 버전으로 설정

  # Ubuntu 24.04 EKS AMI (SSM에서 조회한 값)
  image_id = data.aws_ssm_parameter.ubuntu_eks_ami.value

  # SSH 접근용 Key Pair
  key_name = var.key_name

  # -------------------------------------------------------------------------
  # 네트워크 인터페이스 설정
  # -------------------------------------------------------------------------
  network_interfaces {
    associate_public_ip_address = false # Private IP만 사용 (보안)
    delete_on_termination       = true  # 인스턴스 삭제 시 ENI도 삭제

    # 2개의 Security Group 연결
    security_groups = [
      aws_security_group.node.id,                                     # 커스텀 Node SG
      aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id # EKS 관리형 SG
    ]
  }

  # -------------------------------------------------------------------------
  # EBS 볼륨 설정
  # -------------------------------------------------------------------------
  block_device_mappings {
    device_name = "/dev/sda1" # Ubuntu 기본 디바이스

    ebs {
      volume_size           = var.disk_size # GB 단위
      volume_type           = "gp3"         # 최신 SSD 타입 (가성비 좋음)
      iops                  = 3000          # gp3 기본 IOPS
      throughput            = 125           # MB/s
      delete_on_termination = true          # 인스턴스 삭제 시 볼륨도 삭제
      encrypted             = true          # 볼륨 암호화 (보안)
    }
  }

  # -------------------------------------------------------------------------
  # Instance Metadata Service (IMDS) 설정
  # -------------------------------------------------------------------------
  # IMDSv2 강제: SSRF 공격 방지를 위한 보안 설정
  # IMDSv1은 단순 HTTP GET으로 접근 가능하여 취약
  # IMDSv2는 토큰 기반으로 보안 강화
  # -------------------------------------------------------------------------
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 필수 (v1 차단)
    http_put_response_hop_limit = 2          # Pod 내부 컨테이너에서도 접근 가능
    instance_metadata_tags      = "enabled"  # 인스턴스 태그 메타데이터 접근 허용
  }

  # -------------------------------------------------------------------------
  # User Data - 부트스트랩 스크립트
  # -------------------------------------------------------------------------
  # templatefile(): Terraform 변수를 스크립트에 주입
  # base64encode(): AWS가 요구하는 인코딩
  # -------------------------------------------------------------------------
  user_data = base64encode(templatefile("${path.module}/userdata.tftpl", {
    cluster_name       = aws_eks_cluster.cluster.name
    cluster_endpoint   = aws_eks_cluster.cluster.endpoint
    cluster_ca         = aws_eks_cluster.cluster.certificate_authority[0].data
    kubelet_extra_args = var.kubelet_extra_args
  }))

  # 인스턴스 태그
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-worker-node"
        # EKS가 이 노드를 소유함을 표시
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      }
    )
  }

  # 볼륨 태그
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-worker-volume"
      }
    )
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-launch-template"
    }
  )
}

# ============================================================================
# 4. EKS Managed Node Group
# ============================================================================
# AWS가 관리하는 Worker Node 그룹
# Auto Scaling, 롤링 업데이트, 헬스 체크 등 자동 처리
# ============================================================================

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node.arn

  # Worker Node를 배치할 서브넷 (Private EKS Subnet)
  subnet_ids = var.worker_subnet_ids

  # AMI Type
  # CUSTOM: Launch Template에서 지정한 AMI 사용 (Ubuntu)
  # AL2_x86_64: Amazon Linux 2 (기본값)
  ami_type = "CUSTOM"

  # 용량 타입
  # ON_DEMAND: 안정적, 비용 예측 가능
  # SPOT: 최대 90% 저렴, 언제든 중단 가능
  capacity_type = var.capacity_type

  # 인스턴스 타입 (Launch Template에서 지정하지 않은 경우 사용)
  instance_types = var.instance_types

  # -------------------------------------------------------------------------
  # 스케일링 설정
  # -------------------------------------------------------------------------
  scaling_config {
    desired_size = var.desired_size # 원하는 노드 수
    max_size     = var.max_size     # Auto Scaling 상한
    min_size     = var.min_size     # Auto Scaling 하한
  }

  # -------------------------------------------------------------------------
  # 업데이트 전략
  # -------------------------------------------------------------------------
  # max_unavailable_percentage: 롤링 업데이트 시 동시에 중단될 수 있는 비율
  # 예: 33% = 노드 3대일 때 1대씩 업데이트
  # -------------------------------------------------------------------------
  update_config {
    max_unavailable_percentage = var.max_unavailable_percentage
  }

  # Launch Template 연결
  launch_template {
    id      = aws_launch_template.worker_nodes.id
    version = "$Latest" # 항상 최신 버전 사용
  }

  # Kubernetes 노드 레이블
  labels = var.node_labels

  # -------------------------------------------------------------------------
  # Kubernetes Taint (동적 블록)
  # -------------------------------------------------------------------------
  # Taint: 특정 Pod만 이 노드에 스케줄링되도록 제한
  # effect: NoSchedule, NoExecute, PreferNoSchedule
  # -------------------------------------------------------------------------
  dynamic "taint" {
    for_each = var.node_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # IAM 정책이 먼저 연결되어야 노드 그룹 생성 가능
  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
    aws_iam_role_policy_attachment.node_ssm_policy
  ]

  tags = merge(
    var.tags,
    {
      Name = var.node_group_name
    }
  )

  lifecycle {
    # 새 노드 그룹 먼저 생성 후 기존 삭제 (다운타임 최소화)
    create_before_destroy = true

    # Cluster Autoscaler나 HPA가 조정하는 desired_size는 무시
    # Terraform이 매번 원래 값으로 되돌리지 않도록
    ignore_changes = [scaling_config[0].desired_size]
  }
}