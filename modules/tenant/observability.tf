# ---------------------------------------------------------------------------
# Cloud Logging: keep the tenant's platform logs 90 days (default is 30).
# ---------------------------------------------------------------------------
resource "google_logging_project_bucket_config" "default" {
  project        = google_project.tenant.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = 90

  depends_on = [google_project_service.services]
}

# ---------------------------------------------------------------------------
# Cloud Monitoring: API uptime and ingestion backlog
# ---------------------------------------------------------------------------
resource "google_monitoring_uptime_check_config" "api" {
  project      = google_project.tenant.project_id
  display_name = "${var.tenant_name} portal API /healthz"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = "/healthz"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = google_project.tenant.project_id
      host       = local.api_hostname
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_monitoring_alert_policy" "detection_backlog" {
  project      = google_project.tenant.project_id
  display_name = "${var.tenant_name}: detection backlog older than 10 minutes"
  combiner     = "OR"

  conditions {
    display_name = "Oldest unacked message on detection-engine-push > 600 s"

    condition_threshold {
      filter          = "resource.type = \"pubsub_subscription\" AND resource.labels.subscription_id = \"${google_pubsub_subscription.detection_push.name}\" AND metric.type = \"pubsub.googleapis.com/subscription/oldest_unacked_message_age\""
      comparison      = "COMPARISON_GT"
      threshold_value = 600
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = var.notification_channels
  user_labels           = local.labels
}
