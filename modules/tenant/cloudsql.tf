# Instance names cannot be reused for about a week after deletion, so add a short suffix.
resource "random_id" "sql_suffix" {
  byte_length = 2
}

resource "google_sql_database_instance" "main" {
  project             = google_project.tenant.project_id
  name                = "sql-${var.tenant_name}-prod-${random_id.sql_suffix.hex}"
  region              = var.region
  database_version    = "POSTGRES_16"
  encryption_key_name = google_kms_crypto_key.cmek.id
  deletion_protection = true

  settings {
    tier                        = var.sql_tier
    edition                     = "ENTERPRISE"
    availability_type           = var.sql_availability_type
    disk_type                   = "PD_SSD"
    disk_size                   = var.sql_disk_size_gb
    disk_autoresize             = true
    deletion_protection_enabled = true
    user_labels                 = local.labels

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      ssl_mode                                      = "ENCRYPTED_ONLY"
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "17:00" # UTC = 01:00 Singapore time
      location                       = var.region
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 14
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7  # Sunday
      hour         = 18 # UTC = 02:00 Monday Singapore time
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = false
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  }

  depends_on = [
    google_service_networking_connection.psa,
    google_kms_crypto_key_iam_member.sqladmin,
  ]
}

resource "google_sql_database" "socfirst" {
  project  = google_project.tenant.project_id
  instance = google_sql_database_instance.main.name
  name     = "socfirst"
}

# Workloads log in with IAM database authentication (no password).
resource "google_sql_user" "workload" {
  project  = google_project.tenant.project_id
  instance = google_sql_database_instance.main.name
  name     = trimsuffix(google_service_account.workload.email, ".gserviceaccount.com")
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# Break-glass admin user. Password is kept only in Secret Manager.
resource "random_password" "sql_admin" {
  length           = 32
  special          = true
  override_special = "-_.~"
}

resource "google_sql_user" "admin" {
  project  = google_project.tenant.project_id
  instance = google_sql_database_instance.main.name
  name     = "socfirst_admin"
  password = random_password.sql_admin.result
}

resource "google_secret_manager_secret" "sql_admin" {
  project   = google_project.tenant.project_id
  secret_id = "sql-admin-password"
  labels    = local.labels

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "sql_admin" {
  secret      = google_secret_manager_secret.sql_admin.id
  secret_data = random_password.sql_admin.result
}
