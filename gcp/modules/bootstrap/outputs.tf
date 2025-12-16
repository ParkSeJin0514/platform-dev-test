# ============================================================================
# Bootstrap Module - outputs.tf (GCP)
# ============================================================================

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_release_status" {
  description = "ArgoCD Helm release status"
  value       = helm_release.argocd.status
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = data.kubernetes_secret.argocd_admin.data["password"]
  sensitive   = true
}
