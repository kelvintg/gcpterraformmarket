# ---------------------------------------------------------------------------
# Tenant identity
# ---------------------------------------------------------------------------
variable "tenant_name" {
  description = "Short customer slug used in every resource name. Project ID becomes customer-<tenant_name>-prod."
  type        = string

  validation {
    # customer- (9) + name + -prod (5) must fit the 30-character project ID limit.
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}[a-z0-9]$", var.tenant_name))
    error_message = "tenant_name must be 3-16 characters, start with a letter, end with a letter or digit, and use only lowercase letters, digits and hyphens."
  }
}

variable "customer_display_name" {
  description = "Customer's legal or display name, for descriptions only."
  type        = string
}

variable "marketplace_order_id" {
  description = "Google Cloud Marketplace order / entitlement ID for this customer. Stored as a label for billing reconciliation."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.marketplace_order_id))
    error_message = "marketplace_order_id must be 1-63 lowercase letters, digits, hyphens or underscores (GCP label rules)."
  }
}

# ---------------------------------------------------------------------------
# Placement and billing
# ---------------------------------------------------------------------------
variable "billing_account" {
  description = "Billing account the tenant project is created under."
  type        = string
  default     = "010C56-DBE422-956EBA"

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "billing_account must look like XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "tenants_folder_id" {
  description = "Numeric ID of the folder SecurityOperationCenterFirst > Tenants > Production."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{6,20}$", var.tenants_folder_id))
    error_message = "tenants_folder_id must be the numeric folder ID (without the folders/ prefix)."
  }
}

variable "region" {
  description = "Region for all regional resources of this tenant (Cloud Run, Functions, Firestore, BigQuery, Vertex AI, Cloud Storage, KMS)."
  type        = string
  default     = "asia-southeast1"
}

variable "labels" {
  description = "Extra labels merged into the standard tenant labels."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Release and shared platform resources
# ---------------------------------------------------------------------------
variable "release_version" {
  description = "SecurityOperationCenterFirst platform release deployed to this tenant (container image tag and artifact folder)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{4}\\.[0-9]{1,2}\\.[0-9]+$", var.release_version))
    error_message = "release_version must look like 2026.11.2."
  }
}

variable "shared" {
  description = "Shared platform resources in project socfirst-shared, used by every tenant."
  type = object({
    project           = string # shared project ID
    registry_location = string # Artifact Registry location of the container images
    registry_repo     = string # Artifact Registry repository
    release_bucket    = string # bucket holding function sources, portal bundles and model artifacts
    dns_zone          = string # Cloud DNS managed zone for base_domain
  })
  default = {
    project           = "socfirst-shared"
    registry_location = "asia-southeast1"
    registry_repo     = "socfirst"
    release_bucket    = "socfirst-shared-releases"
    dns_zone          = "socfirst-public"
  }
}

variable "base_domain" {
  description = "Public DNS domain served by the shared zone. The tenant API becomes api.<tenant_name>.<base_domain>."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.base_domain))
    error_message = "base_domain must be a lowercase DNS name such as soc.example.com."
  }
}

# ---------------------------------------------------------------------------
# Data retention and sizing
# ---------------------------------------------------------------------------
variable "log_retention_days" {
  description = "Days raw logs (Cloud Storage) and normalized events (BigQuery partitions) are kept."
  type        = number
  default     = 365
}

variable "api_min_instances" {
  description = "Minimum Cloud Run instances for the portal API (1 avoids cold starts for analysts)."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# Access and alerting
# ---------------------------------------------------------------------------
variable "ops_group" {
  description = "IAM principal of the SecurityOperationCenterFirst SRE group, e.g. group:socfirst-sre@example.com."
  type        = string

  validation {
    condition     = can(regex("^group:.+@.+$", var.ops_group))
    error_message = "ops_group must be in the form group:<name>@<domain>."
  }
}

variable "notification_channels" {
  description = "Cloud Monitoring notification channel IDs for tenant alerts (SRE on-call)."
  type        = list(string)
  default     = []
}
