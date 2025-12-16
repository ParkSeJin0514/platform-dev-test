# ============================================================================
# RDS 모듈 - variables.tf
# ============================================================================
# RDS MySQL 인스턴스 생성에 필요한 변수 정의
# ============================================================================

# ===================================
# 필수 변수
# ===================================

variable "identifier" {
  description = "RDS 인스턴스 식별자 (AWS 콘솔에서 표시되는 이름)"
  type        = string
}

variable "vpc_id" {
  description = "RDS를 배치할 VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "RDS Subnet Group에 포함될 서브넷 ID 리스트 (최소 2개 AZ 필요)"
  type        = list(string)
}

# ===================================
# 데이터베이스 설정
# ===================================

variable "engine" {
  description = "데이터베이스 엔진 (mysql, postgres 등)"
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "데이터베이스 엔진 버전"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스 (예: db.t3.micro, db.t3.small)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "할당할 스토리지 크기 (GB)"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "allocated_storage는 20GB 이상 65536GB 이하여야 합니다."
  }
}

variable "max_allocated_storage" {
  description = "Auto Scaling 최대 스토리지 크기 (GB). 0이면 Auto Scaling 비활성화"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "스토리지 타입 (gp2, gp3, io1)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1"], var.storage_type)
    error_message = "storage_type은 gp2, gp3, io1 중 하나여야 합니다."
  }
}

variable "storage_encrypted" {
  description = "스토리지 암호화 여부"
  type        = bool
  default     = true
}

# ===================================
# 인증 정보
# ===================================

variable "db_name" {
  description = "생성할 데이터베이스 이름"
  type        = string
  default     = "petclinic"
}

variable "username" {
  description = "마스터 사용자 이름"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "마스터 사용자 비밀번호 (8자 이상)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.password) >= 8
    error_message = "password는 8자 이상이어야 합니다."
  }
}

# ===================================
# 네트워크 설정
# ===================================

variable "port" {
  description = "데이터베이스 포트"
  type        = number
  default     = 3306
}

variable "publicly_accessible" {
  description = "퍼블릭 접근 허용 여부 (보안상 false 권장)"
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "Multi-AZ 배포 여부 (고가용성)"
  type        = bool
  default     = false
}

# ===================================
# 접근 허용 설정
# ===================================

variable "allowed_security_group_ids" {
  description = "RDS 접근을 허용할 Security Group ID 리스트"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "RDS 접근을 허용할 CIDR 블록 리스트"
  type        = list(string)
  default     = []
}

# ===================================
# 삭제 보호
# ===================================

variable "deletion_protection" {
  description = "삭제 보호 활성화 여부 (프로덕션에서는 true 권장)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "삭제 시 최종 스냅샷 생략 여부"
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "최종 스냅샷 이름 (skip_final_snapshot=false일 때 필수)"
  type        = string
  default     = null
}

# ===================================
# 파라미터 그룹
# ===================================

variable "parameter_group_family" {
  description = "파라미터 그룹 패밀리 (예: mysql8.0)"
  type        = string
  default     = "mysql8.0"
}

variable "parameters" {
  description = "커스텀 파라미터 리스트"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

# ===================================
# 태그
# ===================================

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default     = {}
}