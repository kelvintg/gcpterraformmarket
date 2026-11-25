# ---------------------------------------------------------------------------
# Storage: Firestore (alerts, cases, analyst workflow state)
# ---------------------------------------------------------------------------
resource "google_firestore_database" "main" {
  project                           = google_project.tenant.project_id
  name                              = "(default)"
  location_id                       = var.region
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
  delete_protection_state           = "DELETE_PROTECTION_ENABLED"

  depends_on = [google_project_service.services]
}

resource "google_firestore_backup_schedule" "daily" {
  project   = google_project.tenant.project_id
  database  = google_firestore_database.main.name
  retention = "1209600s" # 14 days

  daily_recurrence {}
}

# ---------------------------------------------------------------------------
# Storage: BigQuery (SIEM data lake)
# ---------------------------------------------------------------------------
resource "google_bigquery_dataset" "events" {
  project                         = google_project.tenant.project_id
  dataset_id                      = "soc_events"
  friendly_name                   = "Normalized security events"
  description                     = "Normalized log events for ${var.customer_display_name}. Partitions expire after ${var.log_retention_days} days."
  location                        = var.region
  default_partition_expiration_ms = var.log_retention_days * 86400000
  delete_contents_on_destroy      = false
  labels                          = local.labels

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.cmek.id
  }

  depends_on = [google_kms_crypto_key_iam_member.bq]
}

resource "google_bigquery_dataset" "detections" {
  project                    = google_project.tenant.project_id
  dataset_id                 = "soc_detections"
  friendly_name              = "Detections and alert history"
  description                = "Detection results, alert history and analyst metrics for ${var.customer_display_name}."
  location                   = var.region
  delete_contents_on_destroy = false
  labels                     = local.labels

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.cmek.id
  }

  depends_on = [google_kms_crypto_key_iam_member.bq]
}

# ---------------------------------------------------------------------------
# AI/ML: Vertex AI endpoint for the tenant's custom anomaly model.
# The model itself is uploaded and deployed by the tenant-release pipeline (phase 5).
# ---------------------------------------------------------------------------
resource "google_vertex_ai_endpoint" "anomaly" {
  project      = google_project.tenant.project_id
  name         = "1001" # numeric endpoint ID, unique within this tenant project
  display_name = "soc-anomaly-detector"
  description  = "Custom anomaly-detection model for ${var.customer_display_name}"
  location     = var.region
  region       = var.region
  labels       = local.labels

  depends_on = [google_project_service.services]
}

# ---------------------------------------------------------------------------
# AI/ML: OpenAI API key (Other Cloud Provider). Terraform creates the empty secret;
# the key itself is added by an engineer in phase 5 and never passes through Terraform state.
# ---------------------------------------------------------------------------
resource "google_secret_manager_secret" "openai" {
  project   = google_project.tenant.project_id
  secret_id = "openai-api-key"
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
