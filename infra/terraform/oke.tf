# OKE Cluster (Oracle Container Engine for Kubernetes)
resource "oci_containerengine_cluster" "orderit_oke" {
  compartment_id     = var.compartment_id
  kubernetes_version = var.k8s_version
  name               = local.cluster_name
  vcn_id             = oci_core_vcn.orderit_vcn.id

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.public_subnet.id
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.public_subnet.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    admission_controller_options {
      is_pod_security_policy_enabled = false
    }
  }

  freeform_tags = local.tags
}

# Image lookup for node pool shape (Oracle Linux for Ampere ARM or x86)
data "oci_core_images" "node_pool_images" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.node_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# OKE Node Pool
resource "oci_containerengine_node_pool" "orderit_node_pool" {
  cluster_id         = oci_containerengine_cluster.orderit_oke.id
  compartment_id     = var.compartment_id
  kubernetes_version = var.k8s_version
  name               = "${local.name_prefix}-node-pool"
  node_shape         = var.node_shape

  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.private_subnet.id
    }

    # If multi-AD region, spread node pool across ADs
    dynamic "placement_configs" {
      for_each = length(data.oci_identity_availability_domains.ads.availability_domains) > 1 ? [data.oci_identity_availability_domains.ads.availability_domains[1].name] : []
      content {
        availability_domain = placement_configs.value
        subnet_id           = oci_core_subnet.private_subnet.id
      }
    }
  }

  # Flex shape configuration (e.g. VM.Standard.A1.Flex for Always Free)
  dynamic "node_shape_config" {
    for_each = length(regexall(".*Flex", var.node_shape)) > 0 ? [1] : []
    content {
      ocpus         = var.ocpus_per_node
      memory_in_gbs = var.memory_in_gbs_per_node
    }
  }

  node_source_details {
    image_id    = data.oci_core_images.node_pool_images.images[0].id
    source_type = "IMAGE"
  }

  node_metadata = var.ssh_public_key != "" ? {
    user_data           = base64encode("#!/bin/bash\n")
    ssh_authorized_keys = var.ssh_public_key
    } : {
    user_data = base64encode("#!/bin/bash\n")
  }

  freeform_tags = local.tags
}
