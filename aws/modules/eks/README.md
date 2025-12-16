# EKS Module

EKS 클러스터와 Managed Node Group을 생성합니다.

## 📋 생성되는 리소스

| 리소스 | 수량 | 설명 |
|--------|------|------|
| EKS Cluster | 1 | Kubernetes Control Plane |
| Managed Node Group | 1 | Worker Node 그룹 |
| Launch Template | 1 | Worker Node 설정 (Ubuntu 24.04) |
| Security Group | 2 | Cluster SG, Node SG |
| IAM Role | 2 | Cluster Role, Node Role |

---

## ✨ 주요 기능

- **Ubuntu 24.04 EKS AMI**: SSM Parameter Store에서 자동 조회
- **IMDSv2 강제**: SSRF 공격 방지
- **EBS 암호화**: 볼륨 자동 암호화
- **롤링 업데이트**: max_unavailable_percentage 설정

---

## 🛡️ Security Group 규칙

| Source | Destination | Port | 설명 |
|--------|-------------|------|------|
| Node SG | Cluster SG | 443 | Worker → API Server |
| Cluster SG | Node SG | 1025-65535 | Control Plane → Worker |
| Node SG | Node SG | All | Worker 간 통신 |
| Mgmt SG | Cluster SG | 443 | Mgmt → API Server |

---

## 🚀 사용 방법

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name    = "petclinic-kr-eks"
  cluster_version = "1.33"
  vpc_id          = module.network.vpc_id

  control_plane_subnet_ids = concat(
    module.network.public_subnet_id,
    module.network.private_eks_subnet_id
  )
  worker_subnet_ids = module.network.private_eks_subnet_id

  node_group_name = "petclinic-kr-workers"
  instance_types  = ["t3.medium"]
  desired_size    = 3
  max_size        = 6
  min_size        = 3

  enable_mgmt_sg_rule    = true
  mgmt_security_group_id = module.ec2.mgmt_security_group_id

  kubelet_extra_args = "--max-pods=110"
}
```

---

## 📤 출력값

| 이름 | 설명 |
|------|------|
| `cluster_id` | 클러스터 이름 |
| `cluster_endpoint` | API 서버 엔드포인트 |
| `cluster_certificate_authority_data` | CA 인증서 (Base64) |
| `node_iam_role_arn` | 노드 IAM Role ARN |
| `node_security_group_id` | 노드 SG ID |

---

## 🔐 IAM 정책

### Cluster Role

- AmazonEKSClusterPolicy
- AmazonEKSVPCResourceController

### Node Role

- AmazonEKSWorkerNodePolicy
- AmazonEKS_CNI_Policy
- AmazonEC2ContainerRegistryReadOnly
- AmazonSSMManagedInstanceCore
