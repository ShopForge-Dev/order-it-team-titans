terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  # Remote state on OCI Object Storage (S3-compatible endpoint).
  # Bootstrap order: apply once with this block commented out, then create the
  # bucket + a Customer Secret Key in the console, uncomment, and `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket                      = "orderit-tfstate"
  #   key                         = "orderit/prod/terraform.tfstate"
  #   region                      = "ap-mumbai-1"
  #   endpoints                   = { s3 = "https://<namespace>.compat.objectstorage.ap-mumbai-1.oraclecloud.com" }
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_requesting_account_id  = true
  #   skip_s3_checksum            = true
  #   use_path_style              = true
  # }
}
