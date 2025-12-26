# ============================================================================
# Bootstrap Module - main.tf
# ============================================================================
# EKS 클러스터 설정: StorageClass, kube-prometheus-stack, ArgoCD
# ============================================================================

# ============================================================================
# gp3 StorageClass (default)
# ============================================================================
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
}

# gp2 StorageClass의 default 해제
resource "kubernetes_annotations" "gp2_non_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [kubernetes_storage_class.gp3]
}

# ============================================================================
# kube-prometheus-stack Helm Chart (petclinic namespace)
# Alertmanager 비활성화
# ============================================================================
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_stack_version
  namespace        = "petclinic"
  create_namespace = true
  timeout          = 900
  wait             = true
  wait_for_jobs    = true

  values = [
    <<-EOT
    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        podMonitorSelectorNilUsesHelmValues: false
        retention: 7d
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: gp3
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: ${var.prometheus_storage_size}

    grafana:
      enabled: true
      adminPassword: ${var.grafana_admin_password}
      persistence:
        enabled: true
        type: pvc
        storageClassName: gp3
        size: ${var.grafana_storage_size}
        accessModes:
          - ReadWriteOnce
      sidecar:
        datasources:
          enabled: true
        dashboards:
          enabled: true

    # Alertmanager 비활성화
    alertmanager:
      enabled: false

    nodeExporter:
      enabled: true
    kubeStateMetrics:
      enabled: true
    EOT
  ]

  depends_on = [kubernetes_storage_class.gp3]
}

# ============================================================================
# AWS Auth ConfigMap
# ============================================================================
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      # 워커 노드 IAM Role
      {
        rolearn  = var.node_iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      # Management Instance IAM Role
      {
        rolearn  = var.mgmt_iam_role_arn
        username = "mgmt-admin"
        groups   = ["system:masters"]
      }
    ])
  }

  force = true
}

# ============================================================================
# ArgoCD Namespace
# ============================================================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/managed-by" = "terragrunt"
    }
  }
}

# ============================================================================
# ArgoCD Helm Release
# ============================================================================
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  timeout = 600
  wait    = true

  values = [
    yamlencode({
      global = {
        additionalLabels = {
          "app.kubernetes.io/managed-by" = "terragrunt"
          "project"                      = var.project_name
        }
      }

      server = {
        replicas = 1
        service = {
          type = "ClusterIP"
        }
        extraArgs = ["--insecure"]
      }

      repoServer = {
        replicas = 1
      }

      controller = {
        replicas = 1
      }

      redis = {
        enabled = true
      }

      dex = {
        enabled = false
      }

      notifications = {
        enabled = false
      }

      applicationSet = {
        enabled = true
      }

      configs = {
        ssh = {
          knownHosts = <<-EOF
            github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
            github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
            github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
          EOF
        }
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ============================================================================
# ArgoCD 초기화 대기
# ============================================================================
# ArgoCD Helm Release 후 Application Controller가 완전히 Ready 되기까지 대기
# 이 대기 시간이 없으면 root-app 생성 시 Sync가 제대로 트리거되지 않음
# ============================================================================
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]

  # Application Controller(StatefulSet)가 완전히 Ready 되기까지 충분한 대기
  # 30초는 부족할 수 있음 - 특히 kube-prometheus-stack 같은 대형 CRD 차트 sync 시
  create_duration = "60s"
}

# ============================================================================
# ArgoCD Root Application (App of Apps)
# ============================================================================
resource "kubectl_manifest" "root_application" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root-app
      namespace: ${var.argocd_namespace}
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: ${var.gitops_repo_url}
        targetRevision: ${var.gitops_target_revision}
        path: aws/apps
      destination:
        server: https://kubernetes.default.svc
        namespace: ${var.argocd_namespace}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [time_sleep.wait_for_argocd]
}

# ============================================================================
# ArgoCD Admin Password 조회
# ============================================================================
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.argocd_namespace
  }

  depends_on = [helm_release.argocd]
}
