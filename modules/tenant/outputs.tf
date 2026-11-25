output "project_id" {
  description = "Tenant project ID (customer-<name>-prod)."
  value       = google_project.tenant.project_id
}

output "project_number" {
  description = "Tenant project number."
  value       = google_project.tenant.number
}

output "billing_account" {
  description = "Billing account the project is linked to."
  value       = google_project.tenant.billing_account
}

output "region" {
  description = "Region of the tenant's regional resources."
  value       = var.region
}

output "gke_cluster_name" {
  description = "GKE Autopilot cluster name."
  value       = google_container_cluster.autopilot.name
}

output "sql_instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.main.name
}

output "sql_connection_name" {
  description = "Cloud SQL connection name for the Auth Proxy / connectors."
  value       = google_sql_database_instance.main.connection_name
}

output "sql_private_ip" {
  description = "Private IP of the Cloud SQL instance."
  value       = google_sql_database_instance.main.private_ip_address
}

output "sql_iam_user" {
  description = "IAM database user for the workloads."
  value       = google_sql_user.workload.name
}

output "logs_bucket" {
  description = "Tenant raw-log bucket name."
  value       = google_storage_bucket.soc_logs.name
}

output "kms_key_id" {
  description = "CMEK key used by Cloud SQL and Cloud Storage."
  value       = google_kms_crypto_key.cmek.id
}

output "workload_service_account" {
  description = "Google service account used by the Security Operation Center First pods."
  value       = google_service_account.workload.email
}

output "k8s_namespace" {
  description = "Kubernetes namespace for the Security Operation Center First workloads."
  value       = var.k8s_namespace
}

output "k8s_service_account" {
  description = "Kubernetes service account bound through Workload Identity."
  value       = var.k8s_service_account
}
