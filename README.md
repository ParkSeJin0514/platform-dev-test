# 🏗️ Platform Infrastructure (Multi-Cloud: AWS / GCP)

AWS Primary + GCP DR 환경을 위한 Terraform/Terragrunt IaC 코드

## 🏛️ 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Multi-Cloud DR Architecture                  │
├─────────────────────────────────┬───────────────────────────────────┤
│         AWS (Primary)           │          GCP (DR/Secondary)       │
├─────────────────────────────────┼───────────────────────────────────┤
│  VPC (10.0.0.0/16)              │  VPC (172.16.0.0/16)              │
│  EKS + Managed Node Group       │  GKE Standard + Node Pool         │
│  Karpenter (Auto Scaling)       │  Node Pool Autoscaling            │
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
platform-dev-last/
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
│   ├── compute/                 # GKE Standard + Node Pool, Cloud SQL, VMs
│   ├── bootstrap/               # ArgoCD
│   └── modules/
│       ├── network/
│       ├── foundation/
│       ├── gke/                 # GKE Standard + Node Pool + Node SA
│       ├── cloudsql/
│       ├── vm/
│       ├── compute/
│       └── bootstrap/
│
└── .github/workflows/
    ├── terraform-apply.yml      # Multi-Cloud Apply (수동)
    ├── terraform-destroy.yml    # Multi-Cloud Destroy (수동 + 승인)
    └── terraform-pr.yml         # PR 생성 시 Plan 실행
```

## 📦 Provider & Chart 버전

### Terraform Provider 버전

| Provider | AWS | GCP | 비고 |
|----------|-----|-----|------|
| Terraform | `>= 1.0` | `>= 1.0` | |
| AWS | `>= 6.24.0` | - | Regional NAT Gateway 지원 |
| Google | - | `~> 5.0` | |
| Google-beta | - | `~> 5.0` | |
| Kubernetes | `~> 2.23` | `~> 2.23` | |
| Helm | `~> 2.11` | `~> 2.11` | |
| kubectl | `~> 1.14` | `~> 1.14` | |
| TLS | `~> 4.0` | - | |

### Helm Chart 버전 (platform-gitops-last)

| Component | Chart Version | App Version |
|-----------|---------------|-------------|
| ALB Controller | `1.8.1` | `2.7.1` |
| Karpenter | `1.1.1` | `1.1.1` |
| External Secrets | `0.10.7` | `0.10.7` |
| EFS CSI Driver | `3.0.8` | `2.0.0` |
| Metrics Server | `3.12.0` | `0.7.0` |
| ArgoCD | `5.51.6` | - |
| kube-prometheus-stack | `67.4.0` | - |

### 애플리케이션 버전

| 항목 | 버전 |
|------|------|
| EKS | `1.31` |
| MySQL (RDS/Cloud SQL) | `8.0` |
| Spring Boot (petclinic-dev) | `3.4.1` |
| Java | `17` |
| Spring Cloud | `2024.0.0` |

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
  --member="principalSet://iam.googleapis.com/projects/605820610222/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/YOUR_ORG/platform-dev-last" \
  --project="kdt2-final-project-t1"
```

## 🔔 Slack 알림

Terraform Apply/Destroy 실행 시 자동으로 Slack 알림이 발송됩니다.

### 알림 종류

| 워크플로우 | 트리거 | 시작 알림 | 완료 알림 | 승인 방식 |
|-----------|--------|----------|----------|----------|
| **Terraform Apply (수동)** | workflow_dispatch | 🚀 Apply 시작 | ✅ 성공 / ❌ 실패 | 없음 |
| **Terraform Destroy** | workflow_dispatch | 🚨 승인 요청 | ✅ 성공 / ❌ 실패 | GitHub Environment |
| **Terraform Plan (PR)** | PR 생성/업데이트 | - | 🔍 Plan 완료 | - |

### 설정 방법

1. **GitHub Secrets에 Slack Webhook URL 추가**
   - Repository → Settings → Secrets and variables → Actions
   - `SLACK_WEBHOOK_URL` 시크릿 추가

2. **Slack Incoming Webhook 생성**
   - Slack App 생성 → Incoming Webhooks 활성화
   - 채널에 Webhook 추가 후 URL 복사

### 알림 예시

**Apply 시작:**
```
🚀 Terraform Apply 시작
━━━━━━━━━━━━━━━━━━━━━
Cloud: aws
Layer: all
실행자: your-username
Repository: org/platform-dev-last
[워크플로우 보기] 버튼
```

**완료 알림:**
```
✅ Terraform Apply 성공
━━━━━━━━━━━━━━━━━━━━━
Cloud: aws
Layer: all
결과: success
실행자: your-username
[상세 로그 보기] 버튼
```

## 🛡️ Terraform Destroy 승인 프로세스

인프라 삭제 전 **팀장 승인**이 필요한 워크플로우가 적용되어 있습니다.

### 워크플로우 흐름

```
워크플로우 실행 + "destroy" 입력
        │
        ▼
┌─────────────────────────────────────┐
│ 1. Confirm 검증                      │
│    └── "destroy" 입력 확인           │
├─────────────────────────────────────┤
│ 2. Slack 알림 - 승인 요청            │
│    └── 팀장에게 승인 요청 알림 전송   │
├─────────────────────────────────────┤
│ 3. ✅ 팀장 승인 (GitHub Environment) │
│    └── production 환경 승인 대기     │
├─────────────────────────────────────┤
│ 4. Pre-Cleanup + Terraform Destroy  │
│    └── ALB/Karpenter 정리 후 삭제    │
├─────────────────────────────────────┤
│ 5. Slack 알림 - 완료                 │
│    └── 성공/실패 알림 전송           │
└─────────────────────────────────────┘
```

### GitHub Environment 설정 (필수)

1. Repository → Settings → Environments
2. **New environment** → `production` 생성
3. **Required reviewers** 체크 → 승인자 GitHub 계정 추가
4. **Prevent self-review** 체크 (선택) → 본인이 실행한 경우 본인 승인 불가
5. **Save protection rules** 클릭

> **참고**: Prevent self-review 체크 시, 실행한 사람과 다른 승인자가 필요합니다.

### Destroy 승인 요청 알림 예시

```
🚨 Terraform Destroy 승인 요청
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cloud: aws
Layer: all
실행자: your-username
확인: destroy
🔴 경고: 인프라 삭제가 요청되었습니다! 승인 후 Destroy가 실행됩니다.
[승인하러 가기] 버튼 (빨간색)
```

## 🔀 PR 기반 Terraform Plan 워크플로우

`.tf` 또는 `.hcl` 파일 변경 시 **PR에서 Plan 결과를 미리 확인**하는 워크플로우입니다.

### 트리거 조건

| 파일 패턴 | 트리거 |
|-----------|--------|
| `aws/**/*.tf` | AWS Plan 실행 |
| `aws/**/*.hcl` | AWS Plan 실행 |
| `gcp/**/*.tf` | GCP Plan 실행 |
| `gcp/**/*.hcl` | GCP Plan 실행 |

> **참고**: README.md 등 다른 파일만 변경 시에는 워크플로우가 트리거되지 않습니다.

### 워크플로우 흐름

```
feature 브랜치에서 .tf 파일 수정
        │
        ▼
┌─────────────────────────────────────┐
│ 1. PR 생성 (feature → main)         │
│    └── terraform-pr.yml 자동 실행   │
├─────────────────────────────────────┤
│ 2. Terraform Plan 실행              │
│    └── AWS/GCP 변경 사항 미리 확인   │
├─────────────────────────────────────┤
│ 3. 🔔 Slack 알림 - Plan 완료        │
│    └── "PR 리뷰 필요합니다"          │
├─────────────────────────────────────┤
│ 4. PR 코멘트로 Plan 결과 표시       │
│    └── 어떤 리소스가 변경되는지 확인 │
├─────────────────────────────────────┤
│ 5. 👀 코드 리뷰 + Approve + Merge   │
│    └── 팀장이 코드와 Plan 결과 검토  │
├─────────────────────────────────────┤
│ 6. 🚀 수동 Apply 실행               │
│    └── terraform-apply.yml 수동 실행│
└─────────────────────────────────────┘
```

### PR Plan 완료 알림 예시

```
🔍 Terraform Plan 완료 - PR 리뷰 필요
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PR: #42
Author: developer-name
AWS Plan: ✅ Success
GCP Plan: ⏭️ Skipped
Title: VPC CIDR 변경
[PR 리뷰하러 가기] 버튼
```

### 테스트 방법

```bash
# 1. feature 브랜치 생성
git checkout -b feature/test-pr

# 2. .tf 또는 .hcl 파일 수정 (주석 추가 등)
echo "# Test comment" >> gcp/foundation/terragrunt.hcl

# 3. 커밋 & 푸시
git add . && git commit -m "test: PR workflow test"
git push -u origin feature/test-pr

# 4. GitHub에서 PR 생성 → 자동으로 Plan 실행
# 5. PR Merge 후 → terraform-apply.yml 수동 실행
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

## 🗄️ RDS Security Group - Karpenter 노드 접근

RDS Security Group은 다음 Security Group에서의 MySQL(3306) 접근을 허용합니다.

### 허용된 Security Group

| Security Group | 용도 | 설명 |
|----------------|------|------|
| **EKS Node SG** | EKS 관리형 노드 | Node Group으로 생성된 EC2 |
| **EKS Cluster SG** | Karpenter 노드 | Karpenter가 프로비저닝한 EC2 |
| **Management SG** | Management Instance | 관리용 EC2 |

### 왜 Cluster SG가 필요한가?

Karpenter가 생성하는 노드는 **EKS Cluster Security Group**을 사용합니다:
- 관리형 노드(Node Group): `node_security_group_id` 사용
- Karpenter 노드: `cluster_security_group_id` 사용 (EKS가 자동 생성)

```hcl
# aws/modules/compute/main.tf
allowed_security_group_ids = [
  module.eks.node_security_group_id,         # EKS 관리형 노드
  module.eks.cluster_security_group_id,      # Karpenter 노드
  module.ec2.mgmt_security_group_id          # Management Instance
]
```

### 문제 증상 (Karpenter 노드에서 DB 접근 불가 시)

```
HikariPool-1 - Starting...
# 30초 이상 대기 후 반복
HikariPool-1 - Starting...
```

Pod가 CrashLoopBackOff 상태가 되고, 로그에 HikariCP가 MySQL 연결을 시도하지만 타임아웃됩니다.

### 수동 확인 (디버깅용)

```bash
# Karpenter 노드의 Security Group 확인
aws ec2 describe-instances \
  --filters "Name=tag:karpenter.sh/nodepool,Values=*" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,SG:SecurityGroups[*].GroupId}'

# RDS Security Group 인바운드 규칙 확인
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID> \
  --query 'SecurityGroups[*].IpPermissions[*].UserIdGroupPairs[*].GroupId'
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
| **Foundation** | 네트워크 인프라 | VPC, Subnet, Regional NAT Gateway | VPC, Subnet, Cloud NAT |
| **Compute** | 컴퓨팅 리소스 | EKS, RDS, IAM Roles | GKE Standard + Node Pool, Cloud SQL, VMs |
| **Bootstrap** | GitOps 설정 | ArgoCD | ArgoCD |

## 🌐 Regional NAT Gateway (AWS)

AWS Provider 6.24.0부터 지원되는 **Regional NAT Gateway**를 사용하여 비용 절감 및 관리 단순화를 구현했습니다.

### 기존 방식 (Zonal) vs 새로운 방식 (Regional)

| 항목 | Zonal (기존) | Regional (현재) |
|------|-------------|-----------------|
| NAT Gateway 개수 | AZ당 1개 (2개 AZ = 2개) | **1개** |
| Elastic IP | AZ당 1개 | 자동 관리 (Auto Mode) |
| Route Table | AZ별 Private RT | **단일 Private RT** |
| 비용 | NAT Gateway × AZ 개수 | **NAT Gateway 1개** |
| 고가용성 | 수동 구성 | **AWS 자동 관리** |

### Terraform 설정 (aws/modules/network/main.tf)

```hcl
# Regional NAT Gateway (단일)
resource "aws_nat_gateway" "regional" {
  availability_mode = "regional"   # Regional 모드
  vpc_id            = aws_vpc.main.id
  connectivity_type = "public"

  tags = { Name = "${var.project_name}-nat-regional" }
  depends_on = [aws_internet_gateway.igw]
}

# Private Route Table (단일)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.regional.id
  }

  tags = { Name = "${var.project_name}-rt-private" }
}
```

### 장점

1. **비용 절감**: 여러 AZ에 NAT Gateway를 개별 생성할 필요 없음
2. **자동 확장**: 워크로드가 있는 AZ에 자동으로 확장
3. **관리 단순화**: 단일 NAT Gateway, 단일 Route Table
4. **고가용성**: AWS가 자동으로 AZ 커버리지 관리

### 요구사항

- **AWS Provider**: `>= 6.24.0`

```hcl
# aws/terragrunt.hcl
aws = {
  source  = "hashicorp/aws"
  version = ">= 6.24.0"
}
```

## ☁️ 주요 차이점 (AWS vs GCP)

| 항목 | AWS | GCP |
|------|-----|-----|
| Kubernetes | EKS + Managed Node | GKE Standard + Node Pool |
| Auto Scaling | Karpenter | Node Pool Autoscaling (min/max) |
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

## ⏱️ ArgoCD 초기화 타이밍 이슈 해결

### 문제

Terraform bootstrap 레이어에서 ArgoCD Helm 설치 직후 `root-app` Application을 생성하면, ArgoCD Application Controller가 아직 완전히 Ready 되지 않아 **Auto-Sync가 트리거되지 않는** 문제가 발생합니다.

### 증상

```bash
kubectl get applications -n argocd
NAME               SYNC STATUS   HEALTH STATUS
argocd-ingress     OutOfSync     Missing      # Sync 안됨
external-secrets   OutOfSync     Degraded
karpenter          OutOfSync     Missing
petclinic          OutOfSync     Degraded
root-app           Synced        Healthy
```

### 해결책

`time_sleep` 리소스를 사용하여 ArgoCD 초기화 완료를 대기합니다.

```hcl
# aws/modules/bootstrap/main.tf

# ArgoCD 초기화 대기 (30초)
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  create_duration = "30s"
}

# Root Application - ArgoCD 초기화 완료 후 생성
resource "kubectl_manifest" "root_application" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root-app
      namespace: argocd
    spec:
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [time_sleep.wait_for_argocd]
}
```

### 수동 Sync (긴급 복구 시)

ArgoCD Application이 OutOfSync 상태인 경우:

```bash
# 개별 Application Sync
kubectl patch application argocd-ingress -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# 여러 Application 한번에
for app in argocd-ingress external-secrets karpenter petclinic; do
  kubectl patch application $app -n argocd --type merge \
    -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
done
```

---

## ⏱️ Karpenter IAM 타이밍 이슈 해결

### 문제

Karpenter가 노드를 프로비저닝할 때, 다음 순서로 동작합니다:

```
1. IAM Role/Policy 생성 → AWS 전체 리전에 전파 (10-30초)
2. EKS Access Entry 생성 → API Server에 반영
3. EC2 Node Bootstrap → kubelet이 API Server에 인증 시도
```

**문제**: 3번이 1,2번보다 먼저 실행되면 노드 등록 실패

### 해결책

`time_sleep` 리소스를 사용하여 IAM 권한 전파를 대기합니다.

```hcl
# aws/modules/compute/karpenter.tf

# IAM 권한 전파 대기 (30초)
resource "time_sleep" "wait_for_karpenter_iam" {
  depends_on = [
    aws_iam_role.karpenter_node,
    aws_iam_role_policy_attachment.karpenter_node_worker,
    aws_iam_role_policy_attachment.karpenter_node_cni,
    aws_iam_role_policy_attachment.karpenter_node_ecr,
    aws_iam_role_policy_attachment.karpenter_node_ssm,
    aws_iam_instance_profile.karpenter_node
  ]
  create_duration = "30s"
}

# EKS Access Entry - IAM 전파 완료 후 생성
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = module.eks.cluster_id
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"

  depends_on = [time_sleep.wait_for_karpenter_iam]
}
```

### 타이밍 설정

| 리소스 | 대기 시간 | 이유 |
|--------|----------|------|
| Karpenter Node IAM | 30초 | IAM Role/Policy 전파 |
| Karpenter Controller IRSA | 15초 | OIDC 기반 IRSA 전파 |

### 실무 권장 사항

| 방법 | 사용 시점 | 장점 | 단점 |
|------|----------|------|------|
| `depends_on` | 리소스 간 명확한 의존성 | 선언적, 명확함 | API 레벨만 보장 |
| `time_sleep` | IAM 전파 등 실제 지연 | 안정적 | 고정 대기 시간 |
| ArgoCD Sync Wave | GitOps 환경 | 자동화 | 정확한 타이밍 어려움 |

---

## 🧹 AWS Terraform Destroy - ALB/Target Group 정리

Terraform destroy 실행 시 Kubernetes에서 생성한 ALB/Target Group이 남아있으면 삭제가 실패할 수 있습니다.
이를 해결하기 위해 **Pre-Cleanup** 단계에서 자동으로 정리합니다.

### 자동 정리 대상

| 리소스 | 정리 방법 |
|--------|----------|
| **Karpenter EC2** | `karpenter.sh/nodepool` 태그 기준 EC2 강제 종료 (가장 먼저!) |
| **Karpenter K8s** | NodePool, EC2NodeClass, NodeClaim Finalizer 제거 후 삭제 |
| **Karpenter Node** | `karpenter.sh/nodepool` 라벨 기준 노드 삭제 |
| **ArgoCD Applications** | Finalizer 제거 후 강제 삭제 |
| **Ingress** | 모든 네임스페이스의 Ingress 삭제 |
| **LoadBalancer Service** | LoadBalancer 타입 Service 삭제 |
| **ALB** | `petclinic`, `k8s`, `argocd` 이름 포함 ALB 강제 삭제 |
| **Target Group** | 고아 Target Group 삭제 |

### 처리 흐름

```
1. Karpenter Controller 중지 (replicas=0) ← 가장 먼저! 새 노드 생성 방지
       ↓
2. Controller 중지 대기 (Pod 종료 확인)
       ↓
3. NodePool 삭제 (Controller 재시작해도 NodePool 없으면 생성 불가)
       ↓
4. EC2NodeClass, NodeClaim 삭제
       ↓
5. Karpenter EC2 인스턴스 강제 종료 (Controller 중지 후 안전하게)
       ↓
6. Karpenter 노드 삭제 (라벨: karpenter.sh/nodepool)
       ↓
7. EC2 인스턴스 종료 확인 (최대 2분 대기)
       ↓
8. 남은 인스턴스 재종료 시도
       ↓
9. ArgoCD Applications 정리
       ↓
10. Ingress & LoadBalancer Service 삭제
       ↓
11. ALB 강제 삭제 (Listener 먼저 삭제)
       ↓
12. ALB 삭제 완료 확인 (최대 5분 대기)
       ↓
13. 고아 Target Group 삭제
       ↓
14. Terraform Destroy 실행
```

> **중요**: Controller를 먼저 중지해야 EC2 종료 후 새 노드가 다시 생성되지 않음!

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

## 🧹 GCP Terraform Destroy - GKE Ingress 리소스 정리

GCP에서 Terraform destroy 실행 시 GKE Ingress가 생성한 리소스가 남아있으면 VPC 삭제가 실패합니다.
이를 해결하기 위해 **Pre-Cleanup** 단계에서 자동으로 정리합니다.

### 자동 정리 대상

| 리소스 | 정리 방법 | 필요 이유 |
|--------|----------|----------|
| **ArgoCD Applications** | Finalizer 제거 후 강제 삭제 | Application 정리 |
| **Ingress** | Finalizer 제거 후 강제 삭제 | GKE Ingress 리소스 정리 시작 |
| **LoadBalancer Service** | Service 삭제 | 외부 LB 정리 |
| **Firewall Rules** | `k8s-fw-*` 패턴 삭제 | VPC 삭제 차단 방지 |
| **NEG** | 모든 zone의 Network Endpoint Groups 삭제 | VPC 삭제 차단 방지 |
| **Backend Services** | `k8s-*` 패턴 삭제 | LB 리소스 정리 |
| **URL Maps** | `k8s-*` 패턴 삭제 | LB 리소스 정리 |
| **Target HTTP Proxies** | `k8s-*` 패턴 삭제 | LB 리소스 정리 |
| **Forwarding Rules** | `k8s-*` 패턴 삭제 | LB 리소스 정리 |
| **Health Checks** | `k8s-*` 패턴 삭제 | LB 리소스 정리 |
| **Cloud SQL** | 인스턴스 삭제 (VPC Peering 삭제 전 필수) | Service Networking Connection 해제 |
| **Service Networking** | `gcloud services vpc-peerings delete` | VPC 삭제 차단 방지 |
| **VPC Peering** | Cloud SQL Private Connection 삭제 | VPC 삭제 차단 방지 |
| **Global Address** | `petclinic-*` 패턴 삭제 | VPC 삭제 차단 방지 |
| **Routes** | VPC 관련 Route 삭제 | VPC 삭제 차단 방지 |

> **중요**: Cloud SQL이 Service Networking Connection을 사용 중이면 VPC Peering 삭제가 실패합니다. 반드시 **Cloud SQL을 먼저 삭제**해야 합니다.

### 처리 흐름

```
1. ArgoCD Applications 정리 (Finalizer 제거)
       ↓
2. Ingress & LoadBalancer Service 삭제
       ↓
3. Forwarding Rules 삭제 (LB 최상위 리소스)
       ↓
4. Target HTTP/HTTPS Proxies 삭제
       ↓
5. URL Maps 삭제
       ↓
6. Backend Services 삭제 (NEG 참조 해제)
       ↓
7. Health Checks 삭제
       ↓
8. Network Endpoint Groups 삭제 (모든 zone)
       ↓
9. GKE 방화벽 규칙 삭제 (k8s-fw-*)
       ↓
10. Cloud SQL 인스턴스 삭제 (VPC Peering 삭제 전 필수!)
       ↓
11. 방화벽 규칙 최종 정리 (VPC에 연결된 모든 규칙 재확인)
       ↓
12. Service Networking Connection 삭제
       ↓
13. VPC Peering 삭제
       ↓
14. Routes 삭제
       ↓
15. Global Address 삭제 (Cloud SQL Private IP)
       ↓
16. Terraform Destroy 실행
```

> **중요**: GKE Ingress 리소스는 **역순으로 삭제**해야 합니다. NEG는 Backend Service에 연결되어 있어 Backend Service를 먼저 삭제해야 NEG 삭제가 가능합니다.
>
> **Note**: 방화벽 규칙 `k8s-fw-l7--*`는 GKE Ingress가 생성하는 L7 로드밸런서 방화벽 규칙입니다. Ingress 삭제 후에도 남아있을 수 있어 VPC 삭제 전에 한번 더 확인합니다.

### 수동 정리 (필요시)

```bash
# Cloud SQL 확인 및 삭제 (VPC Peering 삭제 전 필수!)
gcloud sql instances list --filter="name~petclinic"
gcloud sql instances patch <INSTANCE_NAME> --no-deletion-protection --quiet
gcloud sql instances delete <INSTANCE_NAME> --quiet

# Service Networking Connection 삭제
gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network=petclinic-dr-vpc --quiet

# 방화벽 규칙 확인 (VPC에 연결된 모든 규칙)
gcloud compute firewall-rules list --filter="name~k8s OR network~petclinic" --format="table(name,network)"

# 방화벽 규칙 삭제 (VPC 삭제 차단 방지)
gcloud compute firewall-rules delete <FW_NAME> --quiet

# NEG 확인 (각 zone별)
gcloud compute network-endpoint-groups list --format="table(name,zone)"

# Global Address 확인
gcloud compute addresses list --global --format="table(name,address)"

# VPC Peering 확인
gcloud compute networks peerings list --network=petclinic-dr-vpc

# 수동 삭제 예시
gcloud compute firewall-rules delete <FW_NAME> --quiet
gcloud compute network-endpoint-groups delete <NEG_NAME> --zone=<ZONE> --quiet
gcloud compute addresses delete <ADDR_NAME> --global --quiet
gcloud compute networks peerings delete <PEERING_NAME> --network=<VPC_NAME> --quiet
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
- **GKE 자동 인증**: VM이 GKE 생성 완료 후 자동으로 `kubectl` 설정

> **Note**: VM은 GKE 클러스터 생성 완료 후에 생성되며, startup script에서 GKE RUNNING 상태를 확인 후 kubectl을 자동 설정합니다.

```bash
# Management VM 접속 후 바로 사용 가능
ssh gcp-mgmt
kubectl get pods -A

# kubectl 설정이 안 된 경우 수동 실행
./configure-kubectl.sh

# 또는 직접 실행
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials petclinic-dr-gke --region asia-northeast3 --project kdt2-final-project-t1
```

### startup script 로그 확인
```bash
# VM에서 startup script 실행 로그 확인
sudo cat /var/log/startup-script.log
```

### GKE Standard + Node Pool
- **Standard 모드**: 노드풀 직접 관리 (Autopilot 대신)
- 노드용 Service Account 자동 생성 (`{cluster-name}-nodes`)
- 오토스케일링: `min_node_count` ~ `max_node_count` 설정
- 자동 복구/업그레이드: `auto_repair = true`, `auto_upgrade = true`
- **Public Cluster 모드**: `enable_private_nodes = false`
  - Compute Engine 기본 SA 삭제로 인해 Private Cluster 사용 불가
  - 방화벽으로 보안 제어

### GKE Node Pool 설정 (env.hcl)
```hcl
gke_mode          = "standard"      # standard or autopilot
node_machine_type = "e2-standard-4" # 노드 머신 타입
node_count        = 1               # 초기 노드 수 (존당)
min_node_count    = 1               # 오토스케일링 최소
max_node_count    = 2               # 오토스케일링 최대
```

### Node Service Account 권한
| 권한 | 역할 |
|------|------|
| `roles/logging.logWriter` | Cloud Logging 쓰기 |
| `roles/monitoring.metricWriter` | Cloud Monitoring 메트릭 쓰기 |
| `roles/stackdriver.resourceMetadata.writer` | Stackdriver 메타데이터 |
| `roles/artifactregistry.reader` | Artifact Registry 이미지 Pull |

### Cloud SQL Private Access
- Private Service Connection 사용
- VPC 내부에서만 접근 가능
- 외부 IP 없음

**Private Service Connection 구조:**
```
┌─────────────────┐     VPC Peering      ┌─────────────────────┐
│  petclinic-dr   │ ◄──────────────────► │  Google Managed     │
│     VPC         │  servicenetworking-  │  Service Network    │
│  172.16.0.0/16  │  googleapis-com      │  (Cloud SQL 위치)   │
└─────────────────┘                      └─────────────────────┘
```

**Terraform 리소스 (cloudsql/main.tf):**
- `google_compute_global_address.private_ip_range`: VPC Peering용 IP 범위 (/16)
- `google_service_networking_connection.private_vpc_connection`: VPC Peering 생성
- Apply 시 자동 생성, Destroy 시 Pre-Cleanup에서 강제 삭제

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

## 📊 Cluster Monitoring (kube-prometheus-stack)

Terraform으로 `kube-prometheus-stack`을 자동 배포하여 클러스터 전체 모니터링을 제공합니다.

### 구성 요소

| Component | 경로 | 설명 |
|-----------|------|------|
| Prometheus | `/prometheus` | 메트릭 수집 및 저장 |
| Grafana | `/` | 대시보드 및 시각화 |
| AlertManager | `/alertmanager` | 알림 관리 |
| Node Exporter | - | 노드 메트릭 수집 |
| Kube State Metrics | - | K8s 리소스 메트릭 |

### Terraform 설정 (aws/modules/compute/monitoring.tf)

```hcl
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = var.monitoring_namespace  # default: petclinic
  version    = var.kube_prometheus_stack_version  # default: 67.4.0

  # Prometheus 설정
  set {
    name  = "prometheus.prometheusSpec.routePrefix"
    value = "/prometheus"
  }

  # AlertManager 설정
  set {
    name  = "alertmanager.alertmanagerSpec.routePrefix"
    value = "/alertmanager"
  }

  # Grafana 설정
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password  # default: admin
  }
}
```

### 변수 (env.hcl에서 오버라이드 가능)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `monitoring_namespace` | `petclinic` | 설치 네임스페이스 |
| `kube_prometheus_stack_version` | `67.4.0` | Helm chart 버전 |
| `prometheus_retention` | `7d` | 데이터 보존 기간 |
| `grafana_admin_password` | `admin` | Grafana 관리자 비밀번호 |

### EKS 최적화

EKS에서 접근 불가능한 컴포넌트는 자동 비활성화:
- `kubeEtcd.enabled = false`
- `kubeControllerManager.enabled = false`
- `kubeScheduler.enabled = false`
- `kubeProxy.enabled = false`

### externalUrl 설정 주의사항

**중요**: `externalUrl`에 스킴(http/https) 없이 경로만 설정하면 AlertManager/Prometheus가 CrashLoopBackOff 상태가 됩니다.

```
# 에러 메시지
level=error msg="failed to determine external URL" err="\"/alertmanager\": invalid \"\" scheme, only 'http' and 'https' are supported"
```

**해결책**: ALB 주소를 미리 알 수 없으므로 `externalUrl`은 설정하지 않고 `routePrefix`만 사용합니다.

```hcl
# ❌ 잘못된 설정 (CrashLoopBackOff 발생)
set {
  name  = "alertmanager.alertmanagerSpec.externalUrl"
  value = "/alertmanager"  # 스킴 없음 → 에러
}

# ✅ 올바른 설정 (routePrefix만 사용)
set {
  name  = "alertmanager.alertmanagerSpec.routePrefix"
  value = "/alertmanager"
}
```

### 접속 URL

배포 후 ALB를 통해 접속:
- **Grafana**: `http://cluster-monitoring-alb-xxx.ap-northeast-2.elb.amazonaws.com/`
- **Prometheus**: `http://cluster-monitoring-alb-xxx.ap-northeast-2.elb.amazonaws.com/prometheus`
- **AlertManager**: `http://cluster-monitoring-alb-xxx.ap-northeast-2.elb.amazonaws.com/alertmanager`

## 🔗 관련 저장소

| 저장소 | 설명 |
|--------|------|
| **platform-gitops-last** | GitOps 매니페스트 (aws/, gcp/ 폴더 구조) |
| **petclinic-gitops** | PetClinic 애플리케이션 매니페스트 |
| **petclinic-dev** | PetClinic 소스 코드 + CI/CD |
