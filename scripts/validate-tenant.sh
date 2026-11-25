#!/usr/bin/env bash
# Post-provisioning checks for a Security Operation Center First tenant. Exit code 0 only if every check passes.
# Usage: scripts/validate-tenant.sh <tenant-name>
set -uo pipefail

[[ $# -eq 1 ]] || { echo "Usage: $0 <tenant-name>" >&2; exit 1; }

TENANT="$1"
EXPECTED_BILLING="billingAccounts/010C56-DBE422-956EBA"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/tenants/$TENANT" || exit 1
terraform init -input=false >/dev/null
OUT="$(terraform output -json tenant)"
get() { printf '%s' "$OUT" | jq -r ".$1"; }

P="$(get project_id)"; R="$(get region)"; C="$(get gke_cluster_name)"
I="$(get sql_instance_name)"; B="$(get logs_bucket)"; K="$(get kms_key_id)"; NS="$(get k8s_namespace)"

FAIL=0
check() { # check "<name>" "<expected>" "<actual>"
  if [[ "$3" == "$2" ]]; then printf 'PASS  %-34s %s\n' "$1" "$3"
  else printf 'FAIL  %-34s expected [%s] got [%s]\n' "$1" "$2" "$3"; FAIL=1; fi
}

check "Project ID"                 "customer-${TENANT}-prod" "$P"
check "Project state"              "ACTIVE" "$(gcloud projects describe "$P" --format='value(lifecycleState)')"
FOLDER="$(grep -E '^tenants_folder_id' terraform.tfvars | cut -d'"' -f2)"
check "Project folder"             "$FOLDER" "$(gcloud projects describe "$P" --format='value(parent.id)')"
check "Billing account"            "$EXPECTED_BILLING" "$(gcloud billing projects describe "$P" --format='value(billingAccountName)')"
check "Billing enabled"            "True" "$(gcloud billing projects describe "$P" --format='value(billingEnabled)')"
check "GKE status"                 "RUNNING" "$(gcloud container clusters describe "$C" --region "$R" --project "$P" --format='value(status)')"
check "GKE Autopilot"              "True" "$(gcloud container clusters describe "$C" --region "$R" --project "$P" --format='value(autopilot.enabled)')"
check "GKE private nodes"          "True" "$(gcloud container clusters describe "$C" --region "$R" --project "$P" --format='value(privateClusterConfig.enablePrivateNodes)')"
check "Cloud SQL state"            "RUNNABLE" "$(gcloud sql instances describe "$I" --project "$P" --format='value(state)')"
check "Cloud SQL HA"               "REGIONAL" "$(gcloud sql instances describe "$I" --project "$P" --format='value(settings.availabilityType)')"
check "Cloud SQL public IP"        "False" "$(gcloud sql instances describe "$I" --project "$P" --format='value(settings.ipConfiguration.ipv4Enabled)')"
check "Cloud SQL CMEK"             "$K" "$(gcloud sql instances describe "$I" --project "$P" --format='value(diskEncryptionConfiguration.kmsKeyName)')"
check "Bucket public access"       "enforced" "$(gcloud storage buckets describe "gs://$B" --format='value(public_access_prevention)')"
check "Bucket uniform access"      "True" "$(gcloud storage buckets describe "gs://$B" --format='value(uniform_bucket_level_access)')"
check "Bucket CMEK"                "$K" "$(gcloud storage buckets describe "gs://$B" --format='value(default_kms_key)')"

gcloud container clusters get-credentials "$C" --region "$R" --project "$P" >/dev/null 2>&1
NOT_READY="$(kubectl -n "$NS" get deployments -o jsonpath='{range .items[?(@.status.availableReplicas!=@.spec.replicas)]}{.metadata.name}{" "}{end}' 2>/dev/null)"
check "Workloads available"        "" "$NOT_READY"

echo
if [[ $FAIL -eq 0 ]]; then echo "RESULT: tenant $TENANT PASSED all checks"; else echo "RESULT: tenant $TENANT FAILED - see FAIL lines"; fi
exit $FAIL
