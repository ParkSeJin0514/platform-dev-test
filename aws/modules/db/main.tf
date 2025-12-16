# ============================================================================
# RDS 모듈 - main.tf
# ============================================================================
# RDS MySQL 인스턴스 및 관련 리소스 생성
#
# 생성되는 리소스:
#   - DB Subnet Group: RDS가 배치될 서브넷 그룹
#   - DB Parameter Group: MySQL 파라미터 설정
#   - DB Instance: RDS MySQL 인스턴스
#
# 네트워크 구성:
#   - Private DB Subnet에 배치 (인터넷에서 직접 접근 불가)
#   - Security Group으로 접근 제어
# ============================================================================

# ============================================================================
# DB Subnet Group
# ============================================================================
# RDS 인스턴스가 배치될 서브넷을 정의
# Multi-AZ 배포를 위해 최소 2개 AZ의 서브넷 필요
# ============================================================================

resource "aws_db_subnet_group" "db_subnet" {
  name        = "${var.identifier}-subnet-group"
  description = "Subnet group for RDS ${var.identifier}"
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-subnet-group"
    }
  )
}

# ============================================================================
# DB Parameter Group
# ============================================================================
# MySQL 파라미터 커스터마이징
# 기본 설정: 한국어 지원을 위한 UTF-8 설정 포함
# ============================================================================

resource "aws_db_parameter_group" "db_para" {
  name        = "${var.identifier}-params"
  family      = var.parameter_group_family
  description = "Parameter group for RDS ${var.identifier}"

  # 기본 파라미터: 한국어/UTF-8 지원
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "collation_connection"
    value = "utf8mb4_unicode_ci"
  }

  # 타임존 설정 (한국 시간)
  parameter {
    name  = "time_zone"
    value = "Asia/Seoul"
  }

  # 사용자 정의 파라미터
  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-params"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# RDS Instance
# ============================================================================
# MySQL RDS 인스턴스 생성
# Private Subnet에 배치되어 VPC 내부에서만 접근 가능
# ============================================================================

resource "aws_db_instance" "db_instance" {
  # 기본 식별 정보
  identifier = var.identifier

  # 엔진 설정
  engine         = var.engine
  engine_version = var.engine_version

  # 인스턴스 사양
  instance_class = var.instance_class

  # 스토리지 설정
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted

  # 데이터베이스 설정
  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = var.port

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  # 파라미터 그룹
  parameter_group_name = aws_db_parameter_group.db_para.name

  # 삭제 관련 설정
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier

  # 성능 인사이트 (무료 티어에서는 비활성화)
  performance_insights_enabled = false

  # 태그
  tags = merge(
    var.tags,
    {
      Name = var.identifier
    }
  )
}