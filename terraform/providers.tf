provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Home region alias. IAM resources (compartments, groups, dynamic groups,
# policies) are global and MUST be created against the tenancy home region,
# which is not necessarily var.region.
provider "oci" {
  alias            = "home"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = local.home_region
}

data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}

data "oci_identity_regions" "all" {}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  home_region = one([
    for r in data.oci_identity_regions.all.regions :
    r.name if r.key == data.oci_identity_tenancy.this.home_region_key
  ])

  # Always-Free A1 capacity is per-AD and frequently exhausted. Spreading the
  # pool across every AD in the region maximises the chance of a successful launch.
  availability_domains = [for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name]

  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.extra_tags
  )
}
