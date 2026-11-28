# ---------------------------------------------------------------------------
# Backend: Cloud Functions (2nd gen) log normalizer
# raw-logs (Pub/Sub) -> parse + enrich -> raw archive (GCS), soc_events (BigQuery), normalized-events (Pub/Sub)
# ---------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "normalizer" {
  project     = google_project.tenant.project_id
  name        = "log-normalizer"
  location    = var.region
  description = "Parses raw customer logs, archives them and publishes normalized events."
  labels      = local.labels

  build_config {
    runtime         = "python312"
    entry_point     = "handle_raw_log"
    service_account = google_service_account.fn_build.id

    source {
      storage_source {
        bucket = var.shared.release_bucket
        object = "functions/log-normalizer/${var.release_version}.zip"
      }
    }
  }

  service_config {
    available_memory               = "512Mi"
    timeout_seconds                = 120
    min_instance_count             = 0
    max_instance_count             = 50
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.fn_normalizer.email

    environment_variables = {
      TENANT           = var.tenant_name
      GCP_PROJECT      = google_project.tenant.project_id
      BQ_DATASET       = google_bigquery_dataset.events.dataset_id
      RAW_BUCKET       = google_storage_bucket.raw_logs.name
      NORMALIZED_TOPIC = google_pubsub_topic.normalized.id
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.raw_logs.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.eventarc.email
  }

  depends_on = [
    google_project_iam_member.fn_build,
    google_storage_bucket_iam_member.release_read_build,
    google_storage_bucket_iam_member.release_read_gcf_agent,
  ]
}

# ---------------------------------------------------------------------------
# Backend: Cloud Run detection engine
# Runs detection rules on normalized events, scores them with the Vertex AI custom model,
# triages and enriches alerts with Gemini, and writes alerts and cases to Firestore and BigQuery.
# Reachable only from Pub/Sub push.
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "detection" {
  project  = google_project.tenant.project_id
  name     = "detection-engine"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  labels   = local.labels

  template {
    service_account                  = google_service_account.run_detection.email
    max_instance_request_concurrency = 40

    scaling {
      min_instance_count = 0
      max_instance_count = 30
    }

    containers {
      image = local.images.detection

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }

      env {
        name  = "TENANT"
        value = var.tenant_name
      }
      env {
        name  = "GCP_PROJECT"
        value = google_project.tenant.project_id
      }
      env {
        name  = "BQ_EVENTS_DATASET"
        value = google_bigquery_dataset.events.dataset_id
      }
      env {
        name  = "BQ_DETECTIONS_DATASET"
        value = google_bigquery_dataset.detections.dataset_id
      }
      env {
        name  = "VERTEX_ENDPOINT"
        value = google_vertex_ai_endpoint.anomaly.id
      }
      env {
        name  = "GEMINI_MODEL"
        value = var.gemini_model
      }
      env {
        name  = "GEMINI_REASONING_MODEL"
        value = var.gemini_reasoning_model
      }
      env {
        name  = "GEMINI_LOCATION"
        value = var.gemini_location
      }
    }
  }

  depends_on = [google_artifact_registry_repository_iam_member.run_agent_pull]
}
