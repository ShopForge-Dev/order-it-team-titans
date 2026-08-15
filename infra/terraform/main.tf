terraform {
  required_version = ">= 1.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }
  }

  # Remote state backend configuration (uncomment for production state management in OCI Object Storage)
  # backend "s3" {
  #   bucket                      = "orderit-oci-tf-state"
  #   key                         = "prod/terraform.tfstate"
  #   region                      = "us-ashburn-1"
  #   endpoint                    = "https://<namespace>.compat.objectstorage.<region>.oraclecloud.com"
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   force_path_style            = true
  # }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Fetch home region data for IAM resources
data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
}

data "oci_identity_regions" "regions" {
  filter {
    name   = "key"
    values = [data.oci_identity_tenancy.tenancy.home_region_key]
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}
