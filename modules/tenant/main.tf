locals {
  project_id = "customer-${var.tenant_name}-prod"

  labels = merge({
    tenant            = var.tenant_name
    env               = "prod"
    product           = "socfirst"
    managed-by        = "terraform"
    marketplace-order = var.marketplace_order_id
  }, var.labels)

  services = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "storage.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

# One dedicated project per customer, in the Security Operation Center First organization,
# billed to the Security Operation Center First partner billing account.
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
