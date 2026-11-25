# ---------------------------------------------------------------------------
# Security: Cloud Armor policy (WAF, rate limiting, adaptive DDoS protection)
# ---------------------------------------------------------------------------
resource "google_compute_security_policy" "edge" {
  project     = google_project.tenant.project_id
  name        = "armor-${var.tenant_name}"
  description = "Edge policy for the ${var.tenant_name} portal API"
  type        = "CLOUD_ARMOR"

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "OWASP: SQL injection"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1001
    description = "OWASP: cross-site scripting"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1002
    description = "OWASP: local file inclusion"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('lfi-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action      = "throttle"
    priority    = 2000
    description = "600 requests per minute per client IP"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 600
        interval_sec = 60
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  depends_on = [google_project_service.services]
}

# ---------------------------------------------------------------------------
# Security: Cloud Load Balancing (global external Application Load Balancer)
# https://api.<tenant>.<base_domain>  ->  Cloud Armor  ->  serverless NEG  ->  soc-portal-api
# ---------------------------------------------------------------------------
resource "google_compute_global_address" "api" {
  project = google_project.tenant.project_id
  name    = "lb-ip-${var.tenant_name}"

  depends_on = [google_project_service.services]
}

resource "google_compute_region_network_endpoint_group" "portal_api" {
  project               = google_project.tenant.project_id
  name                  = "neg-soc-portal-api"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.portal_api.name
  }
}

resource "google_compute_backend_service" "portal_api" {
  project               = google_project.tenant.project_id
  name                  = "bes-soc-portal-api"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = google_compute_security_policy.edge.id

  backend {
    group = google_compute_region_network_endpoint_group.portal_api.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "api" {
  project         = google_project.tenant.project_id
  name            = "urlmap-${var.tenant_name}"
  default_service = google_compute_backend_service.portal_api.id
}

resource "google_compute_managed_ssl_certificate" "api" {
  project = google_project.tenant.project_id
  name    = "cert-api-${var.tenant_name}"

  managed {
    domains = [local.api_hostname]
  }

  depends_on = [google_project_service.services]
}

resource "google_compute_ssl_policy" "tls12" {
  project         = google_project.tenant.project_id
  name            = "tls12-modern"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"

  depends_on = [google_project_service.services]
}

resource "google_compute_target_https_proxy" "api" {
  project          = google_project.tenant.project_id
  name             = "https-proxy-${var.tenant_name}"
  url_map          = google_compute_url_map.api.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api.id]
  ssl_policy       = google_compute_ssl_policy.tls12.id
}

resource "google_compute_global_forwarding_rule" "https" {
  project               = google_project.tenant.project_id
  name                  = "fr-https-${var.tenant_name}"
  ip_address            = google_compute_global_address.api.id
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.api.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  labels                = local.labels
}

# DNS record in the shared public zone. The managed certificate becomes ACTIVE
# once this record resolves (typically 15-60 minutes after apply).
resource "google_dns_record_set" "api" {
  project      = var.shared.project
  managed_zone = var.shared.dns_zone
  name         = "${local.api_hostname}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.api.address]
}
