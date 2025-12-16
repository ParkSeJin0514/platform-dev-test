# ============================================================================
# RDS 모듈 - outputs.tf
# ============================================================================
# RDS 인스턴스 관련 정보를 외부로 출력
# 다른 모듈이나 루트 모듈에서 참조할 수 있습니다.
# ============================================================================

# ===================================
# 연결 정보
# ===================================

output "endpoint" {
  description = "RDS 인스턴스 엔드포인트 (host:port 형식)"
  value       = aws_db_instance.db_instance.endpoint
}

output "address" {
  description = "RDS 인스턴스 호스트명 (포트 제외)"
  value       = aws_db_instance.db_instance.address
}

output "port" {
  description = "RDS 인스턴스 포트"
  value       = aws_db_instance.db_instance.port
}

# Kubernetes Secret 또는 ConfigMap 생성에 유용
output "connection_string" {
  description = "JDBC 연결 문자열 (Spring Boot용)"
  value       = "jdbc:mysql://${aws_db_instance.db_instance.endpoint}/${var.db_name}?useSSL=true&requireSSL=true"
}

# ===================================
# 인스턴스 정보
# ===================================

output "id" {
  description = "RDS 인스턴스 ID"
  value       = aws_db_instance.db_instance.id
}

output "arn" {
  description = "RDS 인스턴스 ARN"
  value       = aws_db_instance.db_instance.arn
}

output "identifier" {
  description = "RDS 인스턴스 식별자"
  value       = aws_db_instance.db_instance.identifier
}

output "resource_id" {
  description = "RDS 인스턴스 리소스 ID (Performance Insights 등에서 사용)"
  value       = aws_db_instance.db_instance.resource_id
}

output "status" {
  description = "RDS 인스턴스 상태"
  value       = aws_db_instance.db_instance.status
}

# ===================================
# 데이터베이스 정보
# ===================================

output "db_name" {
  description = "생성된 데이터베이스 이름"
  value       = aws_db_instance.db_instance.db_name
}

output "username" {
  description = "마스터 사용자 이름"
  value       = aws_db_instance.db_instance.username
  sensitive   = true
}

output "engine" {
  description = "데이터베이스 엔진"
  value       = aws_db_instance.db_instance.engine
}

output "engine_version_actual" {
  description = "실제 설치된 데이터베이스 엔진 버전"
  value       = aws_db_instance.db_instance.engine_version_actual
}

# ===================================
# 네트워크 정보
# ===================================

output "availability_zone" {
  description = "RDS 인스턴스가 배치된 가용영역"
  value       = aws_db_instance.db_instance.availability_zone
}

output "security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "subnet_group_name" {
  description = "DB Subnet Group 이름"
  value       = aws_db_subnet_group.db_subnet.name
}

output "subnet_group_arn" {
  description = "DB Subnet Group ARN"
  value       = aws_db_subnet_group.db_subnet.arn
}

# ===================================
# 파라미터 그룹 정보
# ===================================

output "parameter_group_name" {
  description = "DB Parameter Group 이름"
  value       = aws_db_parameter_group.db_para.name
}

output "parameter_group_arn" {
  description = "DB Parameter Group ARN"
  value       = aws_db_parameter_group.db_para.arn
}

# ===================================
# 스토리지 정보
# ===================================

output "allocated_storage" {
  description = "할당된 스토리지 크기 (GB)"
  value       = aws_db_instance.db_instance.allocated_storage
}

output "storage_type" {
  description = "스토리지 타입"
  value       = aws_db_instance.db_instance.storage_type
}

output "storage_encrypted" {
  description = "스토리지 암호화 여부"
  value       = aws_db_instance.db_instance.storage_encrypted
}