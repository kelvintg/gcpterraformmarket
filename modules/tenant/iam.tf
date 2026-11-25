# ---------------------------------------------------------------------------
# Service agents (Google-managed identities) that need cross-project or resource access
# ---------------------------------------------------------------------------
resource "google_project_service_identity" "run" {
  provider = google-beta
  project  = google_project.tenant.project_id
  service  = "run.googleapis.com"

  depends_on = [google_project_service.services]
}

resource "google_project_service_identity" "gcf" {
  provider = google-beta
  project  = google_project.tenant.project_id
  service  = "cloudfunctions.googleapis.com"

  depends_on = [google_project_service.services]
}

resource "google_project_service_identity" "pubsub" {
  provider = google-beta
  project  = google_project.tenant.project_id
  service  = "pubsub.googleapis.com"

  depends_on = [google_project_service.services]
}

# Cloud Run pulls SecurityOperationCenterFirst images from the shared registry.
resource "google_artifact_registry_repository_iam_member" "run_agent_pull" {
  project    = var.shared.project
  location   = var.shared.registry_location
  repository = var.shared.registry_repo
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_project_service_identity.run.email}"
}

# Function source is read from the shared release bucket.
resource "google_storage_bucket_iam_member" "release_read_gcf_agent" {
  bucket = var.shared.release_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_project_service_identity.gcf.email}"
}

# Pub/Sub must be able to move failed messages to the dead-letter topic.
resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  project = google_project.tenant.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_project_service_identity.pubsub.email}"
}

resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  project      = google_project.tenant.project_id
  subscription = google_pubsub_subscription.detection_push.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_project_service_identity.pubsub.email}"
}

# ---------------------------------------------------------------------------
# Workload service accounts (one per component, least privilege)
# ---------------------------------------------------------------------------
resource "google_service_account" "fn_build" {
  project      = google_project.tenant.project_id
  account_id   = "fn-build"
  display_name = "Cloud Functions build"

  depends_on = [google_project_service.services]
}

resource "google_service_account" "fn_normalizer" {
  project      = google_project.tenant.project_id
  account_id   = "fn-log-normalizer"
  display_name = "Function log-normalizer runtime"

  depends_on = [google_project_service.services]
}

resource "google_service_account" "eventarc" {
  project      = google_project.tenant.project_id
  account_id   = "eventarc-trigger"
  display_name = "Eventarc trigger for log-normalizer"

  depends_on = [google_project_service.services]
}

resource "google_service_account" "run_detection" {
  project      = google_project.tenant.project_id
  account_id   = "run-detection-engine"
  display_name = "Cloud Run detection-engine runtime"

  depends_on = [google_project_service.services]
}

resource "google_service_account" "run_api" {
  project      = google_project.tenant.project_id
  account_id   = "run-portal-api"
  display_name = "Cloud Run soc-portal-api runtime"

  depends_on = [google_project_service.services]
}

resource "google_service_account" "pubsub_push" {
  project      = google_project.tenant.project_id
  account_id   = "pubsub-push"
  display_name = "Pub/Sub push to detection-engine"

  depends_on = [google_project_service.services]
}

# Used by the customer's on-premises SecurityOperationCenterFirst Log Collector (flow 2)
# through Workload Identity Federation, which is set up during customer onboarding.
resource "google_service_account" "collector" {
  project      = google_project.tenant.project_id
  account_id   = "collector-ingest"
  display_name = substr("On-prem log collector (${var.customer_display_name})", 0, 100)

  depends_on = [google_project_service.services]
}

# --- Function build ---
resource "google_project_iam_member" "fn_build" {
  project = google_project.tenant.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.fn_build.email}"
}

resource "google_storage_bucket_iam_member" "release_read_build" {
  bucket = var.shared.release_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.fn_build.email}"
}

# --- log-normalizer ---
resource "google_bigquery_dataset_iam_member" "normalizer_events" {
  project    = google_project.tenant.project_id
  dataset_id = google_bigquery_dataset.events.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.fn_normalizer.email}"
}

resource "google_storage_bucket_iam_member" "normalizer_raw" {
  bucket = google_storage_bucket.raw_logs.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.fn_normalizer.email}"
}

resource "google_pubsub_topic_iam_member" "normalizer_publish" {
  project = google_project.tenant.project_id
  topic   = google_pubsub_topic.normalized.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.fn_normalizer.email}"
}

resource "google_cloud_run_v2_service_iam_member" "eventarc_invoke_normalizer" {
  project  = google_project.tenant.project_id
  location = var.region
  name     = google_cloudfunctions2_function.normalizer.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc.email}"
}

# --- detection-engine ---
resource "google_cloud_run_v2_service_iam_member" "push_invoke_detection" {
  project  = google_project.tenant.project_id
  location = var.region
  name     = google_cloud_run_v2_service.detection.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_push.email}"
}

resource "google_bigquery_dataset_iam_member" "detection_events" {
  project    = google_project.tenant.project_id
  dataset_id = google_bigquery_dataset.events.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.run_detection.email}"
}

resource "google_bigquery_dataset_iam_member" "detection_detections" {
  project    = google_project.tenant.project_id
  dataset_id = google_bigquery_dataset.detections.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.run_detection.email}"
}

resource "google_secret_manager_secret_iam_member" "detection_openai" {
  project   = google_project.tenant.project_id
  secret_id = google_secret_manager_secret.openai.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_detection.email}"
}

resource "google_pubsub_topic_iam_member" "detection_publish_raw" {
  # Flow 3: alerts pulled from Microsoft Graph Security API are published to raw-logs.
  project = google_project.tenant.project_id
  topic   = google_pubsub_topic.raw_logs.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.run_detection.email}"
}

# --- soc-portal-api ---
resource "google_bigquery_dataset_iam_member" "api_events" {
  project    = google_project.tenant.project_id
  dataset_id = google_bigquery_dataset.events.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.run_api.email}"
}

resource "google_bigquery_dataset_iam_member" "api_detections" {
  project    = google_project.tenant.project_id
  dataset_id = google_bigquery_dataset.detections.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.run_api.email}"
}

resource "google_storage_bucket_iam_member" "api_raw_read" {
  bucket = google_storage_bucket.raw_logs.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.run_api.email}"
}

# --- project-level roles shared by the runtimes ---
locals {
  runtime_roles = {
    detection = {
      member = "serviceAccount:${google_service_account.run_detection.email}"
      roles  = ["roles/bigquery.jobUser", "roles/datastore.user", "roles/aiplatform.user", "roles/logging.logWriter", "roles/monitoring.metricWriter"]
    }
    api = {
      member = "serviceAccount:${google_service_account.run_api.email}"
      roles  = ["roles/bigquery.jobUser", "roles/datastore.user", "roles/logging.logWriter", "roles/monitoring.metricWriter"]
    }
    normalizer = {
      member = "serviceAccount:${google_service_account.fn_normalizer.email}"
      roles  = ["roles/logging.logWriter", "roles/monitoring.metricWriter"]
    }
    eventarc = {
      member = "serviceAccount:${google_service_account.eventarc.email}"
      roles  = ["roles/eventarc.eventReceiver"]
    }
  }

  runtime_bindings = merge([
    for k, v in local.runtime_roles : {
      for r in v.roles : "${k}:${r}" => { member = v.member, role = r }
    }
  ]...)
}

resource "google_project_iam_member" "runtime" {
  for_each = local.runtime_bindings

  project = google_project.tenant.project_id
  role    = each.value.role
  member  = each.value.member
}

# --- on-prem collector (flow 2) ---
resource "google_pubsub_topic_iam_member" "collector_publish" {
  project = google_project.tenant.project_id
  topic   = google_pubsub_topic.raw_logs.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.collector.email}"
}

resource "google_storage_bucket_iam_member" "collector_upload" {
  bucket = google_storage_bucket.raw_logs.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.collector.email}"
}

# ---------------------------------------------------------------------------
# SecurityOperationCenterFirst SRE group: read-only by default.
# It may add (not read) the OpenAI key version in phase 5.
# ---------------------------------------------------------------------------
resource "google_project_iam_member" "ops_viewer" {
  project = google_project.tenant.project_id
  role    = "roles/viewer"
  member  = var.ops_group
}

resource "google_secret_manager_secret_iam_member" "ops_add_openai_key" {
  project   = google_project.tenant.project_id
  secret_id = google_secret_manager_secret.openai.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = var.ops_group
}
