#!/usr/bin/env bash
# Post-provisioning checks for a SecurityOperationCenterFirst tenant. Exit code 0 only if every check passes.
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

P="$(get project_id)"; R="$(get region)"; K="$(get kms_key_id)"
FOLDER="$(grep -E '^tenants_folder_id' terraform.tfvars | cut -d'"' -f2)"

FAIL=0
check() { # check "<name>" "<expected>" "<actual>"
  if [[ "$3" == "$2" ]]; then printf 'PASS  %-32s %s\n' "$1" "$3"
  else printf 'FAIL  %-32s expected [%s] got [%s]\n' "$1" "$2" "$3"; FAIL=1; fi
}
check_set() { # check_set "<name>" "<actual>"  -> passes when actual is non-empty
  if [[ -n "$2" ]]; then printf 'PASS  %-32s %s\n' "$1" "$2"
  else printf 'FAIL  %-32s expected a value, got nothing\n' "$1"; FAIL=1; fi
}

echo "== Project and billing"
check "Project ID"            "customer-${TENANT}-prod" "$P"
check "Project state"         "ACTIVE" "$(gcloud projects describe "$P" --format='value(lifecycleState)')"
check "Project folder"        "$FOLDER" "$(gcloud projects describe "$P" --format='value(parent.id)')"
check "Billing account"       "$EXPECTED_BILLING" "$(gcloud billing projects describe "$P" --format='value(billingAccountName)')"
check "Billing enabled"       "True" "$(gcloud billing projects describe "$P" --format='value(billingEnabled)')"

echo "== Ingestion"
check_set "Pub/Sub raw-logs"          "$(gcloud pubsub topics describe raw-logs --project "$P" --format='value(name)' 2>/dev/null)"
check_set "Pub/Sub normalized-events" "$(gcloud pubsub topics describe normalized-events --project "$P" --format='value(name)' 2>/dev/null)"
B="$(get raw_logs_bucket)"
check "Bucket public access"  "enforced" "$(gcloud storage buckets describe "gs://$B" --format='value(public_access_prevention)')"
check "Bucket CMEK"           "$K" "$(gcloud storage buckets describe "gs://$B" --format='value(default_kms_key)')"

echo "== Backend"
check "Function log-normalizer"  "ACTIVE" "$(gcloud functions describe log-normalizer --gen2 --region "$R" --project "$P" --format='value(state)')"
check "Cloud Run detection-engine" "True" "$(gcloud run services describe detection-engine --region "$R" --project "$P" --format='value(status.conditions[0].status)')"
check "Cloud Run soc-portal-api"   "True" "$(gcloud run services describe soc-portal-api --region "$R" --project "$P" --format='value(status.conditions[0].status)')"

echo "== Storage"
check "Firestore (default)"   "FIRESTORE_NATIVE" "$(gcloud firestore databases describe --database='(default)' --project "$P" --format='value(type)')"
check "BigQuery soc_events CMEK"     "$K" "$(bq --project_id="$P" show --format=json soc_events 2>/dev/null | jq -r '.defaultEncryptionConfiguration.kmsKeyName')"
check "BigQuery soc_detections CMEK" "$K" "$(bq --project_id="$P" show --format=json soc_detections 2>/dev/null | jq -r '.defaultEncryptionConfiguration.kmsKeyName')"

echo "== AI/ML"
check_set "Vertex AI model deployed" "$(gcloud ai endpoints describe "$(get vertex_endpoint_id)" --region "$(get vertex_location)" --project "$P" --format='value(deployedModels[0].id)' 2>/dev/null)"

# Gemini smoke test: one tiny generateContent call, billed to the tenant project.
gemini_check() { # gemini_check <model>
  local loc host
  loc="$(get gemini_location)"
  case "$loc" in
    global) host="aiplatform.googleapis.com" ;;
    us|eu)  host="aiplatform.${loc}.rep.googleapis.com" ;;
    *)      host="${loc}-aiplatform.googleapis.com" ;;
  esac
  curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
    "https://${host}/v1/projects/${P}/locations/${loc}/publishers/google/models/$1:generateContent" \
    -d '{"contents":[{"role":"user","parts":[{"text":"Reply with OK"}]}],"generationConfig":{"maxOutputTokens":5}}'
}
check "Gemini $(get gemini_model)"           "200" "$(gemini_check "$(get gemini_model)")"
check "Gemini $(get gemini_reasoning_model)" "200" "$(gemini_check "$(get gemini_reasoning_model)")"

echo "== Frontend and security"
check "TLS certificate"       "ACTIVE" "$(gcloud compute ssl-certificates describe "$(get ssl_certificate)" --global --project "$P" --format='value(managed.status)')"
check "Cloud Armor attached"  "$(get armor_policy)" "$(gcloud compute backend-services describe "$(get backend_service)" --global --project "$P" --format='value(securityPolicy.basename())')"
check "API /healthz"          "200" "$(curl -s -o /dev/null -w '%{http_code}' "https://$(get api_hostname)/healthz")"
check "Portal (Firebase)"     "200" "$(curl -s -o /dev/null -w '%{http_code}' "https://$(get firebase_hosting_site).web.app/")"
check "Cloud Run API direct access blocked" "404" "$(curl -s -o /dev/null -w '%{http_code}' "$(gcloud run services describe soc-portal-api --region "$R" --project "$P" --format='value(status.url)')/healthz")"

echo
if [[ $FAIL -eq 0 ]]; then echo "RESULT: tenant $TENANT PASSED all checks"; else echo "RESULT: tenant $TENANT FAILED - see FAIL lines"; fi
exit $FAIL
