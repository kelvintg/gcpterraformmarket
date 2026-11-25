# ---- Per-tenant values (filled in by scripts/new-tenant.sh) ----
tenant_name           = "__TENANT__"
customer_display_name = "__DISPLAY_NAME__"
marketplace_order_id  = "__ORDER_ID__"
region                = "__REGION__"

# ---- Values shared by every SecurityOperationCenterFirst tenant (set once in tenants/_template) ----
billing_account   = "010C56-DBE422-956EBA"
tenants_folder_id = "REPLACE_WITH_TENANTS_PROD_FOLDER_ID" # numeric ID of SecurityOperationCenterFirst > Tenants > Production
ops_group         = "group:REPLACE_WITH_SRE_GROUP_EMAIL"  # e.g. group:socfirst-sre@<your-domain>
base_domain       = "REPLACE_WITH_BASE_DOMAIN"            # zone socfirst-public; API = api.<tenant>.<base_domain>

# Current platform release; bump here when a new release ships.
release_version = "2026.11.2"

# Cloud Monitoring channel IDs for SRE on-call, e.g. "projects/socfirst-shared/notificationChannels/1234567890".
notification_channels = []

# ---- Sizing (defaults suit a customer sending up to ~50 GB of logs per day) ----
log_retention_days = 365
api_min_instances  = 1
