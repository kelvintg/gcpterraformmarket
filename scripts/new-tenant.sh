#!/usr/bin/env bash
# Create the Terraform configuration for a new SecurityOperationCenterFirst tenant.
# Usage: scripts/new-tenant.sh <tenant-name> "<Customer display name>" <marketplace-order-id> [region]
set -euo pipefail

usage() {
  echo "Usage: $0 <tenant-name> \"<Customer display name>\" <marketplace-order-id> [region]" >&2
  exit 1
}

[[ $# -ge 3 ]] || usage

TENANT="$1"
DISPLAY_NAME="$2"
ORDER_ID="$3"
REGION="${4:-asia-southeast1}"
PROJECT_ID="customer-${TENANT}-prod"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/tenants/_template"
DEST="$ROOT/tenants/$TENANT"

# customer- (9) + name + -prod (5) must stay within the 30-character project ID limit.
if [[ ! "$TENANT" =~ ^[a-z][a-z0-9-]{1,14}[a-z0-9]$ ]]; then
  echo "ERROR: tenant name '$TENANT' must be 3-16 chars: lowercase letters, digits, hyphens; start with a letter." >&2
  exit 1
fi

if [[ ! "$ORDER_ID" =~ ^[a-z0-9_-]{1,63}$ ]]; then
  echo "ERROR: marketplace order ID must be 1-63 lowercase letters, digits, hyphens or underscores." >&2
  exit 1
fi

if [[ ! "$DISPLAY_NAME" =~ ^[A-Za-z0-9\ .,\&\(\)\'-]{2,80}$ ]]; then
  echo "ERROR: display name contains unsupported characters." >&2
  exit 1
fi

if [[ -e "$DEST" ]]; then
  echo "ERROR: $DEST already exists. Is '$TENANT' already provisioned?" >&2
  exit 1
fi

if grep -q "REPLACE_WITH" "$TEMPLATE/terraform.tfvars"; then
  echo "ERROR: fill in the REPLACE_WITH_* values in tenants/_template/terraform.tfvars first." >&2
  exit 1
fi

# Project IDs are globally unique across all of Google Cloud.
if gcloud projects describe "$PROJECT_ID" --format="value(projectId)" >/dev/null 2>&1; then
  echo "ERROR: project $PROJECT_ID already exists in an organization you can see." >&2
  exit 1
fi

escape() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }

mkdir -p "$DEST"
for f in main.tf backend.tf terraform.tfvars; do
  sed -e "s/__TENANT__/$(escape "$TENANT")/g" \
      -e "s/__DISPLAY_NAME__/$(escape "$DISPLAY_NAME")/g" \
      -e "s/__ORDER_ID__/$(escape "$ORDER_ID")/g" \
      -e "s/__REGION__/$(escape "$REGION")/g" \
      "$TEMPLATE/$f" > "$DEST/$f"
done

BASE_DOMAIN="$(grep -E '^base_domain' "$DEST/terraform.tfvars" | cut -d'"' -f2)"

cat <<EOF
Created $DEST
  Project ID      : $PROJECT_ID
  Billing account : $(grep -E '^billing_account' "$DEST/terraform.tfvars" | cut -d'"' -f2)
  Region          : $REGION
  Release         : $(grep -E '^release_version' "$DEST/terraform.tfvars" | cut -d'"' -f2)
  Portal API      : https://api.${TENANT}.${BASE_DOMAIN}

Next:
  git checkout -b tenant/$TENANT
  git add tenants/$TENANT && git commit -m "Add tenant $TENANT ($ORDER_ID)"
  git push -u origin tenant/$TENANT   # opens the PR; Cloud Build posts the plan
EOF
