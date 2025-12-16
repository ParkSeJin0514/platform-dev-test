# ============================================================================
# EC2 모듈 - main.tf
# ============================================================================
# Bastion Host와 Management 인스턴스를 생성합니다.
#
# 접근 흐름:
#   인터넷 → Bastion (Public) → Mgmt (Private) → EKS API
#
# 생성 리소스:
#   - Security Group 2개 (Bastion SG, Mgmt SG)
#   - EC2 Instance 2개 (Bastion, Mgmt)
#   - Elastic IP 1개 (Bastion용)
# ============================================================================

# ============================================================================
# 1. Bastion Security Group
# ============================================================================
# Bastion Host용 Security Group
# 인터넷에서 SSH(22) 접근 허용
# ============================================================================

resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.project_name}-sg-bastion"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-sg-bastion"
  }
}

# Inbound Rule: SSH (0.0.0.0/0 → 22)
# 모든 IP에서 SSH 접근 허용 (운영 환경에서는 IP 제한 권장)
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion_sg.id

  cidr_ipv4   = "0.0.0.0/0" # 모든 IP 허용
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

# Outbound Rule: All Traffic
# 모든 아웃바운드 트래픽 허용 (패키지 설치, SSH 등)
resource "aws_vpc_security_group_egress_rule" "bastion_outbound" {
  security_group_id = aws_security_group.bastion_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # -1 = 모든 프로토콜
}

# ============================================================================
# 2. Mgmt Security Group
# ============================================================================
# Management Instance용 Security Group
# Bastion SG에서만 SSH 접근 허용 (보안 강화)
# ============================================================================

resource "aws_security_group" "mgmt_sg" {
  name_prefix = "${var.project_name}-sg-mgmt"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-sg-mgmt"
  }
}

# Inbound Rule: SSH from Bastion SG only
# CIDR 대신 Security Group ID로 참조 → Bastion IP 변경에도 자동 대응
resource "aws_vpc_security_group_ingress_rule" "mgmt_ssh_from_bastion" {
  security_group_id = aws_security_group.mgmt_sg.id

  # referenced_security_group_id: 이 SG를 가진 인스턴스에서만 접근 허용
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

# Outbound Rule: All Traffic
# NAT Gateway를 통해 인터넷 접근 (패키지 설치, EKS API 통신 등)
resource "aws_vpc_security_group_egress_rule" "mgmt_outbound" {
  security_group_id = aws_security_group.mgmt_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# ============================================================================
# 3. Bastion Instance
# ============================================================================
# Public Subnet에 배치되어 외부에서 SSH 접근 가능
# Elastic IP를 할당하여 인스턴스 재시작해도 동일 IP 유지
# ============================================================================

resource "aws_instance" "bastion" {
  ami           = var.ami
  instance_type = var.bastion_instance_type # 예: t3.micro

  # Public Subnet에 배치 → 인터넷에서 직접 접근 가능
  subnet_id = var.public_subnet_id

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_name

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# Elastic IP - 인스턴스 재시작해도 동일한 Public IP 유지
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip-bastion"
  }
}

# ============================================================================
# 4. Mgmt Instance
# ============================================================================
# Private Subnet에 배치 (인터넷에서 직접 접근 불가)
# Bastion을 통해서만 SSH 접근 가능
#
# userdata.tftpl 스크립트가 부팅 시 자동 실행:
#   1. AWS CLI v2 설치
#   2. eksctl 설치
#   3. kubectl 설치
#   4. EKS 클러스터 준비 대기 후 kubeconfig 자동 설정
# ============================================================================

resource "aws_instance" "mgmt" {
  ami           = var.ami
  instance_type = var.mgmt_instance_type # 예: t3.small

  # Private Subnet에 배치 → Bastion 통해서만 접근
  subnet_id = var.private_subnet_id

  vpc_security_group_ids = [aws_security_group.mgmt_sg.id]
  key_name               = var.key_name

  # IAM Instance Profile 연결
  # EKS 관리 권한, EFS 접근 권한 등이 포함된 역할
  iam_instance_profile = var.mgmt_iam_instance_profile

  # Root Block Device - 디스크 크기 설정
  root_block_device {
    volume_size = 30    # 30GB
    volume_type = "gp3" # 최신 SSD 타입 (gp2보다 성능/비용 우수)
  }

  # User Data - 부팅 시 실행되는 초기화 스크립트
  # templatefile(): 변수를 주입하여 스크립트 생성
  # base64encode(): AWS가 요구하는 Base64 인코딩
  user_data_base64 = base64encode(
    templatefile("${path.module}/userdata.tftpl", {
      region       = var.region       # kubeconfig 설정에 사용
      cluster_name = var.cluster_name # kubeconfig 설정에 사용
    })
  )

  tags = {
    Name = "${var.project_name}-mgmt-eks"
  }
}