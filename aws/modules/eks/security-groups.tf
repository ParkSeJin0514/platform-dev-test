# ============================================================================
# EKS 모듈 - security-groups.tf
# ============================================================================
# EKS 클러스터와 Worker Node의 Security Group을 정의합니다.
#
# Security Group 구조:
#   - Cluster SG: Control Plane 통신용
#   - Node SG: Worker Node 통신용
#   - EKS Managed SG: AWS가 자동 생성 (추가로 연결)
#
# 통신 흐름:
#   Control Plane ←→ Worker Node (양방향)
#   Worker Node ←→ Worker Node (Pod 간 통신)
#   Mgmt Instance → Control Plane (kubectl)
# ============================================================================

# ============================================================================
# 1. Cluster Security Group
# ============================================================================
# EKS Control Plane의 추가 Security Group
# 기본 EKS Managed SG 외에 커스텀 규칙을 적용하기 위해 사용
# ============================================================================

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg-"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )

  lifecycle {
    # SG 교체 시 새 SG 먼저 생성 후 기존 삭제 (연결 끊김 방지)
    create_before_destroy = true
  }
}

# ============================================================================
# 2. Node Security Group
# ============================================================================
# Worker Node EC2 인스턴스의 Security Group
# Pod 간 통신, Control Plane과의 통신에 사용
# ============================================================================

resource "aws_security_group" "node" {
  name_prefix = "${var.cluster_name}-node-sg-"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-sg"
      # EKS가 이 SG를 소유함을 표시
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# 3. Security Group Rules
# ============================================================================

# -------------------------------------------------------------------------
# Node ↔ Node 통신 (모든 프로토콜)
# -------------------------------------------------------------------------
# Pod 간 통신에 필요
# VPC CNI는 Pod에 VPC IP를 할당하므로 노드 간 직접 통신 필요
# -------------------------------------------------------------------------
resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0    # ← 수정: protocol이 "-1"이므로 0
  protocol                 = "-1" # 모든 프로토콜
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id # 자기 자신 참조
}

# -------------------------------------------------------------------------
# Control Plane → Node (1025-65535)
# -------------------------------------------------------------------------
# Control Plane이 Worker Node의 kubelet과 통신
# - kubelet API (10250)
# - NodePort Services (30000-32767)
# - 기타 Pod 통신
# -------------------------------------------------------------------------
resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

# -------------------------------------------------------------------------
# Node → Control Plane API (443)
# -------------------------------------------------------------------------
# Worker Node의 kubelet, kube-proxy가 API Server와 통신
# - Pod 상태 보고
# - ConfigMap, Secret 조회
# - Service Endpoint 업데이트
# -------------------------------------------------------------------------
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

# -------------------------------------------------------------------------
# Node → Internet (All Outbound)
# -------------------------------------------------------------------------
# Worker Node가 외부와 통신
# - ECR에서 이미지 Pull
# - 외부 API 호출
# - NAT Gateway를 통해 인터넷 접근
# -------------------------------------------------------------------------
resource "aws_security_group_rule" "node_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
}

# -------------------------------------------------------------------------
# Control Plane → Node (All Traffic) Egress
# -------------------------------------------------------------------------
# Cluster SG에서 Node SG로 나가는 모든 트래픽 허용
# - kubelet API (10250)
# - NodePort Services (30000-32767)
# - Extension API servers (443)
# - 기타 Pod 통신
# -------------------------------------------------------------------------
resource "aws_security_group_rule" "cluster_egress_node" {
  description              = "Allow cluster control plane to communicate with worker nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

# -------------------------------------------------------------------------
# cluster_egress_node_https 삭제됨
# -------------------------------------------------------------------------
# cluster_egress_node에서 이미 모든 트래픽(protocol="-1")을 허용하므로
# 443 포트만 허용하는 별도 규칙은 중복되어 삭제함
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Management Instance → Control Plane API (443)
# -------------------------------------------------------------------------
# Mgmt 인스턴스에서 kubectl로 클러스터 관리
#
# count 조건 설명:
#   var.mgmt_security_group_id != null ? 1 : 0  → Plan 시점 에러 발생
#   var.enable_mgmt_sg_rule ? 1 : 0             → Boolean으로 Plan 시점에 값 확정
# -------------------------------------------------------------------------
resource "aws_security_group_rule" "cluster_ingress_mgmt_https" {
  count = var.enable_mgmt_sg_rule ? 1 : 0

  description              = "Allow Management Instance to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = var.mgmt_security_group_id
}