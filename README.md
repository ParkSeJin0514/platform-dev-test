# Platform Infrastructure (Multi-Cloud: AWS / GCP)

AWS Primary + GCP DR 환경을 위한 Terraform/Terragrunt IaC 코드

## 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Multi-Cloud DR Architecture                  │
├─────────────────────────────────┬───────────────────────────────────┤
│         AWS (Primary)           │          GCP (DR/Secondary)       │
├─────────────────────────────────┼───────────────────────────────────┤
│  EKS + Managed Node Group       │  GKE Autopilot                    │
│  Karpenter (Auto Scaling)       │  Built-in Auto Scaling            │
│  ALB Controller                 │  GKE Ingress (GCE)                │
│  EFS CSI Driver                 │  -                                │
│  External Secrets (AWS SM)      │  External Secrets (GCP SM)        │
│  IRSA                           │  Workload Identity                │
│  RDS MySQL                      │  (Uses AWS RDS)                   │
└─────────────────────────────────┴───────────────────────────────────┘
```

## 디렉토리 구조

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
│   ├── compute/                 # GKE Autopilot
│   ├── bootstrap/               # ArgoCD
│   └── modules/
│       ├── network/
│       ├── foundation/
│       ├── gke/
│       ├── compute/
│       └── bootstrap/
│
└── .github/workflows/
    ├── terraform-apply.yml      # Multi-Cloud Apply
    └── terraform-destroy.yml    # Multi-Cloud Destroy
```

## 사전 요구사항

### AWS
- AWS Account
- GitHub Actions OIDC 설정
- S3 Bucket (Terraform State)
- Secrets: `AWS_ROLE_ARN`, `TF_VAR_db_password`, `SSH_PUBLIC_KEY`

### GCP
- GCP Project: `kdt2-final-project-t1`
- GCS Bucket: `kdt2-final-project-t1-tfstate`
- Workload Identity Pool 및 Provider 설정

#### GCP OIDC 설정 (최초 1회)

```bash
# 1. Workload Identity Pool 생성
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project="kdt2-final-project-t1"

# 2. OIDC Provider 생성
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --project="kdt2-final-project-t1"

# 3. Service Account 생성
gcloud iam service-accounts create "github-actions" \
  --display-name="GitHub Actions" \
  --project="kdt2-final-project-t1"

# 4. 권한 부여
for role in container.admin compute.admin iam.serviceAccountAdmin secretmanager.admin storage.admin; do
  gcloud projects add-iam-policy-binding "kdt2-final-project-t1" \
    --member="serviceAccount:github-actions@kdt2-final-project-t1.iam.gserviceaccount.com" \
    --role="roles/$role"
done

# 5. Workload Identity 바인딩 (YOUR_ORG/YOUR_REPO를 실제 값으로 변경)
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions@kdt2-final-project-t1.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/605820610222/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_ORG/platform-dev-test" \
  --project="kdt2-final-project-t1"
```

## 사용 방법

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

## 레이어 설명

| Layer | 설명 | AWS 리소스 | GCP 리소스 |
|-------|------|-----------|-----------|
| **Foundation** | 네트워크 인프라 | VPC, Subnet, NAT Gateway | VPC, Subnet, Cloud NAT |
| **Compute** | 컴퓨팅 리소스 | EKS, RDS, IAM Roles | GKE Autopilot, Secret Manager |
| **Bootstrap** | GitOps 설정 | ArgoCD | ArgoCD |

## 주요 차이점 (AWS vs GCP)

| 항목 | AWS | GCP |
|------|-----|-----|
| Kubernetes | EKS + Managed Node | GKE Autopilot |
| Auto Scaling | Karpenter | Built-in |
| Load Balancer | ALB Controller | GKE Ingress |
| Storage | EFS CSI Driver | - |
| IAM | IRSA | Workload Identity |
| Secrets | AWS Secrets Manager | GCP Secret Manager |
| State Backend | S3 | GCS |

## DR 전략

- **전략**: Active-Standby
- **Primary**: AWS (ap-northeast-2)
- **Secondary**: GCP (asia-northeast3)
- **Database**: AWS RDS만 사용 (GCP에서 Cross-Cloud 접근)
- **Failover**: Manual (ArgoCD를 통한 GitOps)

## 관련 저장소

- **platform-gitops**: GitOps 매니페스트 (`aws/`, `gcp/` 폴더 구조)
- **petclinic-gitops**: PetClinic 애플리케이션 매니페스트
