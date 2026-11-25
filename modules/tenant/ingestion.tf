# ---------------------------------------------------------------------------
# Ingestion: Cloud Pub/Sub
# Flow 1 (customer GCP Log Router sink) and flow 2 (on-prem collector) publish to raw-logs.
# Flow 3 (Microsoft Graph Security API pull) is published by the detection engine.
# ---------------------------------------------------------------------------
resource "google_pubsub_topic" "raw_logs" {
  project                    = google_project.tenant.project_id
  name                       = "raw-logs"
  message_retention_duration = "604800s" # 7 days replay window
  labels                     = local.labels

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  depends_on = [google_project_service.services]
}

resource "google_pubsub_topic" "normalized" {
  project                    = google_project.tenant.project_id
  name                       = "normalized-events"
  message_retention_duration = "604800s"
  labels                     = local.labels

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  depends_on = [google_project_service.services]
}

resource "google_pubsub_topic" "dead_letter" {
  project = google_project.tenant.project_id
  name    = "dead-letter"
  labels  = local.labels

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  depends_on = [google_project_service.services]
}

# Normalized events are pushed to the detection engine (Cloud Run), authenticated with OIDC.
resource "google_pubsub_subscription" "detection_push" {
  project              = google_project.tenant.project_id
  name                 = "detection-engine-push"
  topic                = google_pubsub_topic.normalized.id
  ack_deadline_seconds = 60
  labels               = local.labels

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.detection.uri}/pubsub/push"

    oidc_token {
      service_account_email = google_service_account.pubsub_push.email
      audience              = google_cloud_run_v2_service.detection.uri
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 10
  }

  expiration_policy {
    ttl = "" # never expire
  }
}

# Holds undeliverable messages for SRE investigation and replay.
resource "google_pubsub_subscription" "dead_letter_hold" {
  project                    = google_project.tenant.project_id
  name                       = "dead-letter-hold"
  topic                      = google_pubsub_topic.dead_letter.id
  message_retention_duration = "604800s"
  labels                     = local.labels

  expiration_policy {
    ttl = ""
  }
}

# ---------------------------------------------------------------------------
# Ingestion: Cloud Storage raw-log archive
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "raw_logs" {
  project                     = google_project.tenant.project_id
  name                        = "${local.project_id}-raw-logs"
  location                    = upper(var.region)
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.labels

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.cmek.id
  }

  soft_delete_policy {
    retention_duration_seconds = 604800 # 7 days
  }

  lifecycle_rule {
    condition {
      age                   = 30
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age                   = 90
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = var.log_retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs]
}
