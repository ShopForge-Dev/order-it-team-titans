###############################################################################
# Authentication — sourced from ~/.oci/config. Set via TF_VAR_* env vars.
###############################################################################

variable "tenancy_ocid" {
  description = "OCID of the tenancy."
  type        = string
}

variable "user_ocid" {
  description = "OCID of the API user."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key."
  type        = string
}

variable "private_key_path" {
  description = "Filesystem path to the API signing private key (PEM)."
  type        = string
}

variable "region" {
  description = "OCI region to deploy into."
  type        = string
  default     = "ap-mumbai-1"
}

###############################################################################
# Naming
###############################################################################

variable "project" {
  description = "Project slug used as the prefix for every resource name."
  type        = string
  default     = "orderit"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be lowercase alphanumeric/hyphen, 2-21 chars, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be one of: staging, prod."
  }
}

variable "extra_tags" {
  description = "Additional freeform tags merged onto every resource."
  type        = map(string)
  default     = {}
}

###############################################################################
# Compartment
###############################################################################

variable "create_compartment" {
  description = <<-EOT
    Create a dedicated compartment for this stack. Requires tenancy-level
    manage-compartments permission. Set false to deploy into an existing
    compartment supplied via existing_compartment_ocid.
  EOT
  type        = bool
  default     = true
}

variable "existing_compartment_ocid" {
  description = "Compartment OCID to deploy into when create_compartment = false."
  type        = string
  default     = null
}

###############################################################################
# Network
###############################################################################

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "10.0.0.0/16"
}

variable "lb_subnet_cidr" {
  description = "Public subnet hosting the OCI Load Balancer created by ingress-nginx."
  type        = string
  default     = "10.0.1.0/24"
}

variable "worker_subnet_cidr" {
  description = "Private subnet hosting OKE worker nodes."
  type        = string
  default     = "10.0.10.0/24"
}

variable "api_subnet_cidr" {
  description = "Subnet hosting the OKE Kubernetes API endpoint."
  type        = string
  default     = "10.0.0.0/28"
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Provision a NAT gateway so private worker nodes reach the internet
    (Stripe, Cloudinary, MongoDB Atlas, image pulls from GHCR).
    OCI NAT gateways are NOT always-free and bill hourly plus per-GB.
    Set false only if workers run in the public subnet.
  EOT
  type        = bool
  default     = true
}

variable "workers_in_public_subnet" {
  description = <<-EOT
    Place worker nodes in the public subnet with public IPs instead of behind
    a NAT gateway. Cuts the NAT cost to zero at the price of a larger attack
    surface. Intended for the $0 learning footprint only — never for prod.
  EOT
  type        = bool
  default     = false
}

variable "api_endpoint_is_public" {
  description = "Expose the Kubernetes API endpoint publicly (required for kubectl/CI from outside the VCN)."
  type        = bool
  default     = true
}

variable "api_allowed_cidrs" {
  description = <<-EOT
    CIDRs permitted to reach the Kubernetes API on 6443. Defaults to the whole
    internet so a fresh clone works; narrow this to your egress IP for anything
    real.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

###############################################################################
# OKE
###############################################################################

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster. Null selects the newest version OKE offers."
  type        = string
  default     = null
}

variable "node_shape" {
  description = "Worker node shape. VM.Standard.A1.Flex (Ampere ARM) is the Always-Free shape."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_ocpus" {
  description = "OCPUs per worker node. Always-Free budget is 4 OCPUs total across all A1 instances."
  type        = number
  default     = 2
}

variable "node_memory_gbs" {
  description = "Memory per worker node in GB. Always-Free budget is 24 GB total across all A1 instances."
  type        = number
  default     = 12
}

variable "node_count" {
  description = <<-EOT
    Worker nodes in the pool. Set to 0 to park the cluster overnight and
    preserve trial credits (SOP-COST-004). Default 2 x (2 OCPU / 12 GB)
    exactly consumes the Always-Free A1 allowance.
  EOT
  type        = number
  default     = 2
}

variable "node_boot_volume_gbs" {
  description = "Worker boot volume size in GB. Always-Free block storage total is 200 GB."
  type        = number
  default     = 50
}

variable "cni_type" {
  description = <<-EOT
    OKE pod networking. FLANNEL_OVERLAY keeps pod IPs off the VCN and needs no
    extra subnet. OCI_VCN_IP_NATIVE gives pods routable VCN IPs but requires a
    dedicated pod subnet and burns VCN address space per pod.
  EOT
  type        = string
  default     = "FLANNEL_OVERLAY"

  validation {
    condition     = contains(["FLANNEL_OVERLAY", "OCI_VCN_IP_NATIVE"], var.cni_type)
    error_message = "cni_type must be FLANNEL_OVERLAY or OCI_VCN_IP_NATIVE."
  }
}

variable "cluster_type" {
  description = "OKE cluster tier. BASIC_CLUSTER has no control-plane fee; ENHANCED_CLUSTER bills hourly."
  type        = string
  default     = "BASIC_CLUSTER"

  validation {
    condition     = contains(["BASIC_CLUSTER", "ENHANCED_CLUSTER"], var.cluster_type)
    error_message = "cluster_type must be BASIC_CLUSTER or ENHANCED_CLUSTER."
  }
}

variable "ssh_public_key" {
  description = "SSH public key authorised on worker nodes / staging VM. Null disables SSH access entirely."
  type        = string
  default     = null
}

###############################################################################
# Staging VM (for staging environment)
###############################################################################

variable "staging_vm_shape" {
  description = "VM shape for staging. VM.Standard.A1.Flex (ARM) is the Always-Free shape."
  type        = string
  default     = "VM.Standard.A1.Flex"

  validation {
    condition     = contains(["VM.Standard.A1.Flex", "VM.Standard.E2.1.Micro"], var.staging_vm_shape)
    error_message = "staging_vm_shape must be VM.Standard.A1.Flex (ARM) or VM.Standard.E2.1.Micro (AMD) for Always Free."
  }
}

variable "staging_vm_ocpus" {
  description = "OCPUs for staging VM (Flex shape only). Always-Free budget is 4 OCPUs total."
  type        = number
  default     = 4
}

variable "staging_vm_memory_gbs" {
  description = "Memory for staging VM in GB (Flex shape only). Always-Free budget is 24 GB total."
  type        = number
  default     = 24
}

variable "staging_vm_boot_volume_gbs" {
  description = "Staging VM boot volume size in GB. Always-Free block storage total is 200 GB."
  type        = number
  default     = 100
}

variable "duckdns_token" {
  description = "DuckDNS token for automatic DNS updates for staging domain."
  type        = string
  default     = null
}

###############################################################################
# Storage
###############################################################################

variable "buckets" {
  description = "Object Storage buckets to create, keyed by logical name."
  type = map(object({
    access_type = optional(string, "NoPublicAccess")
    versioning  = optional(string, "Disabled")
    tier        = optional(string, "Standard")
  }))
  default = {
    assets  = { access_type = "NoPublicAccess" }
    backups = { versioning = "Enabled" }
  }
}

variable "container_repositories" {
  description = <<-EOT
    OCIR repositories to create. Empty by default: the delivery pipeline
    publishes to GitHub Container Registry per the design doc, so OCIR would
    be an unused second registry.
  EOT
  type        = list(string)
  default     = []
}
