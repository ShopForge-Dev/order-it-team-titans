###############################################################################
# Orderit — OCI infrastructure
#
# Provisions the substrate the existing Kustomize manifests in app/k8s/ deploy
# onto: compartment + IAM, VCN, OKE cluster with an Always-Free ARM node pool,
# and Object Storage.
#
# Deliberately NOT provisioned here:
#   - Load balancer. ingress-nginx creates it via a Service of type
#     LoadBalancer; Terraform only supplies the subnet. See README for the
#     annotations that keep it on the 10 Mbps Always-Free flexible shape.
#   - TLS certificates. cert-manager issues them from Let's Encrypt.
#   - MongoDB. The app points at MongoDB Atlas M0, which is outside OCI.
###############################################################################

module "iam" {
  source = "./modules/iam"

  providers = {
    oci.home = oci.home
  }

  tenancy_ocid              = var.tenancy_ocid
  name_prefix               = local.name_prefix
  compartment_name          = local.name_prefix
  create_compartment        = var.create_compartment
  existing_compartment_ocid = var.existing_compartment_ocid
  tags                      = local.common_tags
}

module "network" {
  source = "./modules/network"

  compartment_ocid = module.iam.compartment_ocid
  name_prefix      = local.name_prefix
  tags             = local.common_tags

  vcn_cidr           = var.vcn_cidr
  lb_subnet_cidr     = var.lb_subnet_cidr
  worker_subnet_cidr = var.worker_subnet_cidr
  api_subnet_cidr    = var.api_subnet_cidr

  enable_nat_gateway       = var.enable_nat_gateway
  workers_in_public_subnet = var.workers_in_public_subnet
  api_endpoint_is_public   = var.api_endpoint_is_public
  api_allowed_cidrs        = var.api_allowed_cidrs
}

module "oke" {
  source = "./modules/oke"

  compartment_ocid = module.iam.compartment_ocid
  name_prefix      = local.name_prefix
  tags             = local.common_tags

  vcn_id               = module.network.vcn_id
  lb_subnet_id         = module.network.lb_subnet_id
  worker_subnet_id     = module.network.worker_subnet_id
  api_subnet_id        = module.network.api_subnet_id
  availability_domains = local.availability_domains

  kubernetes_version     = var.kubernetes_version
  cluster_type           = var.cluster_type
  cni_type               = var.cni_type
  api_endpoint_is_public = var.api_endpoint_is_public

  # Whether nodes get public IPs is decided by the worker subnet's
  # prohibit_public_ip_on_vnic, not by the node pool.
  node_shape           = var.node_shape
  node_ocpus           = var.node_ocpus
  node_memory_gbs      = var.node_memory_gbs
  node_count           = var.node_count
  node_boot_volume_gbs = var.node_boot_volume_gbs
  ssh_public_key       = var.ssh_public_key

  # The OKE service policy must exist before the service tries to create the
  # cluster's managed resources.
  depends_on = [module.iam]
}

module "storage" {
  source = "./modules/storage"

  compartment_ocid       = module.iam.compartment_ocid
  name_prefix            = local.name_prefix
  tags                   = local.common_tags
  buckets                = var.buckets
  container_repositories = var.container_repositories
}

###############################################################################
# Guardrails
###############################################################################
#important_do_not_edit
#unless upgraded the limits
check "always_free_a1_budget" {
  assert {
    condition = !can(regex("\\.A1\\.", var.node_shape)) || (
      var.node_ocpus * var.node_count <= 4 && var.node_memory_gbs * var.node_count <= 24
    )
    error_message = format(
      "Node pool requests %d OCPU / %d GB of A1 capacity. Always-Free caps the tenancy at 4 OCPU / 24 GB — the excess bills against trial credits.",
      var.node_ocpus * var.node_count,
      var.node_memory_gbs * var.node_count,
    )
  }
}

check "nat_gateway_cost" {
  assert {
    condition     = !var.enable_nat_gateway || var.workers_in_public_subnet || var.environment == "prod"
    error_message = "A NAT gateway bills hourly plus per-GB and is not Always-Free. For a $0 dev footprint set workers_in_public_subnet = true and enable_nat_gateway = false."
  }
}
