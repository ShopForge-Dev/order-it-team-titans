terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  # Remote state on OCI Object Storage (S3-compatible endpoint).
  # Bootstrap:
  # 1. Apply once with this block commented out
  # 2. Create bucket "orderit-tfstate" in OCI Object Storage
  # 3. Create Customer Secret Key in OCI Console (User Settings > Customer Secret Keys)
  # 4. Replace <NAMESPACE> with your OCI Object Storage namespace
  # 5. Uncomment this block and run `terraform init -migrate-state`
  backend "s3" {
    bucket                      = "orderit-tfstate"
    key                         = "orderit/${var.environment}/terraform.tfstate"
    region                      = "ap-mumbai-1"
    endpoints                   = { s3 = "https://<NAMESPACE>.compat.objectstorage.ap-mumbai-1.oraclecloud.com" }
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
