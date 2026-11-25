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
  description = "Numeric ID of the folder Security Operation Center First > Tenants > Production."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{6,20}$", var.tenants_folder_id))
    error_message = "tenants_folder_id must be the numeric folder ID (without the folders/ prefix)."
  }
}

variable "region" {
  description = "Region for all regional resources of this tenant."
  type        = string
  default     = "asia-southeast1"
}

variable "labels" {
  description = "Extra labels merged into the standard tenant labels."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
# Each tenant has its own isolated VPC, so these ranges are safely reused across tenants.
variable "subnet_cidr" {
  description = "Primary range of the GKE subnet."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for GKE Pods."
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range for GKE Services."
  type        = string
  default     = "10.20.0.0/20"
}

variable "gke_master_cidr" {
  description = "/28 range for the GKE control plane of the private cluster."
  type        = string
  default     = "172.16.0.0/28"
}

variable "psa_address" {
  description = "Start address of the Private Service Access range used by Cloud SQL."
  type        = string
  default     = "10.64.0.0"
}

variable "psa_prefix_length" {
  description = "Prefix length of the Private Service Access range."
  type        = number
  default     = 20
}

variable "gke_master_authorized_cidrs" {
  description = "CIDRs allowed to reach the GKE control plane (Security Operation Center First ops VPN / bastion egress)."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}

# ---------------------------------------------------------------------------
# Cloud SQL
# ---------------------------------------------------------------------------
variable "sql_tier" {
  description = "Cloud SQL machine tier. Default: 2 vCPU / 7.5 GB."
  type        = string
  default     = "db-custom-2-7680"
}

variable "sql_disk_size_gb" {
  description = "Initial SSD size in GB (auto-resize is on)."
  type        = number
  default     = 50
}

variable "sql_availability_type" {
  description = "REGIONAL (high availability, production default) or ZONAL."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.sql_availability_type)
    error_message = "sql_availability_type must be REGIONAL or ZONAL."
  }
}

# ---------------------------------------------------------------------------
# Cloud Storage
# ---------------------------------------------------------------------------
variable "log_retention_days" {
  description = "Days raw logs are kept in the tenant bucket before deletion."
  type        = number
  default     = 365
}

# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------
variable "ops_group" {
  description = "IAM principal of the Security Operation Center First SRE group, e.g. group:socfirst-sre@example.com."
  type        = string

  validation {
    condition     = can(regex("^group:.+@.+$", var.ops_group))
    error_message = "ops_group must be in the form group:<name>@<domain>."
  }
}

variable "shared_artifact_registry" {
  description = "Central Artifact Registry repository holding Security Operation Center First images and Helm charts."
  type = object({
    project    = string
    location   = string
    repository = string
  })
  default = {
    project    = "socfirst-shared"
    location   = "asia-southeast1"
    repository = "socfirst"
  }
}

variable "k8s_namespace" {
  description = "Kubernetes namespace of the Security Operation Center First workloads."
  type        = string
  default     = "socfirst"
}

variable "k8s_service_account" {
  description = "Kubernetes service account bound to the workload Google service account through Workload Identity."
  type        = string
  default     = "socfirst-workload"
}
