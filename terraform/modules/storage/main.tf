data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_ocid
}

###############################################################################
# Object Storage
#
# Always-Free allowance is 20 GB across all buckets in the tenancy.
###############################################################################

resource "oci_objectstorage_bucket" "this" {
  for_each = var.buckets

  compartment_id        = var.compartment_ocid
  namespace             = data.oci_objectstorage_namespace.this.namespace
  name                  = "${var.name_prefix}-${each.key}"
  access_type           = each.value.access_type
  storage_tier          = each.value.tier
  versioning            = each.value.versioning
  object_events_enabled = false
  freeform_tags         = var.tags
}

###############################################################################
# OCIR
#
# Empty by default: images are published to GitHub Container Registry, so
# creating OCIR repos would leave a second, unused registry behind.
###############################################################################

resource "oci_artifacts_container_repository" "this" {
  for_each = toset(var.container_repositories)

  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}/${each.value}"
  is_public      = false
  freeform_tags  = var.tags
}
