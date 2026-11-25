#!/usr/bin/env bash
# Deploy the Security Operation Center First tenant workloads into the tenant's GKE Autopilot cluster.
# Run from the Security Operation Center First ops bastion (its egress CIDR is in gke_master_authorized_cidrs).
# Usage: scripts/deploy-workloads.sh <tenant-name> <chart-version>
set -euo pipefail

[[ $# -eq 2 ]] || { echo "Usage: $0 <tenant-name> <chart-version>" >&2; exit 1; }

TENANT="$1"
CHART_VERSION="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY_HOST="asia-southeast1-docker.pkg.dev"
CHART="oci://${REGISTRY_HOST}/socfirst-shared/socfirst/socfirst-tenant"

cd "$ROOT/tenants/$TENANT"
terraform init -input=false >/dev/null
OUT="$(terraform output -json tenant)"
get() { printf '%s' "$OUT" | jq -r ".$1"; }

PROJECT_ID="$(get project_id)"
REGION="$(get region)"
CLUSTER="$(get gke_cluster_name)"
NAMESPACE="$(get k8s_namespace)"
KSA="$(get k8s_service_account)"
GSA="$(get workload_service_account)"

echo ">> Connecting to $CLUSTER in $PROJECT_ID ($REGION)"
gcloud container clusters get-credentials "$CLUSTER" --region "$REGION" --project "$PROJECT_ID"

echo ">> Namespace and Workload Identity service account"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" create serviceaccount "$KSA" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" annotate serviceaccount "$KSA" \
  "iam.gke.io/gcp-service-account=$GSA" --overwrite

echo ">> Helm install socfirst-tenant $CHART_VERSION (runs the DB migration job as a pre-install hook)"
gcloud auth print-access-token | helm registry login -u oauth2accesstoken --password-stdin "https://${REGISTRY_HOST}"
helm upgrade --install socfirst "$CHART" \
  --version "$CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --set tenant.name="$TENANT" \
  --set tenant.projectId="$PROJECT_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$KSA" \
  --set cloudsql.connectionName="$(get sql_connection_name)" \
  --set cloudsql.iamUser="$(get sql_iam_user)" \
  --set cloudsql.database=socfirst \
  --set storage.bucket="$(get logs_bucket)" \
  --wait --timeout 20m

kubectl -n "$NAMESPACE" get deployments,pods
echo ">> Done. Next: register the tenant in the control plane, then run scripts/validate-tenant.sh $TENANT"
