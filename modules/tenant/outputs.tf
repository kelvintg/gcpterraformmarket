output "project_id" {
  description = "Tenant project ID (customer-<name>-prod)."
  value       = google_project.tenant.project_id
}

output "project_number" {
  description = "Tenant project number."
  value       = google_project.tenant.number
}

output "billing_account" {
  description = "Billing account the project is linked to."
  value       = google_project.tenant.billing_account
}

output "region" {
  description = "Region of the tenant's regional resources."
  value       = var.region
}

output "release_version" {
  description = "Platform release deployed to this tenant."
  value       = var.release_version
}

output "api_hostname" {
  description = "Public hostname of the portal API."
  value       = local.api_hostname
}

output "lb_ip" {
  description = "Global IP address of the load balancer."
  value       = google_compute_global_address.api.address
}

output "ssl_certificate" {
  description = "Google-managed certificate name."
  value       = google_compute_managed_ssl_certificate.api.name
}

output "armor_policy" {
  description = "Cloud Armor policy name."
  value       = google_compute_security_policy.edge.name
}

output "backend_service" {
  description = "Load balancer backend service name."
  value       = google_compute_backend_service.portal_api.name
}

output "raw_logs_topic" {
  description = "Pub/Sub topic customers' log sources publish to."
  value       = google_pubsub_topic.raw_logs.id
}

output "normalized_topic" {
  description = "Pub/Sub topic of normalized events."
  value       = google_pubsub_topic.normalized.id
}

output "function_name" {
  description = "Cloud Functions log normalizer."
  value       = google_cloudfunctions2_function.normalizer.name
}

output "run_portal_api" {
  description = "Cloud Run portal API service."
  value       = google_cloud_run_v2_service.portal_api.name
}

output "run_detection_engine" {
  description = "Cloud Run detection engine service."
  value       = google_cloud_run_v2_service.detection.name
}

output "firestore_database" {
  description = "Firestore database."
  value       = google_firestore_database.main.name
}

output "bq_events_dataset" {
  description = "BigQuery dataset of normalized events."
  value       = google_bigquery_dataset.events.dataset_id
}

output "bq_detections_dataset" {
  description = "BigQuery dataset of detections."
  value       = google_bigquery_dataset.detections.dataset_id
}

output "raw_logs_bucket" {
  description = "Raw-log archive bucket."
  value       = google_storage_bucket.raw_logs.name
}

output "vertex_endpoint_id" {
  description = "Numeric Vertex AI endpoint ID."
  value       = google_vertex_ai_endpoint.anomaly.name
}

output "firebase_hosting_site" {
  description = "Firebase Hosting site ID of the analyst portal."
  value       = google_firebase_hosting_site.portal.site_id
}

output "firebase_web_app_id" {
  description = "Firebase web app ID."
  value       = google_firebase_web_app.portal.app_id
}

output "openai_secret" {
  description = "Secret Manager secret that holds the tenant's OpenAI API key."
  value       = google_secret_manager_secret.openai.secret_id
}

output "collector_service_account" {
  description = "Service account the on-prem collector uses through Workload Identity Federation."
  value       = google_service_account.collector.email
}

output "kms_key_id" {
  description = "CMEK key used by Cloud Storage and BigQuery."
  value       = google_kms_crypto_key.cmek.id
}
