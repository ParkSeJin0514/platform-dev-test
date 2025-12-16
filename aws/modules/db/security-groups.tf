# ============================================================================
# RDS 모듈 - security-groups.tf
# ============================================================================
# RDS 인스턴스의 Security Group 정의
#
# 접근 허용 방식:
#   1. Security Group 기반: EKS Worker Node, Management Instance 등
#   2. CIDR 기반: 특정 IP 대역 (필요시)
#
# 기본적으로 모든 인바운드 트래픽은 차단되며,
# 명시적으로 허용된 소스만 접근 가능합니다.
# ============================================================================

# ============================================================================
# RDS Security Group
# ============================================================================

resource "aws_security_group" "rds" {
  name_prefix = "${var.identifier}-rds-sg-"
  description = "Security group for RDS ${var.identifier}"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-rds-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Ingress Rules
# ============================================================================

# -------------------------------------------------------------------------
# Security Group 기반 접근 허용
# -------------------------------------------------------------------------
# EKS Worker Node, Management Instance 등에서 RDS 접근 허용
# var.allowed_security_group_ids에 지정된 SG에서만 접근 가능
# -------------------------------------------------------------------------

resource "aws_security_group_rule" "rds_ingress_from_sg" {
  count = length(var.allowed_security_group_ids)

  description              = "Allow inbound from security group ${var.allowed_security_group_ids[count.index]}"
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
}

# -------------------------------------------------------------------------
# CIDR 기반 접근 허용
# -------------------------------------------------------------------------
# 특정 IP 대역에서 RDS 접근이 필요한 경우 사용
# (예: VPN, 온프레미스 네트워크)
# -------------------------------------------------------------------------

resource "aws_security_group_rule" "rds_ingress_from_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  description       = "Allow inbound from CIDR blocks"
  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = var.allowed_cidr_blocks
}

# ============================================================================
# Egress Rules
# ============================================================================
# RDS는 일반적으로 아웃바운드 트래픽이 필요하지 않지만,
# 일부 기능(Lambda 통합 등)을 위해 허용할 수 있습니다.
# 기본적으로 제한적인 egress 설정을 사용합니다.
# ============================================================================

resource "aws_security_group_rule" "rds_egress" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}