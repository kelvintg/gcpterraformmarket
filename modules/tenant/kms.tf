# Customer-managed encryption key (CMEK) dedicated to this tenant.
# Encrypts the raw-log bucket and both BigQuery datasets.
resource "google_kms_key_ring" "tenant" {
  project  = google_project.tenant.project_id
  name     = "kr-${var.tenant_name}"
  location = var.region

  depends_on = [google_project_service.services]
}

resource "google_kms_crypto_key" "cmek" {
  name            = "cmek-${var.tenant_name}"
  key_ring        = google_kms_key_ring.tenant.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days
  labels          = local.labels

  lifecycle {
    prevent_destroy = true
  }
}

# Service agents that must be allowed to use the key.
data "google_storage_project_service_account" "gcs" {
  project = google_project.tenant.project_id

  depends_on = [google_project_service.services]
}

data "google_bigquery_default_service_account" "bq" {
  project = google_project.tenant.project_id

  depends_on = [google_project_service.services]
}

resource "google_kms_crypto_key_iam_member" "gcs" {
  crypto_key_id = google_kms_crypto_key.cmek.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_kms_crypto_key_iam_member" "bq" {
  crypto_key_id = google_kms_crypto_key.cmek.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_bigquery_default_service_account.bq.email}"
}
