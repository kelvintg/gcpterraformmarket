#!/usr/bin/env bash
# Deploy the SecurityOperationCenterFirst application release to one tenant:
#   1. Vertex AI: upload the anomaly model for this release and deploy it to the tenant endpoint
#   2. Firebase Hosting: stage the analyst portal bundle (deployed by the next Cloud Build step)
# Runs inside the "tenant-release" Cloud Build pipeline (google-cloud-cli image).
# Usage: scripts/deploy-release.sh <tenant-outputs.json> <portal-staging-dir>
set -euo pipefail

[[ $# -eq 2 ]] || { echo "Usage: $0 <tenant-outputs.json> <portal-staging-dir>" >&2; exit 1; }

OUTPUTS="$1"
STAGE="$2"
RELEASE_BUCKET="${RELEASE_BUCKET:-socfirst-shared-releases}"
MODEL_IMAGE="${MODEL_IMAGE:-asia-docker.pkg.dev/vertex-ai/prediction/sklearn-cpu.1-3:latest}"

get() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$OUTPUTS" "$1"; }

PROJECT_ID="$(get project_id)"
REGION="$(get region)"
RELEASE="$(get release_version)"
ENDPOINT="$(get vertex_endpoint_id)"
SITE="$(get firebase_hosting_site)"
API_HOST="$(get api_hostname)"
MODEL_NAME="soc-anomaly-detector-${RELEASE//./-}"

echo ">> [1/2] Vertex AI model ${MODEL_NAME} -> endpoint ${ENDPOINT} (${PROJECT_ID}, ${REGION})"
MODEL_ID="$(gcloud ai models list --project="$PROJECT_ID" --region="$REGION" \
  --filter="displayName=${MODEL_NAME}" --format='value(name.basename())' | head -n1)"
if [[ -z "$MODEL_ID" ]]; then
  gcloud ai models upload --project="$PROJECT_ID" --region="$REGION" \
    --display-name="$MODEL_NAME" \
    --artifact-uri="gs://${RELEASE_BUCKET}/models/anomaly-detector/${RELEASE}/" \
    --container-image-uri="$MODEL_IMAGE"
  MODEL_ID="$(gcloud ai models list --project="$PROJECT_ID" --region="$REGION" \
    --filter="displayName=${MODEL_NAME}" --format='value(name.basename())' | head -n1)"
fi

DEPLOYED="$(gcloud ai endpoints describe "$ENDPOINT" --project="$PROJECT_ID" --region="$REGION" \
  --format='value(deployedModels[].model)')"
if [[ "$DEPLOYED" != *"/models/${MODEL_ID}"* ]]; then
  # 100% of traffic to the new model; older deployed models are undeployed by the next release run.
  gcloud ai endpoints deploy-model "$ENDPOINT" --project="$PROJECT_ID" --region="$REGION" \
    --model="$MODEL_ID" --display-name="$MODEL_NAME" \
    --machine-type=n1-standard-4 --min-replica-count=1 --max-replica-count=3 \
    --traffic-split=0=100
else
  echo "   model already deployed, skipping"
fi

echo ">> [2/2] Staging portal ${RELEASE} for Firebase Hosting site ${SITE}"
rm -rf "$STAGE" && mkdir -p "$STAGE/public"
gcloud storage cp "gs://${RELEASE_BUCKET}/portal/portal-${RELEASE}.tar.gz" "$STAGE/portal.tar.gz"
tar -xzf "$STAGE/portal.tar.gz" -C "$STAGE/public"
rm "$STAGE/portal.tar.gz"

cat > "$STAGE/public/config.json" <<EOF
{ "tenant": "${PROJECT_ID#customer-}", "apiBaseUrl": "https://${API_HOST}", "release": "${RELEASE}" }
EOF

cat > "$STAGE/firebase.json" <<EOF
{
  "hosting": {
    "site": "${SITE}",
    "public": "public",
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [{
      "source": "**",
      "headers": [
        { "key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains" },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Content-Security-Policy", "value": "default-src 'self'; connect-src 'self' https://${API_HOST} https://*.googleapis.com; frame-ancestors 'none'" }
      ]
    }]
  }
}
EOF
printf '%s' "$PROJECT_ID" > "$STAGE/project_id"

# Remind the operator if the OpenAI key has not been added yet (phase 5 manual step).
if [[ -z "$(gcloud secrets versions list "$(get openai_secret)" --project="$PROJECT_ID" \
      --filter='state=ENABLED' --format='value(name)' --limit=1)" ]]; then
  echo "!! Secret $(get openai_secret) has no enabled version yet - add the tenant's OpenAI key (runbook phase 5)."
fi
echo ">> Release ${RELEASE} staged for ${PROJECT_ID}"
