# Dynamic Group for OKE Clusters in Compartment
resource "oci_identity_dynamic_group" "oke_dynamic_group" {
  compartment_id = var.tenancy_ocid
  name           = "${local.name_prefix}-oke-dg"
  description    = "Dynamic group for Orderit OKE instances"
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_id}'}"

  freeform_tags = local.tags
}

# IAM Policy for OKE Node Pool permissions (OCIR image pulling, volume attachment, network access)
resource "oci_identity_policy" "oke_policy" {
  compartment_id = var.compartment_id
  name           = "${local.name_prefix}-oke-policy"
  description    = "Policy enabling OKE nodes to manage networking, volumes, and pull images from OCIR"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_dynamic_group.name} to read repos in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_dynamic_group.name} to manage volume-family in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_dynamic_group.name} to use virtual-network-family in compartment id ${var.compartment_id}"
  ]

  freeform_tags = local.tags
}
