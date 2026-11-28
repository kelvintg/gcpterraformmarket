locals {
  project_id   = "customer-${var.tenant_name}-prod"
  api_hostname = "api.${var.tenant_name}.${var.base_domain}"

  labels = merge({
    tenant            = var.tenant_name
    env               = "prod"
    product           = "securityoperationcenterfirst"
    managed-by        = "terraform"
    marketplace-order = var.marketplace_order_id
  }, var.labels)

  # Pull images from the Artifact Registry multi-region nearest the tenant region.
  geography = split("-", var.region)[0]
  registry_location = lookup({
    us           = "us"
    northamerica = "us"
    southamerica = "us"
    europe       = "europe"
    me           = "europe"
    africa       = "europe"
    asia         = "asia"
    australia    = "asia"
  }, local.geography, "us")
  registry = "${local.registry_location}-docker.pkg.dev/${var.shared.project}/${var.shared.registry_repo}"

  vertex_location = var.vertex_location != "" ? var.vertex_location : var.region
  images = {
    portal_api = "${local.registry}/soc-portal-api:${var.release_version}"
    detection  = "${local.registry}/detection-engine:${var.release_version}"
  }

  services = [
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "eventarc.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "identitytoolkit.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
  ]
}

# One dedicated project per customer, in the SecurityOperationCenterFirst organization,
# billed to the SecurityOperationCenterFirst partner billing account.
resource "google_project" "tenant" {
  project_id          = local.project_id
  name                = local.project_id
  folder_id           = var.tenants_folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  labels              = local.labels
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "services" {
  for_each = toset(local.services)

  project                    = google_project.tenant.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
