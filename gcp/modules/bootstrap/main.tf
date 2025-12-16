# ============================================================================
# Bootstrap Module - main.tf (GCP)
# ============================================================================
# ArgoCD 설치 및 Root Application 배포
# ============================================================================

# ============================================================================
# ArgoCD Namespace
# ============================================================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/managed-by" = "terragrunt"
      "cloud"                        = "gcp"
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
          "cloud"                        = "gcp"
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
# ArgoCD Root Application (App of Apps) - GCP용 경로 지정
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
        path: ${var.gitops_path}
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

  depends_on = [helm_release.argocd]
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
