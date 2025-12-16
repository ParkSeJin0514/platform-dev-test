# EC2 Module

Bastion Host와 Management 인스턴스를 생성합니다.

## 📋 생성되는 리소스

| 리소스 | 수량 | 설명 |
|--------|------|------|
| Security Group | 2 | Bastion SG, Mgmt SG |
| EC2 Instance | 2 | Bastion, Mgmt |
| Elastic IP | 1 | Bastion용 고정 IP |

---

## 🔐 접근 흐름

```
인터넷 → Bastion (Public) → Mgmt (Private) → EKS API
```

---

## 🛡️ Security Group 규칙

| Source | Destination | Port | 설명 |
|--------|-------------|------|------|
| 0.0.0.0/0 | Bastion SG | 22 | SSH 접근 |
| Bastion SG | Mgmt SG | 22 | Bastion → Mgmt |

---

## 🚀 사용 방법

```hcl
module "ec2" {
  source = "./modules/ec2"

  project_name = "petclinic-kr"
  vpc_id       = module.network.vpc_id
  ami          = "ami-xxx"
  key_name     = "test"

  bastion_instance_type = "t3.micro"
  public_subnet_id      = module.network.public_subnet_id[0]

  mgmt_instance_type        = "t3.small"
  private_subnet_id         = module.network.private_mgmt_subnet_id[0]
  mgmt_iam_instance_profile = aws_iam_instance_profile.mgmt.name

  region       = "ap-northeast-2"
  cluster_name = "petclinic-kr-eks"

  # NAT Gateway 의존성 (인터넷 접근 보장)
  nat_gateway_ids = module.network.nat_gateway_ids
}
```

---

## 📤 출력값

| 이름 | 설명 |
|------|------|
| `bastion_instance_id` | Bastion 인스턴스 ID |
| `bastion_public_ip` | Bastion Elastic IP |
| `mgmt_instance_id` | Mgmt 인스턴스 ID |
| `mgmt_private_ip` | Mgmt Private IP |
| `mgmt_security_group_id` | Mgmt SG ID (EKS 모듈로 전달) |

---

## ⚙️ Mgmt 인스턴스 자동 설정

`userdata.tftpl` 스크립트가 부팅 시 자동 실행:

1. 네트워크 연결 대기 (NAT Gateway 라우팅 전파)
2. 기본 패키지 설치 (mysql-client, curl, unzip, jq)
3. **Docker 설치** (Docker CE, Docker Compose 플러그인)
4. AWS CLI v2 설치
5. eksctl 설치
6. kubectl 설치
7. EKS 클러스터 ACTIVE 대기
8. kubeconfig 자동 설정
9. **ECR 로그인 헬퍼 스크립트 생성** (`/usr/local/bin/ecr-login`)

---

## 🐳 Docker & ECR 사용

Mgmt 인스턴스에서 Docker 및 ECR 사용 가능:

```bash
# Docker 확인
docker --version
docker ps

# ECR 로그인 (헬퍼 스크립트)
ecr-login

# 이미지 빌드 및 푸시
docker build -t my-app .
docker tag my-app:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest
```

---

## 📝 로그 확인

```bash
sudo cat /var/log/userdata.log
```
