# Root configuration for ONE SecurityOperationCenterFirst tenant.
# Generated from tenants/_template by scripts/new-tenant.sh. Edit only terraform.tfvars in generated copies.

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
variable "release_version" { type = string }
variable "base_domain" { type = string }
variable "ops_group" { type = string }
variable "notification_channels" {
  type    = list(string)
  default = []
}
variable "log_retention_days" {
  type    = number
  default = 365
}
variable "api_min_instances" {
  type    = number
  default = 1
}
variable "gemini_model" {
  type    = string
  default = "gemini-3.8-flash"
}
variable "gemini_reasoning_model" {
  type    = string
  default = "gemini-4-argon"
}
variable "gemini_location" {
  type    = string
  default = "global"
}
variable "vertex_location" {
  type    = string
  default = ""
}

module "tenant" {
  source = "../../modules/tenant"

  tenant_name           = var.tenant_name
  customer_display_name = var.customer_display_name
  marketplace_order_id  = var.marketplace_order_id
  billing_account       = var.billing_account
  tenants_folder_id     = var.tenants_folder_id
  region                = var.region
  release_version       = var.release_version
  base_domain           = var.base_domain
  ops_group             = var.ops_group
  notification_channels = var.notification_channels
  log_retention_days    = var.log_retention_days
  api_min_instances     = var.api_min_instances

  gemini_model           = var.gemini_model
  gemini_reasoning_model = var.gemini_reasoning_model
  gemini_location        = var.gemini_location
  vertex_location        = var.vertex_location
}

output "tenant" {
  description = "Everything the release pipeline, validation and the tenant register need."
  value = {
    project_id                = module.tenant.project_id
    project_number            = module.tenant.project_number
    billing_account           = module.tenant.billing_account
    region                    = module.tenant.region
    release_version           = module.tenant.release_version
    api_hostname              = module.tenant.api_hostname
    lb_ip                     = module.tenant.lb_ip
    ssl_certificate           = module.tenant.ssl_certificate
    armor_policy              = module.tenant.armor_policy
    backend_service           = module.tenant.backend_service
    raw_logs_topic            = module.tenant.raw_logs_topic
    normalized_topic          = module.tenant.normalized_topic
    function_name             = module.tenant.function_name
    run_portal_api            = module.tenant.run_portal_api
    run_detection_engine      = module.tenant.run_detection_engine
    firestore_database        = module.tenant.firestore_database
    bq_events_dataset         = module.tenant.bq_events_dataset
    bq_detections_dataset     = module.tenant.bq_detections_dataset
    raw_logs_bucket           = module.tenant.raw_logs_bucket
    vertex_endpoint_id        = module.tenant.vertex_endpoint_id
    vertex_location           = module.tenant.vertex_location
    gemini_model              = module.tenant.gemini_model
    gemini_reasoning_model    = module.tenant.gemini_reasoning_model
    gemini_location           = module.tenant.gemini_location
    registry_location         = module.tenant.registry_location
    firebase_hosting_site     = module.tenant.firebase_hosting_site
    firebase_web_app_id       = module.tenant.firebase_web_app_id
    collector_service_account = module.tenant.collector_service_account
    kms_key_id                = module.tenant.kms_key_id
  }
}
