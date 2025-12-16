# ============================================================================
# Network 모듈 - main.tf
# ============================================================================
# VPC와 관련된 모든 네트워크 리소스를 생성합니다.
# - VPC, Internet Gateway
# - Subnet (4종류 × AZ 개수)
# - NAT Gateway (AZ당 1개)
# - Route Table (Public 1개 + Private AZ별)
# ============================================================================

# ============================================================================
# 0. 가용영역 자동 조회
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# 1. VPC 및 Internet Gateway
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr # 예: 10.0.0.0/16

  # DNS 설정 - EKS에서 필수
  # enable_dns_hostnames: EC2 인스턴스에 DNS 호스트네임 할당
  # enable_dns_support: VPC 내 DNS 쿼리 지원
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

# Internet Gateway - Public Subnet의 인터넷 연결 담당
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ============================================================================
# 2. Locals - 서브넷 자동 CIDR 계산
# ============================================================================
# az_count만으로 서브넷 CIDR을 자동 계산합니다.
# 패턴: bastion=10, mgmt=50, eks=100, db=150 시작
#       AZ별 +10씩 증가
# ============================================================================

locals {
  # 사용할 AZ 선택 (az_count 개수만큼)
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # AZ 간격 (A=0, B=1, C=2이면 각각 +0, +10, +20)
  az_offset = 10

  # -------------------------------------------------------------------------
  # 서브넷 종류별 설정 정의
  # -------------------------------------------------------------------------
  # start_index: CIDR 계산 시작점
  # tags: Kubernetes 관련 태그 (ALB Controller가 서브넷을 자동 인식)
  # -------------------------------------------------------------------------
  subnet_plan = {
    "bastion" = {
      start_index = 10
      public      = true
      tags = {
        # ALB Controller가 인터넷 facing LB를 생성할 서브넷으로 인식
        "kubernetes.io/role/elb"                        = "1"
        "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
      }
    }
    "mgmt" = {
      start_index = 50
      public      = false
      tags        = {} # Kubernetes 태그 불필요
    }
    "eks" = {
      start_index = 100
      public      = false
      tags = {
        # ALB Controller가 Internal LB를 생성할 서브넷으로 인식
        "kubernetes.io/role/internal-elb"               = "1"
        "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
      }
    }
    "db" = {
      start_index = 150
      public      = false
      tags        = {} # Kubernetes 태그 불필요
    }
  }

  # -------------------------------------------------------------------------
  # Flatten: 모든 서브넷을 1차원 리스트로 평면화
  # -------------------------------------------------------------------------
  # 출력 예시 (az_count=2):
  #   [ { type="bastion", cidr="10.0.10.0/24", az="ap-northeast-2a", ... },
  #     { type="bastion", cidr="10.0.20.0/24", az="ap-northeast-2b", ... },
  #     { type="mgmt", cidr="10.0.50.0/24", az="ap-northeast-2a", ... }, ... ]
  # -------------------------------------------------------------------------
  subnet_list = flatten([
    for type, config in local.subnet_plan : [
      for idx, az in local.azs : {
        type    = type
        cidr    = cidrsubnet(var.vpc_cidr, 8, config.start_index + (idx * local.az_offset))
        az      = az
        suffix  = substr(az, -2, 2) # "2a", "2b" 추출
        az_char = substr(az, -1, 1) # "a", "b" 추출
        public  = config.public
        tags    = config.tags
      }
    ]
  ])

  # -------------------------------------------------------------------------
  # List를 Map으로 변환 (for_each용)
  # -------------------------------------------------------------------------
  # 결과 예시:
  #   { "bastion_2a" = {...}, "bastion_2b" = {...},
  #     "eks_2a" = {...}, "eks_2b" = {...}, ... }
  # -------------------------------------------------------------------------
  subnets = {
    for item in local.subnet_list :
    "${item.type}_${item.suffix}" => item
  }
}

# ============================================================================
# 3. Subnet 생성
# ============================================================================

resource "aws_subnet" "subnet" {
  for_each = local.subnets # Map의 각 항목에 대해 서브넷 생성

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  # Public Subnet만 Public IP 자동 할당
  map_public_ip_on_launch = each.value.public

  tags = merge(
    each.value.tags, # Kubernetes 태그
    {
      # 이름 예시: petclinic-kr-bastion-a, petclinic-kr-eks-b
      Name = "${var.project_name}-${each.value.type}-${each.value.az_char}"
    }
  )
}

# ============================================================================
# 4. NAT Gateway 및 Elastic IP
# ============================================================================
# 각 AZ에 NAT Gateway를 배치하여 고가용성 확보
# Private Subnet의 인스턴스가 인터넷에 접근할 때 사용
# ============================================================================

# NAT Gateway용 Elastic IP (AZ별)
resource "aws_eip" "eip" {
  for_each = toset(local.azs) # 리스트를 Set으로 변환

  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip-${substr(each.key, -1, 1)}" }
}

# NAT Gateway (AZ별)
resource "aws_nat_gateway" "nat" {
  for_each = toset(local.azs)

  allocation_id = aws_eip.eip[each.key].id

  # NAT Gateway는 반드시 Public(bastion) Subnet에 배치
  # 키 변환: "ap-northeast-2a" → "bastion_2a"
  subnet_id = aws_subnet.subnet["bastion_${substr(each.key, -2, 2)}"].id

  tags = { Name = "${var.project_name}-nat-${substr(each.key, -1, 1)}" }

  # IGW가 먼저 생성되어야 NAT Gateway 생성 가능
  depends_on = [aws_internet_gateway.igw]
}

# ============================================================================
# 5. Route Table
# ============================================================================

# Public Route Table (1개 - 모든 Public Subnet 공용)
# 인터넷 트래픽을 Internet Gateway로 라우팅
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                 # 모든 외부 트래픽
    gateway_id = aws_internet_gateway.igw.id # → IGW로
  }

  tags = { Name = "${var.project_name}-rt-public" }
}

# Private Route Table (AZ별 생성)
# 인터넷 트래픽을 해당 AZ의 NAT Gateway로 라우팅
resource "aws_route_table" "private_rt" {
  for_each = toset(local.azs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"                      # 모든 외부 트래픽
    nat_gateway_id = aws_nat_gateway.nat[each.key].id # → 해당 AZ의 NAT로
  }

  tags = { Name = "${var.project_name}-rt-private-${substr(each.key, -1, 1)}" }
}

# ============================================================================
# 6. Route Table Association
# ============================================================================
# 각 서브넷을 적절한 Route Table에 연결
# ============================================================================

resource "aws_route_table_association" "rt_asso" {
  for_each = aws_subnet.subnet # 모든 서브넷 순회

  subnet_id = each.value.id

  # 삼항 연산자로 Public/Private 구분
  # Public(bastion) Subnet → Public RT
  # Private Subnet → 해당 AZ의 Private RT
  route_table_id = local.subnets[each.key].public ? aws_route_table.public_rt.id : aws_route_table.private_rt[each.value.availability_zone].id
}