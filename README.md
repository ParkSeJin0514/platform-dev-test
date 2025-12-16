# 🏗️ Platform Infrastructure (Multi-Cloud: AWS / GCP)

AWS Primary + GCP DR 환경을 위한 Terraform/Terragrunt IaC 코드

## 🏛️ 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Multi-Cloud DR Architecture                  │
├─────────────────────────────────┬───────────────────────────────────┤
│         AWS (Primary)           │          GCP (DR/Secondary)       │
├─────────────────────────────────┼───────────────────────────────────┤
│  VPC (10.0.0.0/16)              │  VPC (10.1.0.0/16)                │
│  EKS + Managed Node Group       │  GKE Autopilot                    │
│  Karpenter (Auto Scaling)       │  Built-in Auto Scaling            │
│  ALB Controller                 │  GKE Ingress (GCE)                │
│  EFS CSI Driver                 │  -                                │
│  External Secrets (AWS SM)      │  External Secrets (GCP SM)        │
│  IRSA                           │  Workload Identity                │
│  RDS MySQL                      │  Cloud SQL MySQL (Private)        │
│  Bastion + Management VM        │  Bastion + Management VM          │
└─────────────────────────────────┴───────────────────────────────────┘
```

## 📁 디렉토리 구조

```
platform-dev-test/
├── aws/                          # AWS Infrastructure
│   ├── terragrunt.hcl           # Root Terragrunt (S3 Backend)
│   ├── env.hcl                  # AWS 환경 변수
│   ├── foundation/              # VPC, Subnet, NAT Gateway
│   ├── compute/                 # EKS, RDS, IAM Roles
│   ├── bootstrap/               # ArgoCD
│   └── modules/
│       ├── network/
│       ├── foundation/
│       ├── eks/
│       ├── rds/
│       ├── compute/
│       └── bootstrap/
│
├── gcp/                          # GCP Infrastructure
│   ├── terragrunt.hcl           # Root Terragrunt (GCS Backend)
│   ├── env.hcl                  # GCP 환경 변수
│   ├── foundation/              # VPC, Subnet, Cloud NAT
│   ├── compute/                 # GKE Autopilot, Cloud SQL, VMs
│   ├── bootstrap/               # ArgoCD
│   └── modules/
│       ├── network/
│       ├── foundation/
│       ├── gke/
│       ├── cloudsql/
│       ├── vm/
│       ├── compute/
│       └── bootstrap/
│
└── .github/workflows/
    ├── terraform-apply.yml      # Multi-Cloud Apply
    └── terraform-destroy.yml    # Multi-Cloud Destroy
```

## 📋 사전 요구사항

### AWS
- AWS Account
- GitHub Actions OIDC 설정
- S3 Bucket (Terraform State)
- Secrets: `AWS_ROLE_ARN`, `TF_VAR_db_password`, `SSH_PUBLIC_KEY`

### GCP
- GCP Project: `kdt2-final-project-t1`
- GCS Bucket: `kdt2-final-project-t1-tfstate`
- Workload Identity Pool 및 Provider 설정

## 🔐 GCP OIDC 설정 (최초 1회)

```bash
# 1. Workload Identity Pool 생성
gcloud iam workload-identity-pools create "github-actions-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project="kdt2-final-project-t1"

# 2. OIDC Provider 생성
gcloud iam workload-identity-pools providers create-oidc "github-actions-provider" \
  --location="global" \
  --workload-identity-pool="github-actions-pool" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --project="kdt2-final-project-t1"

# 3. Service Account 생성 및 권한 부여
gcloud iam service-accounts create "github-actions" \
  --display-name="GitHub Actions" \
  --project="kdt2-final-project-t1"

# 4. Workload Identity 바인딩
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions@kdt2-final-project-t1.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/605820610222/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/YOUR_ORG/platform-dev-test" \
  --project="kdt2-final-project-t1"
```

## 🚀 사용 방법

### GitHub Actions 실행

1. **Actions** 탭으로 이동
2. **Terraform Apply** 또는 **Terraform Destroy** 워크플로우 선택
3. **Run workflow** 클릭
4. 옵션 선택:
   - **Cloud**: `aws` 또는 `gcp`
   - **Layer**: `all`, `foundation`, `compute`, `bootstrap`

### 로컬 실행 (선택사항)

```bash
# AWS
cd aws/foundation && terragrunt apply
cd ../compute && terragrunt apply
cd ../bootstrap && terragrunt apply

# GCP
cd gcp/foundation && terragrunt apply
cd ../compute && terragrunt apply
cd ../bootstrap && terragrunt apply
```

## 📊 레이어 설명

| Layer | 설명 | AWS 리소스 | GCP 리소스 |
|-------|------|-----------|-----------|
| **Foundation** | 네트워크 인프라 | VPC, Subnet, NAT Gateway | VPC, Subnet, Cloud NAT |
| **Compute** | 컴퓨팅 리소스 | EKS, RDS, IAM Roles | GKE Autopilot, Cloud SQL, VMs |
| **Bootstrap** | GitOps 설정 | ArgoCD | ArgoCD |

## ☁️ 주요 차이점 (AWS vs GCP)

| 항목 | AWS | GCP |
|------|-----|-----|
| Kubernetes | EKS + Managed Node | GKE Autopilot |
| Auto Scaling | Karpenter | Built-in |
| Load Balancer | ALB Controller | GKE Ingress |
| Storage | EFS CSI Driver | - |
| IAM | IRSA | Workload Identity |
| Secrets | AWS Secrets Manager | GCP Secret Manager |
| Database | RDS MySQL | Cloud SQL MySQL |
| State Backend | S3 | GCS |

## 🔄 DR 전략

- **전략**: Active-Standby
- **Primary**: AWS (ap-northeast-2)
- **Secondary**: GCP (asia-northeast3)
- **Database**: 각 클라우드 별도 DB (Cloud SQL)
- **Failover**: Manual (ArgoCD를 통한 GitOps)

## 🖥️ VM 접속 (SSH)

```bash
# SSH Config (~/.ssh/config)
# AWS
Host bastion
  HostName 43.201.225.72
  User ubuntu
  IdentityFile ~/project/infra-terragrunt-github/keys/test

Host mgmt
  HostName 10.0.50.99
  User ubuntu
  IdentityFile ~/project/infra-terragrunt-github/keys/test
  ProxyJump bastion

# GCP
Host gcp-bastion
  HostName 35.216.107.157
  User ubuntu
  IdentityFile ~/.ssh/gcp_key.pem

Host gcp-mgmt
  HostName 10.1.2.3
  User ubuntu
  IdentityFile ~/.ssh/gcp_key.pem
  ProxyJump gcp-bastion
```

```bash
# 접속
ssh bastion      # AWS Bastion
ssh mgmt         # AWS Management
ssh gcp-bastion  # GCP Bastion
ssh gcp-mgmt     # GCP Management
```

## 🔧 GCP 특이사항

### Management VM 자동 설정
GCP Management VM 생성 시 자동으로 설치/설정되는 항목:
- **kubectl** + **gke-gcloud-auth-plugin**: GKE 클러스터 접근
- **Docker**: 컨테이너 관리
- **mysql-client**: Cloud SQL 접속
- **GKE 자동 인증**: VM 생성 시 자동으로 `kubectl` 설정 완료

```bash
# Management VM 접속 후 바로 사용 가능
ssh gcp-mgmt
kubectl get pods -A
```

### GKE Autopilot
- 노드 관리 불필요 (완전 관리형)
- Pod 단위 과금
- 자동 스케일링

### Cloud SQL Private Access
- Private Service Connection 사용
- VPC 내부에서만 접근 가능
- 외부 IP 없음

### Workload Identity
```yaml
# GKE Service Account 연동
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: "SA@PROJECT.iam.gserviceaccount.com"
```

### Artifact Registry
```bash
# GKE 노드에 AR 읽기 권한 부여
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:gke-cluster-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

## 🔗 관련 저장소

| 저장소 | 설명 |
|--------|------|
| **platform-gitops-test** | GitOps 매니페스트 (aws/, gcp/ 폴더 구조) |
| **petclinic-gitops** | PetClinic 애플리케이션 매니페스트 |
| **petclinic-dev** | PetClinic 소스 코드 + CI/CD |
