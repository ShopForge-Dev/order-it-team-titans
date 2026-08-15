###############################################################################
# Compartment
#
# Created in the tenancy home region: IAM resources are global and the OCI
# provider rejects them against a non-home region.
###############################################################################

resource "oci_identity_compartment" "this" {
  count = var.create_compartment ? 1 : 0

  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = var.compartment_name
  description    = "Managed by Terraform — ${var.compartment_name}"
  enable_delete  = true
  freeform_tags  = var.tags
}

locals {
  compartment_ocid = var.create_compartment ? oci_identity_compartment.this[0].id : var.existing_compartment_ocid
}

###############################################################################
# Instance principals
#
# Lets worker nodes call OCI APIs (pull from OCIR, write to Object Storage,
# attach block volumes for PVCs) with no static credentials on the node.
###############################################################################

resource "oci_identity_dynamic_group" "nodes" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.name_prefix}-nodes-dg"
  description    = "OKE worker nodes in the ${var.compartment_name} compartment"
  matching_rule  = "ALL {instance.compartment.id = '${local.compartment_ocid}'}"
  freeform_tags  = var.tags
}

resource "oci_identity_policy" "nodes" {
  provider = oci.home

  compartment_id = local.compartment_ocid
  name           = "${var.name_prefix}-nodes-policy"
  description    = "Least-privilege access for OKE worker nodes"
  freeform_tags  = var.tags

  statements = [
    # Pull container images.
    "Allow dynamic-group ${oci_identity_dynamic_group.nodes.name} to read repos in compartment id ${local.compartment_ocid}",
    # Persistent volumes for stateful workloads.
    "Allow dynamic-group ${oci_identity_dynamic_group.nodes.name} to manage volume-family in compartment id ${local.compartment_ocid}",
    # Application assets and database backups.
    "Allow dynamic-group ${oci_identity_dynamic_group.nodes.name} to manage object-family in compartment id ${local.compartment_ocid}",
  ]

  depends_on = [oci_identity_dynamic_group.nodes]
}

###############################################################################
# OKE service policy
#
# The Container Engine service itself needs permission to manage the VCN, the
# load balancers created by ingress-nginx, and the worker instances.
###############################################################################

resource "oci_identity_policy" "oke_service" {
  provider = oci.home

  compartment_id = local.compartment_ocid
  name           = "${var.name_prefix}-oke-service-policy"
  description    = "Allows the OKE service to manage cluster infrastructure"
  freeform_tags  = var.tags

  statements = [
    "Allow service OKE to manage all-resources in compartment id ${local.compartment_ocid}",
  ]
}
