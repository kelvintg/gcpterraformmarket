# ---------------------------------------------------------------------------
# Frontend: Cloud Run portal API (behind Cloud Load Balancing + Cloud Armor)
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "portal_api" {
  project  = google_project.tenant.project_id
  name     = "soc-portal-api"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" # only reachable through the load balancer
  labels   = local.labels

  template {
    service_account = google_service_account.run_api.email

    scaling {
      min_instance_count = var.api_min_instances
      max_instance_count = 20
    }

    containers {
      image = local.images.portal_api

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
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
        name  = "ALLOWED_ORIGIN"
        value = "https://${google_firebase_hosting_site.portal.site_id}.web.app"
      }
    }
  }

  depends_on = [google_artifact_registry_repository_iam_member.run_agent_pull]
}

# The API authenticates every request itself (Firebase Authentication ID tokens).
# Cloud Run IAM is open because ingress is restricted to the load balancer above.
resource "google_cloud_run_v2_service_iam_member" "portal_api_public" {
  project  = google_project.tenant.project_id
  location = var.region
  name     = google_cloud_run_v2_service.portal_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------
# Frontend: Firebase (Hosting for the analyst portal, Authentication for sign-in)
# Customer SSO (SAML / OIDC) is configured during customer onboarding, not here.
# ---------------------------------------------------------------------------
resource "google_firebase_project" "tenant" {
  provider = google-beta
  project  = google_project.tenant.project_id

  depends_on = [google_project_service.services]
}

resource "google_firebase_web_app" "portal" {
  provider     = google-beta
  project      = google_project.tenant.project_id
  display_name = "SOC portal (${var.tenant_name})"

  depends_on = [google_firebase_project.tenant]
}

resource "google_firebase_hosting_site" "portal" {
  provider = google-beta
  project  = google_project.tenant.project_id
  site_id  = "${local.project_id}-portal"
  app_id   = google_firebase_web_app.portal.app_id
}
