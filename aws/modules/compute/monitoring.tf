# ============================================================================
# Compute Module - monitoring.tf
# ============================================================================
# kube-prometheus-stack Helm 배포
# Cluster-wide 모니터링 (Prometheus, Grafana, AlertManager)
# ============================================================================

# ============================================================================
# Helm Provider Configuration (EKS 인증)
# ============================================================================
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id, "--region", var.region]
    }
  }
}

# ============================================================================
# kube-prometheus-stack Helm Release
# ============================================================================
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = var.monitoring_namespace
  create_namespace = true
  version          = var.kube_prometheus_stack_version

  # Prometheus 설정
  set {
    name  = "prometheus.prometheusSpec.externalUrl"
    value = "/prometheus"
  }

  set {
    name  = "prometheus.prometheusSpec.routePrefix"
    value = "/prometheus"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "2Gi"
  }

  # AlertManager 설정
  set {
    name  = "alertmanager.alertmanagerSpec.externalUrl"
    value = "/alertmanager"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.routePrefix"
    value = "/alertmanager"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.limits.memory"
    value = "256Mi"
  }

  # Grafana 설정
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "grafana.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "grafana.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "grafana.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "grafana.defaultDashboardsEnabled"
    value = "true"
  }

  set {
    name  = "grafana.sidecar.dashboards.enabled"
    value = "true"
  }

  # Node Exporter
  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  # Kube State Metrics
  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  # EKS에서 접근 불가능한 컴포넌트 비활성화
  set {
    name  = "defaultRules.rules.etcd"
    value = "false"
  }

  set {
    name  = "defaultRules.rules.kubeProxy"
    value = "false"
  }

  set {
    name  = "defaultRules.rules.kubeScheduler"
    value = "false"
  }

  set {
    name  = "kubeEtcd.enabled"
    value = "false"
  }

  set {
    name  = "kubeControllerManager.enabled"
    value = "false"
  }

  set {
    name  = "kubeScheduler.enabled"
    value = "false"
  }

  set {
    name  = "kubeProxy.enabled"
    value = "false"
  }

  depends_on = [
    module.eks,
    time_sleep.wait_for_karpenter_iam
  ]
}
