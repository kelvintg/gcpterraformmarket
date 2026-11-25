# SecurityOperationCenter-gcp-tenant-provisioning

Terraform that creates a dedicated (single-tenant) Google Cloud environment for each Security Operation Center First customer.
The step-by-step procedure is SOP-PLT-004 *Single-Tenant Provisioning Runbook*.

| Item | Value |
| --- | --- |
| Project per tenant | `customer-<name>-prod` |
| Billing account | `010C56-DBE422-956EBA` |
| Folder | `Security Operation Center First > Tenants > Production` |
| Default region | `asia-southeast1` |
| Core services | 1 GKE Autopilot cluster, 1 Cloud SQL (PostgreSQL 16) instance, 1 Cloud Storage bucket |
| Supporting services | VPC + subnet, Cloud Router + Cloud NAT, Private Service Access, Cloud KMS (CMEK), Secret Manager, IAM service accounts, Cloud Logging / Monitoring |
| State | `gs://socfirst-tfstate/tenants/<name>` (project `socfirst-automation`) |
| Typical time to provision | ~3 hours end to end (Terraform apply alone ~40-50 min) |

## Layout

```
modules/tenant/          The tenant module (one call = one complete tenant)
  main.tf                Project, billing link, labels, APIs
  network.tf             VPC, subnet + secondary ranges, Cloud Router, Cloud NAT, Private Service Access
  kms.tf                 Key ring + CMEK key, service-agent grants
  gke.tf                 GKE Autopilot cluster (private nodes) + node service account
  cloudsql.tf            Cloud SQL for PostgreSQL 16 (HA, private IP, CMEK, PITR), DB, users, admin secret
  storage.tf             Raw-log bucket (CMEK, PAP enforced, lifecycle tiering)
  iam.tf                 Workload service account, Workload Identity binding, SRE group roles
  outputs.tf
tenants/_template/       Copied for every new tenant by scripts/new-tenant.sh
tenants/<name>/          One folder per provisioned tenant (own state prefix)
cloudbuild/              tenant-plan.yaml (PR) and tenant-apply.yaml (manual, approval required)
scripts/                 new-tenant.sh, deploy-workloads.sh, validate-tenant.sh
```

## One-time setup

1. In `tenants/_template/terraform.tfvars`, replace every `REPLACE_WITH_*` value (folder ID, SRE group, ops VPN CIDR).
2. In project `socfirst-automation`:
   - Create the state bucket `socfirst-tfstate` (versioning on, uniform access) and the records bucket `socfirst-provisioning-records`.
   - Enable the APIs `cloudresourcemanager`, `cloudbilling`, `serviceusage`, `iam`, `cloudbuild`, `compute`, `container`, `sqladmin`, `servicenetworking`, `cloudkms`, `secretmanager`.
3. Create the service account `tf-tenant-provisioner@socfirst-automation.iam.gserviceaccount.com` and grant it:
   - On folder `Tenants > Production`: `roles/resourcemanager.projectCreator`, `roles/resourcemanager.projectIamAdmin`, `roles/serviceusage.serviceUsageAdmin`, `roles/compute.networkAdmin`, `roles/container.admin`, `roles/cloudsql.admin`, `roles/storage.admin`, `roles/cloudkms.admin`, `roles/secretmanager.admin`, `roles/iam.serviceAccountAdmin`, `roles/iam.serviceAccountUser`.
   - On billing account `010C56-DBE422-956EBA`: `roles/billing.user`.
   - On Artifact Registry repository `socfirst-shared/socfirst`: `roles/artifactregistry.admin` (needed to grant pull access to each tenant's node SA).
   - On the state bucket: `roles/storage.objectAdmin`.
4. Create the two Cloud Build triggers:

```bash
gcloud builds triggers create github --name=tenant-plan --project=socfirst-automation \
  --repository=projects/socfirst-automation/locations/asia-southeast1/connections/github/repositories/SecurityOperationCenter-gcp-tenant-provisioning \
  --pull-request-pattern='^main$' --included-files='tenants/**,modules/**' \
  --build-config=cloudbuild/tenant-plan.yaml \
  --service-account=projects/socfirst-automation/serviceAccounts/tf-tenant-provisioner@socfirst-automation.iam.gserviceaccount.com

gcloud builds triggers create manual --name=tenant-apply --project=socfirst-automation \
  --repository=projects/socfirst-automation/locations/asia-southeast1/connections/github/repositories/SecurityOperationCenter-gcp-tenant-provisioning \
  --branch=main --build-config=cloudbuild/tenant-apply.yaml --require-approval \
  --service-account=projects/socfirst-automation/serviceAccounts/tf-tenant-provisioner@socfirst-automation.iam.gserviceaccount.com
```

## Provision a tenant (summary)

```bash
scripts/new-tenant.sh acme "Acme Corp" 8f2c1d7e-4b0a-4c55-9e61-2a7d3b9c0f14 asia-southeast1
git checkout -b tenant/acme && git add tenants/acme && git commit -m "Add tenant acme" && git push -u origin tenant/acme
# PR -> tenant-plan posts the plan -> review + merge
gcloud builds triggers run tenant-apply --project=socfirst-automation --branch=main --substitutions=_TENANT=acme
# approve the build in Cloud Build -> apply (~40-50 min)
scripts/deploy-workloads.sh acme <chart-version>
scripts/validate-tenant.sh acme
```

Full procedure, timings, validation and rollback: SOP-PLT-004.
