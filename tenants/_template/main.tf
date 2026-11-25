# Root configuration for ONE tenant. Generated from tenants/_template by scripts/new-tenant.sh.
# Do not edit generated copies by hand except terraform.tfvars.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0, < 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

# Credentials: the pipeline runs as tf-tenant-provisioner@socfirst-automation.iam.gserviceaccount.com.
# For a local run, set GOOGLE_IMPERSONATE_SERVICE_ACCOUNT to that account instead of using personal rights.
provider "google" {
  region                = var.region
  billing_project       = "socfirst-automation"
  user_project_override = true
}

provider "google-beta" {
  region                = var.region
  billing_project       = "socfirst-automation"
  user_project_override = true
}

variable "tenant_name" { type = string }
variable "customer_display_name" { type = string }
variable "marketplace_order_id" { type = string }
variable "billing_account" { type = string }
variable "tenants_folder_id" { type = string }
variable "region" { type = string }
variable "ops_group" { type = string }
variable "gke_master_authorized_cidrs" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}
variable "sql_tier" {
  type    = string
  default = "db-custom-2-7680"
}
variable "sql_availability_type" {
  type    = string
  default = "REGIONAL"
}
variable "log_retention_days" {
  type    = number
  default = 365
}

module "tenant" {
  source = "../../modules/tenant"

  tenant_name                 = var.tenant_name
  customer_display_name       = var.customer_display_name
  marketplace_order_id        = var.marketplace_order_id
  billing_account             = var.billing_account
  tenants_folder_id           = var.tenants_folder_id
  region                      = var.region
  ops_group                   = var.ops_group
  gke_master_authorized_cidrs = var.gke_master_authorized_cidrs
  sql_tier                    = var.sql_tier
  sql_availability_type       = var.sql_availability_type
  log_retention_days          = var.log_retention_days
}

output "tenant" {
  description = "Everything the Helm deployment and the tenant register need."
  value = {
    project_id               = module.tenant.project_id
    project_number           = module.tenant.project_number
    billing_account          = module.tenant.billing_account
    region                   = module.tenant.region
    gke_cluster_name         = module.tenant.gke_cluster_name
    sql_instance_name        = module.tenant.sql_instance_name
    sql_connection_name      = module.tenant.sql_connection_name
    sql_private_ip           = module.tenant.sql_private_ip
    sql_iam_user             = module.tenant.sql_iam_user
    logs_bucket              = module.tenant.logs_bucket
    kms_key_id               = module.tenant.kms_key_id
    workload_service_account = module.tenant.workload_service_account
    k8s_namespace            = module.tenant.k8s_namespace
    k8s_service_account      = module.tenant.k8s_service_account
  }
}
