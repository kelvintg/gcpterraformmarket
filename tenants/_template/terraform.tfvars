# ---- Per-tenant values (filled in by scripts/new-tenant.sh) ----
tenant_name           = "__TENANT__"
customer_display_name = "__DISPLAY_NAME__"
marketplace_order_id  = "__ORDER_ID__"
region                = "__REGION__"

# ---- Values shared by every Security Operation Center First tenant (set once in tenants/_template) ----
billing_account   = "010C56-DBE422-956EBA"
tenants_folder_id = "REPLACE_WITH_TENANTS_PROD_FOLDER_ID" # numeric ID of Security Operation Center First > Tenants > Production
ops_group         = "group:REPLACE_WITH_SRE_GROUP_EMAIL"  # e.g. group:socfirst-sre@<your-domain>

gke_master_authorized_cidrs = [
  { cidr_block = "REPLACE_WITH_OPS_VPN_CIDR", display_name = "socfirst-ops-vpn" },
]

# ---- Sizing (defaults suit a customer sending up to ~50 GB of logs per day) ----
sql_tier              = "db-custom-2-7680"
sql_availability_type = "REGIONAL"
log_retention_days    = 365
