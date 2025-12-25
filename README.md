# Platform Infrastructure (Multi-Cloud: AWS / GCP)

AWS Primary + GCP DR 환경을 위한 Terraform/Terragrunt IaC 코드

## 아키텍처 개요

```
┌─────────────────────────────────┬───────────────────────────────────┐
│         AWS (Primary)           │          GCP (DR/Secondary)       │
├─────────────────────────────────┼───────────────────────────────────┤
│  VPC (10.0.0.0/16)              │  VPC (172.16.0.0/16)              │
│  EKS + Managed Node Group       │  GKE Standard + Node Pool         │
│  Karpenter (Auto Scaling)       │  Node Pool Autoscaling            │
│  ALB Controller                 │  GKE Ingress (GCE)                │
│  External Secrets (AWS SM)      │  External Secrets (GCP SM)        │
│  IRSA                           │  Workload Identity                │
│  RDS MySQL                      │  Cloud SQL MySQL (Private)        │
│  Bastion + Management VM        │  Bastion + Management VM          │
└─────────────────────────────────┴───────────────────────────────────┘
```

## 디렉토리 구조

```
platform-dev-last/
├── aws/                          # AWS Infrastructure
│   ├── terragrunt.hcl           # Root Terragrunt (S3 Backend)
│   ├── env.hcl                  # AWS 환경 변수 (⚠️ 민감정보는 환경변수로)
│   ├── keys/                    # SSH 키 파일
│   │   ├── test                 # Private Key (Git에서 제외 권장)
│   │   └── test.pub             # Public Key (EC2 Key Pair용)
│   ├── foundation/              # VPC, Subnet, NAT Gateway
│   ├── compute/                 # EKS, RDS, EC2, IAM Roles
│   ├── bootstrap/               # ArgoCD, aws-auth ConfigMap
│   └── modules/                 # 재사용 가능한 Terraform 모듈
│       ├── network/             # VPC, Subnet, Route Table
│       ├── eks/                 # EKS Cluster, Node Group, SG
│       ├── ec2/                 # Bastion, Management VM
│       ├── db/                  # RDS MySQL, Parameter Group, SG
│       ├── foundation/          # Foundation 통합 모듈
│       ├── compute/             # Compute 통합 모듈 (+ Karpenter IRSA)
│       └── bootstrap/           # ArgoCD Helm, Root Application
│
├── gcp/                          # GCP Infrastructure
│   ├── terragrunt.hcl           # Root Terragrunt (GCS Backend)
│   ├── env.hcl                  # GCP 환경 변수
│   ├── foundation/              # VPC, Subnet, Cloud NAT
│   ├── compute/                 # GKE, Cloud SQL, VMs
│   ├── bootstrap/               # ArgoCD
│   └── modules/                 # network, gke, cloudsql, vm 등
│
└── .github/workflows/
    ├── terraform-apply.yml      # Multi-Cloud Apply (수동)
    ├── terraform-destroy.yml    # Multi-Cloud Destroy (수동 + 승인)
    └── terraform-pr.yml         # PR 생성 시 Plan 실행
```

## Provider 버전

| Provider | AWS | GCP |
|----------|-----|-----|
| Terraform | `>= 1.0` | `>= 1.0` |
| AWS | `>= 6.24.0` | - |
| Google | - | `~> 5.0` |
| Kubernetes | `~> 2.23` | `~> 2.23` |
| Helm | `~> 2.11` | `~> 2.11` |

## 사전 요구사항

### AWS
- S3 Bucket (Terraform State): `petclinic-kr-tfstate`
- DynamoDB Table (State Lock): `petclinic-kr-tflock`
- GitHub Actions OIDC 설정
- Secrets:
  - `AWS_ROLE_ARN`: GitHub Actions가 Assume할 IAM Role
  - `TF_VAR_db_password`: RDS 비밀번호 (환경변수로 전달)
  - `SSH_PUBLIC_KEY`: EC2 Key Pair용 공개키 (또는 `aws/keys/test.pub` 사용)

### GCP
- GCS Bucket: `kdt2-final-project-t1-tfstate`
- Workload Identity Pool 및 Provider 설정

## 사용 방법

### GitHub Actions 실행

1. **Actions** 탭 → **Terraform Apply** 워크플로우 선택
2. **Run workflow** → 옵션 선택:
   - **Cloud**: `aws` 또는 `gcp`
   - **Layer**: `all`, `foundation`, `compute`, `bootstrap`

### 로컬 실행

```bash
# 환경 변수 설정 (필수)
export TF_VAR_db_password="your_secure_password"

# AWS
cd aws/foundation && terragrunt apply
cd ../compute && terragrunt apply
cd ../bootstrap && terragrunt apply

# GCP
cd gcp/foundation && terragrunt apply
cd ../compute && terragrunt apply
cd ../bootstrap && terragrunt apply
```

## 환경 변수 설정

### AWS (aws/env.hcl)

민감한 정보는 환경 변수로 관리합니다.

| 변수 | 설명 | 사용처 |
|-----|------|-------|
| `TF_VAR_db_password` | RDS MySQL 비밀번호 | GitHub Secrets → Actions |

```hcl
# env.hcl에서 환경 변수 참조
db_password = get_env("TF_VAR_db_password", "")
```

### SSH Key 설정

EC2 Key Pair는 `aws/keys/test.pub` 파일을 사용합니다.

```hcl
# compute/terragrunt.hcl
ssh_public_key = file("${get_repo_root()}/aws/keys/test.pub")
```

**주의**: Private Key (`aws/keys/test`)는 `.gitignore`에 추가하여 Git에서 제외할 것을 권장합니다.

## 레이어 설명

| Layer | AWS | GCP |
|-------|-----|-----|
| **Foundation** | VPC, Subnet, Regional NAT Gateway | VPC, Subnet, Cloud NAT |
| **Compute** | EKS, RDS, IAM Roles | GKE Standard, Cloud SQL, VMs |
| **Bootstrap** | ArgoCD | ArgoCD |

## AWS vs GCP 주요 차이점

| 항목 | AWS | GCP |
|------|-----|-----|
| Kubernetes | EKS + Managed Node | GKE Standard + Node Pool |
| Auto Scaling | Karpenter | Node Pool Autoscaling |
| Load Balancer | ALB Controller | GKE Ingress |
| IAM | IRSA | Workload Identity |
| Database | RDS MySQL | Cloud SQL MySQL |
| State Backend | S3 | GCS |

## Regional NAT Gateway (AWS)

AWS Provider 6.24.0부터 지원. 단일 NAT Gateway로 모든 AZ 커버.

| 항목 | Zonal (기존) | Regional (현재) |
|------|-------------|-----------------|
| NAT Gateway 개수 | AZ당 1개 | **1개** |
| Route Table | AZ별 Private RT | **단일 Private RT** |
| 비용 | NAT Gateway × AZ | **1개** |

## Slack 알림

| 워크플로우 | 시작 알림 | 완료 알림 |
|-----------|----------|----------|
| Terraform Apply | 시작 | 성공/실패 |
| Terraform Destroy | 승인 요청 | 성공/실패 |
| Terraform Plan (PR) | - | Plan 완료 |

## Destroy 승인 프로세스

인프라 삭제 전 **팀장 승인** 필요:

1. `destroy` 입력 확인
2. Slack 승인 요청 알림
3. GitHub Environment 승인 대기
4. Pre-Cleanup + Terraform Destroy
5. 완료 알림

### GitHub Environment 설정

Repository → Settings → Environments → `production` 생성 → Required reviewers 추가

## Pre-Cleanup (Destroy 전 정리)

### AWS

```
Karpenter Controller 중지 → NodePool 삭제 → EC2 종료 → ArgoCD Applications 정리
→ Ingress/LB Service 삭제 → ALB 강제 삭제 → Target Group 삭제 → Terraform Destroy
```

### GCP

```
ArgoCD Applications 정리 → Ingress 삭제 → LB 리소스 삭제 (역순)
→ NEG 삭제 → Firewall 삭제 → Cloud SQL 삭제 → VPC Peering 삭제 → Terraform Destroy
```

## GCP 특이사항

### Management VM 자동 설정
- kubectl, Docker, mysql-client 자동 설치
- GKE 인증 자동 설정 (`configure-kubectl` 명령어 제공)
- OS Login 사용자 지원

### GKE Standard + Node Pool
- 노드용 Service Account 자동 생성
- 오토스케일링: `min_node_count` ~ `max_node_count`
- Public Cluster 모드 (방화벽으로 보안 제어)

### Cloud SQL Private Access
- Private Service Connection 사용
- VPC 내부에서만 접근 가능

### Standalone NEG

Service에 NEG annotation 추가하여 GKE 재배포 후에도 동일한 NEG 이름 유지:

```yaml
annotations:
  cloud.google.com/neg: '{"exposed_ports": {"8080":{"name": "petclinic-api-gateway-neg"}}}'
```

## ArgoCD 접속 정보

```bash
# 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

## 트러블슈팅

### ArgoCD Auto-Sync 안됨
- **원인**: Application Controller 초기화 전 root-app 생성
- **해결**: `time_sleep` 30초 대기 후 root-app 생성

### Karpenter 노드 등록 실패
- **원인**: IAM Role/Policy 전파 전 노드 부트스트랩
- **해결**: `time_sleep` 30초 대기 후 EKS Access Entry 생성

### Karpenter 노드에서 DB 접근 불가
- **원인**: RDS SG에 Cluster SG 미등록 (Karpenter 노드는 Cluster SG 사용)
- **해결**: `cluster_security_group_id`를 RDS 허용 SG에 추가

### Terraform State와 AWS 리소스 불일치 (EntityAlreadyExists)
GitHub Actions에서 `EntityAlreadyExists` 오류 발생 시 AWS에 리소스가 존재하지만 Terraform State에 없는 상태.

**해결 방법**: 기존 AWS 리소스를 Terraform State로 Import

```bash
cd aws/compute

# IAM Role Import
terragrunt import 'module.eks.aws_iam_role.eks_cluster' "petclinic-kr-eks-cluster-role"
terragrunt import 'module.eks.aws_iam_role.eks_node' "petclinic-kr-eks-node-role"
terragrunt import 'module.ec2.aws_iam_role.bastion' "petclinic-kr-bastion-role"
terragrunt import 'module.ec2.aws_iam_role.mgmt' "petclinic-kr-mgmt-role"

# IAM Policy Import
terragrunt import 'aws_iam_policy.karpenter_controller' "arn:aws:iam::ACCOUNT_ID:policy/petclinic-kr-karpenter-controller"

# Instance Profile Import
terragrunt import 'module.ec2.aws_iam_instance_profile.bastion' "petclinic-kr-bastion-profile"
terragrunt import 'module.ec2.aws_iam_instance_profile.mgmt' "petclinic-kr-mgmt-profile"

# IRSA Role Import
terragrunt import 'aws_iam_role.alb_controller' "petclinic-kr-alb-controller"
terragrunt import 'aws_iam_role.efs_csi_driver' "petclinic-kr-efs-csi-driver"
terragrunt import 'aws_iam_role.external_secrets' "petclinic-kr-external-secrets"
terragrunt import 'aws_iam_role.karpenter_controller' "petclinic-kr-karpenter-controller"

# RDS Parameter Group Import
TF_VAR_db_password="your_password" terragrunt import 'module.db.aws_db_parameter_group.db_para' "petclinic-kr-db-params"

# Secrets Manager Import
terragrunt import 'module.db.aws_secretsmanager_secret.db_credentials' "petclinic-kr-db-credentials"
```

### Key Pair 충돌 (InvalidKeyPair.Duplicate)
AWS에 Key Pair가 있지만 State에 `public_key` 값 없이 Import된 경우.

**해결 방법**: State에서 제거 후 AWS에서 삭제하여 새로 생성

```bash
cd aws/compute

# State에서 제거
terragrunt state rm aws_key_pair.this

# AWS에서 삭제 (Terraform이 새로 생성하도록)
aws ec2 delete-key-pair --key-name petclinic-kr-key --region ap-northeast-2
```

### DB Parameter Group 충돌 (DBParameterGroupAlreadyExists)
RDS Parameter Group이 AWS에 존재하지만 State에 없는 경우.

**해결 방법**: State로 Import (db_password 환경변수 필요)

```bash
cd aws/compute
TF_VAR_db_password="your_password" terragrunt import 'module.db.aws_db_parameter_group.db_para' "petclinic-kr-db-params"
```

### State 확인 및 정리 명령어

```bash
# 현재 State 리소스 목록 확인
terragrunt state list

# 특정 리소스 상세 확인
terragrunt state show 'resource_address'

# State에서 리소스 제거 (AWS 리소스는 유지)
terragrunt state rm 'resource_address'

# S3 State 파일 직접 확인
aws s3 ls s3://petclinic-kr-tfstate/ --recursive

# DynamoDB Lock 항목 확인/삭제
aws dynamodb scan --table-name petclinic-kr-tflock
aws dynamodb delete-item --table-name petclinic-kr-tflock --key '{"LockID":{"S":"petclinic-kr-tfstate/compute/terraform.tfstate"}}'
```

## Monitoring (kube-prometheus-stack)

kube-prometheus-stack은 **Terraform compute 레이어에서 Helm으로 자동 설치**됩니다.

### 자동 설치 구성

| 항목 | AWS | GCP |
|------|-----|-----|
| Namespace | `petclinic` | `petclinic` |
| Grafana Service | ClusterIP | NodePort |
| Prometheus Service | ClusterIP | NodePort |
| Ingress Class | ALB | GCE |

### 설정 변수 (compute 모듈)

```hcl
variable "prometheus_stack_version" {
  default = "65.1.0"
}

variable "grafana_admin_password" {
  default   = "admin"
  sensitive = true
}

variable "prometheus_storage_size" {
  default = "10Gi"
}

variable "grafana_storage_size" {
  default = "5Gi"
}
```

### Ingress 관리

Ingress는 **petclinic-gitops에서 통합 관리**됩니다:

- **AWS**: `overlays/aws/cluster-monitoring-ingress.yaml` (ALB)
- **GCP**: `overlays/gcp/cluster-monitoring-ingress.yaml` (GCE)

> Terraform은 Helm Chart만 설치하고, Ingress는 GitOps로 관리하여 모든 Ingress를 한 곳에서 관리합니다.

### GCP NodePort 요구사항

GCE Ingress는 NodePort 서비스가 필요합니다. Terraform이 Helm values에서 자동으로 NodePort로 설정합니다:

```yaml
grafana:
  service:
    type: NodePort
prometheus:
  service:
    type: NodePort
```

## 관련 저장소

| 저장소 | 설명 |
|--------|------|
| **platform-gitops-last** | GitOps 매니페스트 (aws/, gcp/) |
| **petclinic-gitops** | PetClinic 애플리케이션 매니페스트 |
| **petclinic-dev** | PetClinic 소스 코드 + CI/CD |
