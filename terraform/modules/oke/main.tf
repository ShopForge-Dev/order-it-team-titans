###############################################################################
# Version + image selection
###############################################################################

data "oci_containerengine_cluster_option" "this" {
  cluster_option_id = "all"
  compartment_id    = var.compartment_ocid
}

data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
}

locals {
  # OKE returns versions oldest-first; take the newest unless pinned.
  k8s_version = coalesce(
    var.kubernetes_version,
    element(
      data.oci_containerengine_cluster_option.this.kubernetes_versions,
      length(data.oci_containerengine_cluster_option.this.kubernetes_versions) - 1,
    )
  )

  # Worker images are published per architecture; Ampere shapes need aarch64.
  node_arch = can(regex("\\.A[0-9]+\\.", var.node_shape)) ? "aarch64" : "x86_64"

  # Image names embed the Kubernetes version, e.g.
  # "Oracle-Linux-8.9-aarch64-2024.01.26-0-OKE-1.28.2-679".
  image_version_token = "OKE-${replace(local.k8s_version, "/^v/", "")}"

  matching_images = sort([
    for src in data.oci_containerengine_node_pool_option.this.sources :
    src.image_id
    if can(regex("Oracle-Linux", src.source_name))
    && can(regex(local.node_arch, src.source_name))
    && can(regex(local.image_version_token, src.source_name))
  ])

  node_image_id = length(local.matching_images) > 0 ? element(local.matching_images, length(local.matching_images) - 1) : null
}

###############################################################################
# Cluster
###############################################################################

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_ocid
  name               = "${var.name_prefix}-oke"
  kubernetes_version = local.k8s_version
  vcn_id             = var.vcn_id
  type               = var.cluster_type
  freeform_tags      = var.tags

  endpoint_config {
    subnet_id            = var.api_subnet_id
    is_public_ip_enabled = var.api_endpoint_is_public
  }

  cluster_pod_network_options {
    cni_type = var.cni_type
  }

  options {
    service_lb_subnet_ids = [var.lb_subnet_id]

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    admission_controller_options {
      is_pod_security_policy_enabled = false
    }
  }
}

###############################################################################
# Node pool
#
# node_count = 0 parks the cluster (SOP-COST-004 nightly scale-down) without
# destroying the pool, so a scale-up costs one API call instead of a re-apply.
###############################################################################

resource "oci_containerengine_node_pool" "this" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_ocid
  name               = "${var.name_prefix}-pool"
  kubernetes_version = local.k8s_version
  node_shape         = var.node_shape
  freeform_tags      = var.tags

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.node_image_id
    boot_volume_size_in_gbs = var.node_boot_volume_gbs
  }

  node_config_details {
    size = var.node_count

    # Spread across every AD: Always-Free A1 capacity is allocated per-AD and
    # is routinely exhausted in any single one.
    dynamic "placement_configs" {
      for_each = var.availability_domains
      content {
        availability_domain = placement_configs.value
        subnet_id           = var.worker_subnet_id
      }
    }

    node_pool_pod_network_option_details {
      cni_type = var.cni_type
    }

    is_pv_encryption_in_transit_enabled = true
    freeform_tags                       = var.tags
  }

  ssh_public_key = var.ssh_public_key

  lifecycle {
    # node_count is managed out-of-band by the nightly scale-to-zero job, so a
    # later `terraform apply` must not fight it back to the committed value.
    ignore_changes = [node_config_details[0].size]

    # Fail in plan with an actionable message instead of at apply with a
    # provider-level "image not found".
    precondition {
      condition     = local.node_image_id != null
      error_message = "No OKE worker image found for Kubernetes ${local.k8s_version} on ${local.node_arch}. Pin kubernetes_version to a version OKE publishes images for."
    }
  }
}

###############################################################################
# Kubeconfig
###############################################################################

data "oci_containerengine_cluster_kube_config" "this" {
  cluster_id = oci_containerengine_cluster.this.id
}
