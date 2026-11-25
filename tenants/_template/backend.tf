terraform {
  backend "gcs" {
    bucket = "socfirst-tfstate"
    prefix = "tenants/__TENANT__"
  }
}
