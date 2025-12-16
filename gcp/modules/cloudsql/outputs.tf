# ============================================================================
# Cloud SQL Module - outputs.tf
# ============================================================================

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.mysql.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.mysql.connection_name
}

output "private_ip_address" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.mysql.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.petclinic.name
}

output "database_user" {
  description = "Database user"
  value       = google_sql_user.petclinic.name
}

output "jdbc_url" {
  description = "JDBC connection URL"
  value       = "jdbc:mysql://${google_sql_database_instance.mysql.private_ip_address}:3306/${var.database_name}?useSSL=false&allowPublicKeyRetrieval=true"
  sensitive   = true
}

output "db_credentials_secret_id" {
  description = "Secret Manager secret ID for DB credentials"
  value       = google_secret_manager_secret.db_credentials.secret_id
}
