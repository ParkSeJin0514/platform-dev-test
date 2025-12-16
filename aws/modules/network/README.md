# Network Module

VPC와 관련된 모든 네트워크 리소스를 생성합니다.

## 📋 생성되는 리소스

| 리소스 | 수량 | 설명 |
|--------|------|------|
| VPC | 1 | 10.0.0.0/16 |
| Internet Gateway | 1 | Public Subnet 인터넷 연결 |
| Subnet | 8 | 4종류 × 2 AZ |
| NAT Gateway | 2 | AZ당 1개 (고가용성) |
| Elastic IP | 2 | NAT Gateway용 |
| Route Table | 3 | Public 1개 + Private 2개 (AZ별) |

---

## 🌐 서브넷 구성

| 종류 | AZ-a | AZ-c | 용도 |
|------|------|------|------|
| Public | 10.0.10.0/24 | 10.0.20.0/24 | Bastion, NAT, ALB |
| Private Mgmt | 10.0.50.0/24 | 10.0.60.0/24 | Management Instance |
| Private EKS | 10.0.100.0/24 | 10.0.110.0/24 | EKS Worker Nodes |
| Private DB | 10.0.150.0/24 | 10.0.160.0/24 | RDS 등 |

---

## 🚀 사용 방법

```hcl
module "network" {
  source = "./modules/network"

  vpc_cidr                  = "10.0.0.0/16"
  az                        = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnet_cidrs       = ["10.0.10.0/24", "10.0.20.0/24"]
  private_mgmt_subnet_cidrs = ["10.0.50.0/24", "10.0.60.0/24"]
  private_eks_subnet_cidrs  = ["10.0.100.0/24", "10.0.110.0/24"]
  private_db_subnet_cidrs   = ["10.0.150.0/24", "10.0.160.0/24"]
  project_name              = "petclinic-kr"
}
```

---

## 📤 출력값

| 이름 | 설명 |
|------|------|
| `vpc_id` | VPC ID |
| `public_subnet_id` | Public Subnet ID 리스트 |
| `private_mgmt_subnet_id` | Mgmt Subnet ID 리스트 |
| `private_eks_subnet_id` | EKS Subnet ID 리스트 |
| `private_db_subnet_id` | DB Subnet ID 리스트 |
| `nat_gateway_ids` | NAT Gateway ID Map |
| `route_table_ids` | Route Table ID Map |

---

## 🔀 라우팅 구조

```
Public Subnet → Internet Gateway → 인터넷
Private Subnet → NAT Gateway → Internet Gateway → 인터넷
```