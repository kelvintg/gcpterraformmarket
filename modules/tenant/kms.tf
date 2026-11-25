# Customer-managed encryption key (CMEK) dedicated to this tenant.
# Used by Cloud SQL and the Cloud Storage bucket.
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
resource "google_project_service_identity" "sqladmin" {
  provider = google-beta
  project  = google_project.tenant.project_id
  service  = "sqladmin.googleapis.com"

  depends_on = [google_project_service.services]
}

data "google_storage_project_service_account" "gcs" {
  project = google_project.tenant.project_id

  depends_on = [google_project_service.services]
}

resource "google_kms_crypto_key_iam_member" "sqladmin" {
  crypto_key_id = google_kms_crypto_key.cmek.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.sqladmin.email}"
}

resource "google_kms_crypto_key_iam_member" "gcs" {
  crypto_key_id = google_kms_crypto_key.cmek.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}
