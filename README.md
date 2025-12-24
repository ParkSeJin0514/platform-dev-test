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
│   ├── env.hcl                  # AWS 환경 변수
│   ├── foundation/              # VPC, Subnet, NAT Gateway
│   ├── compute/                 # EKS, RDS, IAM Roles
│   ├── bootstrap/               # ArgoCD
│   └── modules/                 # network, eks, rds, ec2 등
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
- S3 Bucket (Terraform State)
- GitHub Actions OIDC 설정
- Secrets: `AWS_ROLE_ARN`, `TF_VAR_db_password`, `SSH_PUBLIC_KEY`

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

### Kubernetes cluster unreachable (Helm Provider)
- **원인**: EKS 클러스터 생성 전에 Helm Provider가 연결 시도
- **해결**: `enable_monitoring` 변수로 2단계 배포
  ```bash
  # 1단계: EKS 생성 (enable_monitoring = false)
  cd aws/compute && terragrunt apply

  # 2단계: Helm 배포 (enable_monitoring = true로 변경 후)
  terragrunt apply
  ```

## 관련 저장소

| 저장소 | 설명 |
|--------|------|
| **platform-gitops-last** | GitOps 매니페스트 (aws/, gcp/) |
| **petclinic-gitops** | PetClinic 애플리케이션 매니페스트 |
| **petclinic-dev** | PetClinic 소스 코드 + CI/CD |
