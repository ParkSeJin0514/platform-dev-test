# ============================================================================
# Bootstrap Module - outputs.tf
# ============================================================================

output "argocd_namespace" {
  description = "ArgoCD 네임스페이스"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_admin_password" {
  description = "ArgoCD Admin 초기 비밀번호"
  value       = data.kubernetes_secret.argocd_admin.data["password"]
  sensitive   = true
}

output "argocd_server_url" {
  description = "ArgoCD Server URL (kubectl port-forward 필요)"
  value       = "https://localhost:8080"
}

output "argocd_access_guide" {
  description = "ArgoCD 접속 가이드"
  value       = <<-EOT

  ============================================
  ArgoCD 접속 가이드
  ============================================

  1. Port Forward 실행
     kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:443

  2. 브라우저 접속
     https://localhost:8080

  3. 로그인 정보
     Username: admin
     Password: (아래 명령어로 확인)

     kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

  ============================================
  IRSA Role ARNs (platform-gitops에 설정)
  ============================================

  ALB Controller:     ${var.alb_controller_role_arn}
  EFS CSI Driver:     ${var.efs_csi_driver_role_arn}
  External Secrets:   ${var.external_secrets_role_arn}

  EOT
}
