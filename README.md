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

## 🔔 Slack 알림

Terraform Apply/Destroy 실행 시 자동으로 Slack 알림이 발송됩니다.

### 알림 종류

| 시점 | 내용 |
|------|------|
| **시작** | 워크플로우 시작, Cloud/Layer 정보, 실행자 |
| **완료** | 성공/실패 상태, 상세 로그 링크 |

### 설정 방법

1. **GitHub Secrets에 Slack Webhook URL 추가**
   - Repository → Settings → Secrets and variables → Actions
   - `SLACK_WEBHOOK_URL` 시크릿 추가

2. **Slack Incoming Webhook 생성**
   - Slack App 생성 → Incoming Webhooks 활성화
   - 채널에 Webhook 추가 후 URL 복사

### 알림 예시

```
🚀 Terraform Apply 시작
━━━━━━━━━━━━━━━━━━━━━
Cloud: aws
Layer: all
실행자: your-username
[워크플로우 보기] 버튼
```

## 🛡️ ALB Security Group 자동화

AWS EKS에서 ALB Ingress Controller가 생성하는 ALB → Worker Node 트래픽을 자동으로 허용합니다.

### 자동 설정되는 규칙

| 규칙 | 소스 | 대상 | 포트 |
|------|------|------|------|
| `node_ingress_alb` | VPC CIDR | Node SG | 0-65535 (TCP) |
| `cluster_ingress_alb` | VPC CIDR | Cluster SG | 0-65535 (TCP) |

### 이전 수동 작업 (더 이상 불필요)

```bash
# 더 이상 필요 없음 - Terraform이 자동으로 처리
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxx \
  --protocol tcp \
  --port 0-65535 \
  --cidr 10.0.0.0/16
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

## 🧹 AWS Terraform Destroy - ALB/Target Group 정리

Terraform destroy 실행 시 Kubernetes에서 생성한 ALB/Target Group이 남아있으면 삭제가 실패할 수 있습니다.
이를 해결하기 위해 **Pre-Cleanup** 단계에서 자동으로 정리합니다.

### 자동 정리 대상

| 리소스 | 정리 방법 |
|--------|----------|
| **Karpenter** | NodeClaim, NodePool, EC2NodeClass Finalizer 제거 후 삭제 |
| **ArgoCD Applications** | Finalizer 제거 후 강제 삭제 |
| **Ingress** | 모든 네임스페이스의 Ingress 삭제 |
| **LoadBalancer Service** | LoadBalancer 타입 Service 삭제 |
| **ALB** | `petclinic`, `k8s`, `argocd` 이름 포함 ALB 강제 삭제 |
| **Target Group** | 고아 Target Group 삭제 |

### 처리 흐름

```
1. Karpenter 리소스 정리
       ↓
2. ArgoCD Applications 정리
       ↓
3. Ingress & LoadBalancer Service 삭제
       ↓
4. ALB 강제 삭제 (Listener 먼저 삭제)
       ↓
5. 30초 대기 (ALB 삭제 완료 대기)
       ↓
6. 고아 Target Group 삭제
       ↓
7. ALB 삭제 완료 확인 (최대 5분 대기)
       ↓
8. Terraform Destroy 실행
```

### 수동 정리 (필요시)

```bash
# ALB 목록 확인
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn]' --output table

# Target Group 목록 확인
aws elbv2 describe-target-groups --query 'TargetGroups[*].[TargetGroupName,TargetGroupArn]' --output table

# ALB 강제 삭제
aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>

# Target Group 삭제
aws elbv2 delete-target-group --target-group-arn <TG_ARN>
```

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
