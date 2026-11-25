# Google service account used by the Security Operation Center First pods through Workload Identity.
resource "google_service_account" "workload" {
  project      = google_project.tenant.project_id
  account_id   = "socfirst-workload"
  display_name = substr("Security Operation Center First workloads (${var.customer_display_name})", 0, 100) # GCP limit: 100 chars

  depends_on = [google_project_service.services]
}

# The <project>.svc.id.goog identity pool exists only after the cluster is created.
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"

  depends_on = [google_container_cluster.autopilot]
}

resource "google_project_iam_member" "workload" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/cloudsql.instanceUser",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = google_project.tenant.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workload.email}"
}

resource "google_storage_bucket_iam_member" "workload_logs" {
  bucket = google_storage_bucket.soc_logs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.workload.email}"
}

# Security Operation Center First SRE group: read everything, deploy to the cluster. No data-plane admin by default.
resource "google_project_iam_member" "ops" {
  for_each = toset([
    "roles/viewer",
    "roles/container.developer",
  ])

  project = google_project.tenant.project_id
  role    = each.value
  member  = var.ops_group
}
