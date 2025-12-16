# ============================================================================
# Compute Module - variables.tf
# ============================================================================

# ============================================================================
# Foundation에서 받아오는 변수
# ============================================================================
variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public Subnet IDs"
}

variable "private_eks_subnet_ids" {
  type        = list(string)
  description = "Private EKS Subnet IDs"
}

variable "private_mgmt_subnet_ids" {
  type        = list(string)
  description = "Private Management Subnet IDs"
}

variable "private_db_subnet_ids" {
  type        = list(string)
  description = "Private DB Subnet IDs"
}

variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "region" {
  type        = string
  description = "AWS 리전"
}

# ============================================================================
# EC2 변수
# ============================================================================
variable "bastion_instance_type" {
  type        = string
  description = "Bastion Host 인스턴스 타입"
  default     = "t3.micro"
}

variable "mgmt_instance_type" {
  type        = string
  description = "Management 인스턴스 타입"
  default     = "t3.small"
}

variable "key_name" {
  type        = string
  description = "SSH Key Pair 이름"
}

variable "ubuntu_ami_filters" {
  type = list(object({
    name   = string
    values = list(string)
  }))
  description = "Ubuntu AMI 검색 필터"
}

# ============================================================================
# EKS 변수
# ============================================================================
variable "eks_version" {
  type        = string
  description = "EKS Kubernetes 버전"
  default     = "1.31"
}

variable "eks_instance_types" {
  type        = list(string)
  description = "Worker Node 인스턴스 타입"
  default     = ["t3.medium"]
}

variable "eks_capacity_type" {
  type        = string
  description = "용량 타입: ON_DEMAND 또는 SPOT"
  default     = "ON_DEMAND"
}

variable "eks_disk_size" {
  type        = number
  description = "Worker Node EBS 볼륨 크기 (GB)"
  default     = 50
}

variable "eks_desired_size" {
  type        = number
  description = "원하는 Worker Node 수"
  default     = 2
}

variable "eks_max_size" {
  type        = number
  description = "최대 Worker Node 수"
  default     = 4
}

variable "eks_min_size" {
  type        = number
  description = "최소 Worker Node 수"
  default     = 1
}

variable "eks_max_unavailable_percentage" {
  type        = number
  description = "업데이트 시 동시 중단 가능한 노드 비율"
  default     = 33
}

variable "eks_kubelet_extra_args" {
  type        = string
  description = "kubelet 추가 인자"
  default     = "--max-pods=110"
}

variable "eks_node_labels" {
  type        = map(string)
  description = "Worker Node 레이블"
  default     = {}
}

variable "eks_node_taints" {
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  description = "Worker Node Taint"
  default     = []
}

variable "eks_cluster_log_types" {
  type        = list(string)
  description = "CloudWatch 로그 유형"
  default     = ["api", "audit", "authenticator"]
}

# ============================================================================
# RDS 변수
# ============================================================================
variable "db_engine" {
  type        = string
  description = "데이터베이스 엔진"
  default     = "mysql"
}

variable "db_engine_version" {
  type        = string
  description = "데이터베이스 엔진 버전"
  default     = "8.0"
}

variable "db_parameter_group_family" {
  type        = string
  description = "파라미터 그룹 패밀리"
  default     = "mysql8.0"
}

variable "db_instance_class" {
  type        = string
  description = "RDS 인스턴스 클래스"
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "할당 스토리지 크기 (GB)"
  default     = 20
}

variable "db_max_allocated_storage" {
  type        = number
  description = "Auto Scaling 최대 스토리지 (GB)"
  default     = 100
}

variable "db_storage_type" {
  type        = string
  description = "스토리지 타입"
  default     = "gp3"
}

variable "db_storage_encrypted" {
  type        = bool
  description = "스토리지 암호화"
  default     = true
}

variable "db_name" {
  type        = string
  description = "데이터베이스 이름"
  default     = "petclinic"
}

variable "db_username" {
  type        = string
  description = "마스터 사용자"
  default     = "admin"
}

variable "db_password" {
  type        = string
  description = "마스터 비밀번호"
  sensitive   = true
}

variable "db_port" {
  type        = number
  description = "데이터베이스 포트"
  default     = 3306
}

variable "db_multi_az" {
  type        = bool
  description = "Multi-AZ 배포"
  default     = false
}

variable "db_deletion_protection" {
  type        = bool
  description = "삭제 보호"
  default     = false
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "최종 스냅샷 생략"
  default     = true
}

variable "ssh_public_key" {
  description = "SSH Public Key"
  type        = string
}

variable "github_oidc_role_arn" {
  description = "GitHub Actions OIDC Role ARN for EKS access"
  type        = string
  default     = "arn:aws:iam::946775837287:role/github-actions-terraform"
}