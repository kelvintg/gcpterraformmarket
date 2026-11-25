# SecurityOperationCenter-gcp-tenant-provisioning

Terraform that creates a dedicated (single-tenant) Google Cloud environment for each SecurityOperationCenterFirst customer.
Each tenant project runs its own copy of the partner-tenant stack from the SecurityOperationCenterFirst platform architecture.
The step-by-step procedure is SOP-PLT-004 *Single-Tenant Provisioning Runbook*.

| Item | Value |
| --- | --- |
| Project per tenant | `customer-<name>-prod` |
| Billing account | `010C56-DBE422-956EBA` |
| Folder | `SecurityOperationCenterFirst > Tenants > Production` |
| Default region | `asia-southeast1` (Singapore) |
| Ingestion | Cloud Pub/Sub (`raw-logs`, `normalized-events`, `dead-letter`), Cloud Storage raw-log archive, Cloud Logging, Cloud Monitoring |
| Backend | Cloud Functions 2nd gen `log-normalizer`, Cloud Run `detection-engine` |
| Storage | Firestore (Native), BigQuery `soc_events` and `soc_detections` |
| AI/ML | Vertex AI endpoint `soc-anomaly-detector`; OpenAI API key in Secret Manager (OpenAI itself is an Other Cloud Provider) |
| Frontend | Cloud Run `soc-portal-api`, Firebase Hosting + Authentication |
| Security | Cloud Armor, global external Application Load Balancer with Google-managed TLS, IAM (one service account per component), Cloud KMS (CMEK) |
| State | `gs://socfirst-tfstate/tenants/<name>` (project `socfirst-automation`) |
| Typical time to provision | ~3 hours end to end (Terraform apply ~40 min, release deploy ~40 min) |

Resource IDs keep the short prefix `socfirst` (for example `socfirst-automation`) because GCP project IDs are limited to
30 characters, which `securityoperationcenterfirst-automation` (39) would exceed.

## Layout

```
modules/tenant/          The tenant module (one call = one complete tenant)
  main.tf                Project, billing link, labels, APIs
  kms.tf                 Key ring + CMEK key, grants to the Cloud Storage and BigQuery service agents
  ingestion.tf           Pub/Sub topics and push subscription, raw-log bucket
  backend.tf             Cloud Functions log-normalizer, Cloud Run detection-engine
  data.tf                Firestore + daily backups, BigQuery datasets, Vertex AI endpoint, OpenAI key secret
  frontend.tf            Cloud Run soc-portal-api, Firebase project, web app and Hosting site
  security.tf            Cloud Armor policy, load balancer, managed certificate, DNS record
  iam.tf                 Service agents, per-component service accounts, least-privilege bindings, SRE group
  observability.tf       Log retention, uptime check, detection-backlog alert
  outputs.tf
tenants/_template/       Copied for every new tenant by scripts/new-tenant.sh
tenants/<name>/          One folder per provisioned tenant (own state prefix)
cloudbuild/              tenant-plan.yaml (PR), tenant-apply.yaml and tenant-release.yaml (manual, approval required)
scripts/                 new-tenant.sh, deploy-release.sh, validate-tenant.sh
```

## One-time setup

1. In `tenants/_template/terraform.tfvars`, replace every `REPLACE_WITH_*` value (folder ID, SRE group, base domain).
2. In project `socfirst-shared`: Artifact Registry repository `socfirst` (images `soc-portal-api`, `detection-engine`),
   bucket `socfirst-shared-releases` (function sources, portal bundles, model artifacts) and public Cloud DNS zone `socfirst-public` for the base domain.
3. In project `socfirst-automation`:
   - Create the state bucket `socfirst-tfstate` (versioning on, uniform access) and the records bucket `socfirst-provisioning-records`.
   - Enable the APIs `cloudresourcemanager`, `cloudbilling`, `serviceusage`, `iam`, `cloudbuild`, `firebase` and every API listed in `modules/tenant/main.tf`.
4. Create the service account `tf-tenant-provisioner@socfirst-automation.iam.gserviceaccount.com` and grant it:
   - On folder `Tenants > Production`: `roles/resourcemanager.projectCreator`, `roles/resourcemanager.projectIamAdmin`,
     `roles/serviceusage.serviceUsageAdmin`, `roles/firebase.admin`, `roles/run.admin`, `roles/cloudfunctions.admin`,
     `roles/eventarc.admin`, `roles/pubsub.admin`, `roles/datastore.owner`, `roles/bigquery.admin`, `roles/aiplatform.admin`,
     `roles/storage.admin`, `roles/cloudkms.admin`, `roles/secretmanager.admin`, `roles/compute.loadBalancerAdmin`,
     `roles/compute.securityAdmin`, `roles/monitoring.admin`, `roles/logging.admin`, `roles/iam.serviceAccountAdmin`,
     `roles/iam.serviceAccountUser`.
   - On billing account `010C56-DBE422-956EBA`: `roles/billing.user`.
   - In `socfirst-shared`: `roles/artifactregistry.admin` on repository `socfirst`, `roles/storage.admin` on bucket
     `socfirst-shared-releases`, `roles/dns.admin` on zone `socfirst-public` (to grant tenant access and add the API record).
   - On the state and records buckets: `roles/storage.objectAdmin`.
5. Create the Cloud Build triggers:

```bash
REPO=projects/socfirst-automation/locations/asia-southeast1/connections/github/repositories/SecurityOperationCenter-gcp-tenant-provisioning
SA=projects/socfirst-automation/serviceAccounts/tf-tenant-provisioner@socfirst-automation.iam.gserviceaccount.com

gcloud builds triggers create github --name=tenant-plan --project=socfirst-automation --repository=$REPO \
  --pull-request-pattern='^main$' --included-files='tenants/**,modules/**' \
  --build-config=cloudbuild/tenant-plan.yaml --service-account=$SA

gcloud builds triggers create manual --name=tenant-apply --project=socfirst-automation --repository=$REPO \
  --branch=main --build-config=cloudbuild/tenant-apply.yaml --require-approval --service-account=$SA

gcloud builds triggers create manual --name=tenant-release --project=socfirst-automation --repository=$REPO \
  --branch=main --build-config=cloudbuild/tenant-release.yaml --require-approval --service-account=$SA
```

## Provision a tenant (summary)

```bash
scripts/new-tenant.sh acme "Acme Corp" 8f2c1d7e-4b0a-4c55-9e61-2a7d3b9c0f14 asia-southeast1
git checkout -b tenant/acme && git add tenants/acme && git commit -m "Add tenant acme" && git push -u origin tenant/acme
# PR -> tenant-plan posts the plan -> review + merge
gcloud builds triggers run tenant-apply   --project=socfirst-automation --branch=main --substitutions=_TENANT=acme   # ~40 min
gcloud builds triggers run tenant-release --project=socfirst-automation --branch=main --substitutions=_TENANT=acme   # ~25 min
printf '%s' "$OPENAI_PROJECT_KEY" | gcloud secrets versions add openai-api-key --project=customer-acme-prod --data-file=-
scripts/validate-tenant.sh acme
```

Full procedure, timings, validation and rollback: SOP-PLT-004.
