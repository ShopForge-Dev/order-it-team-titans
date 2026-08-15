# Container Repository for Orderit Backend Images
resource "oci_artifacts_container_repository" "ocir_backend" {
  compartment_id = var.compartment_id
  display_name   = "orderit-backend"
  is_public      = false
  is_immutable   = false

  freeform_tags = merge(
    local.tags,
    {
      "Name" = "orderit-backend"
    }
  )
}

# Container Repository for Orderit Frontend Images
resource "oci_artifacts_container_repository" "ocir_frontend" {
  compartment_id = var.compartment_id
  display_name   = "orderit-frontend"
  is_public      = false
  is_immutable   = false

  freeform_tags = merge(
    local.tags,
    {
      "Name" = "orderit-frontend"
    }
  )
}
