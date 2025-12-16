# ============================================================================
# Cloud SQL Module - main.tf (GCP)
# ============================================================================
# MySQL 인스턴스 생성
# ============================================================================

# ============================================================================
# Cloud SQL MySQL Instance
# ============================================================================
resource "google_sql_database_instance" "mysql" {
  name             = "${var.project_name}-mysql"
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    backup_configuration {
      enabled            = var.backup_enabled
      binary_log_enabled = var.backup_enabled
      start_time         = "03:00"
    }

    maintenance_window {
      day  = 7  # Sunday
      hour = 4
    }

    database_flags {
      name  = "character_set_server"
      value = "utf8mb4"
    }

    user_labels = {
      environment = var.environment
      project     = var.project_name
      managed-by  = "terragrunt"
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ============================================================================
# Private Service Connection (VPC Peering for Cloud SQL)
# ============================================================================
# 기존에 생성된 Private IP range가 있으면 import 필요
# terraform import module.cloudsql.google_compute_global_address.private_ip_range petclinic-dr-sql-ip
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.project_name}-sql-ip"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id

  lifecycle {
    ignore_changes = all
  }
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  # 기존 연결이 있으면 업데이트
  update_on_creation_fail = true

  lifecycle {
    ignore_changes = [reserved_peering_ranges]
  }
}

# ============================================================================
# Database
# ============================================================================
resource "google_sql_database" "petclinic" {
  name     = var.database_name
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
  charset  = "utf8mb4"
}

# ============================================================================
# Database User
# ============================================================================
resource "google_sql_user" "petclinic" {
  name     = var.database_user
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
  password = var.database_password
}

# ============================================================================
# Store credentials in Secret Manager
# ============================================================================
resource "google_secret_manager_secret" "db_credentials" {
  secret_id = "${var.project_name}-db-credentials"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    project     = var.project_name
    managed-by  = "terragrunt"
  }
}

resource "google_secret_manager_secret_version" "db_credentials" {
  secret      = google_secret_manager_secret.db_credentials.id
  secret_data = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:mysql://${google_sql_database_instance.mysql.private_ip_address}:3306/${var.database_name}?useSSL=false&allowPublicKeyRetrieval=true"
    SPRING_DATASOURCE_USERNAME = var.database_user
    SPRING_DATASOURCE_PASSWORD = var.database_password
    MYSQL_HOST                 = google_sql_database_instance.mysql.private_ip_address
    MYSQL_PORT                 = "3306"
    MYSQL_DATABASE             = var.database_name
  })
}

# Secret 접근 권한 (External Secrets SA)
resource "google_secret_manager_secret_iam_member" "db_credentials_accessor" {
  secret_id = google_secret_manager_secret.db_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.external_secrets_sa_email}"
}
