###############################################################################
# Orderit — OCI infrastructure
#
# Provisions infrastructure for both staging and production environments:
# - Staging: Oracle Always Free VM with K3s (lightweight K8s)
# - Production: OKE cluster with Always Free ARM nodes
#
# Deliberately NOT provisioned here:
#   - Load balancer. ingress-nginx creates it via a Service of type
#     LoadBalancer; Terraform only supplies the subnet.
#   - TLS certificates. cert-manager issues them from Let's Encrypt.
#   - MongoDB. The app points at MongoDB Atlas M0, which is outside OCI.
###############################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = merge(
    {
      "Project"     = var.project
      "Environment" = var.environment
      "ManagedBy"   = "Terraform"
    },
    var.extra_tags
  )

  availability_domains = slice(data.oci_identity_availability_domains.ads.availability_domains, 0, 3)
}

# Get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

###############################################################################
# IAM Module (shared)
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

###############################################################################
# Network Module (shared VCN, different subnets per environment)
###############################################################################
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

###############################################################################
# CONDITIONAL: Staging VM (for staging environment) OR OKE (for production)
###############################################################################

# Staging VM module (only for staging environment)
module "staging_vm" {
  count = var.environment == "staging" ? 1 : 0

  source = "./modules/staging-vm"

  compartment_ocid     = module.iam.compartment_ocid
  name_prefix          = local.name_prefix
  tags                 = local.common_tags
  vcn_id               = module.network.vcn_id
  subnet_id            = module.network.lb_subnet_id  # Use public LB subnet for staging VM
  availability_domain  = local.availability_domains[0]
  ssh_public_key       = var.ssh_public_key

  shape           = var.staging_vm_shape
  ocpus           = var.staging_vm_ocpus
  memory_gbs      = var.staging_vm_memory_gbs
  boot_volume_gbs = var.staging_vm_boot_volume_gbs
}

# OKE module (only for production environment)
module "oke" {
  count = var.environment == "prod" ? 1 : 0

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

  node_shape           = var.node_shape
  node_ocpus           = var.node_ocpus
  node_memory_gbs      = var.node_memory_gbs
  node_count           = var.node_count
  node_boot_volume_gbs = var.node_boot_volume_gbs
  ssh_public_key       = var.ssh_public_key

  depends_on = [module.iam]
}

###############################################################################
# Storage Module (shared)
###############################################################################
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
check "always_free_a1_budget" {
  assert {
    condition = var.environment != "prod" || !can(regex("\\.A1\\.", var.node_shape)) || (
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
    condition     = var.environment != "prod" || !var.enable_nat_gateway || var.workers_in_public_subnet
    error_message = "A NAT gateway bills hourly plus per-GB and is not Always-Free. For a $0 dev footprint set workers_in_public_subnet = true and enable_nat_gateway = false."
  }
}

check "staging_vm_always_free" {
  assert {
    condition = var.environment != "staging" || (
      var.staging_vm_shape == "VM.Standard.A1.Flex" &&
      var.staging_vm_ocpus <= 4 &&
      var.staging_vm_memory_gbs <= 24
    )
    error_message = "Staging VM exceeds Always-Free ARM limits (4 OCPU / 24 GB). Use VM.Standard.A1.Flex with <= 4 OCPU and <= 24 GB."
  }
}