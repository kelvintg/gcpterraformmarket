# Least-privilege node service account (instead of the Compute Engine default SA).
resource "google_service_account" "gke_nodes" {
  project      = google_project.tenant.project_id
  account_id   = "gke-nodes"
  display_name = "GKE Autopilot nodes (${var.tenant_name})"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "gke_nodes_default" {
  project = google_project.tenant.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Nodes pull Security Operation Center First images from the central registry in socfirst-shared.
resource "google_artifact_registry_repository_iam_member" "gke_nodes_pull" {
  project    = var.shared_artifact_registry.project
  location   = var.shared_artifact_registry.location
  repository = var.shared_artifact_registry.repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "autopilot" {
  project          = google_project.tenant.project_id
  name             = "gke-${var.tenant_name}-prod"
  location         = var.region
  enable_autopilot = true

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.gke_master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.gke_master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_nodes.email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  }

  # Saturday and Sunday 17:00-01:00 UTC (01:00-09:00 Singapore time).
  maintenance_policy {
    recurring_window {
      start_time = "2026-01-03T17:00:00Z"
      end_time   = "2026-01-04T01:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  resource_labels     = local.labels
  deletion_protection = true

  depends_on = [
    google_project_iam_member.gke_nodes_default,
    google_compute_router_nat.nat,
  ]
}
