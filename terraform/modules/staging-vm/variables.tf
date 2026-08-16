###############################################################################
# Staging VM module — Oracle Always Free VM with K3s
#
# Provisions a single VM for staging environment running K3s (lightweight K8s).
# Uses Oracle Always Free tier: 2 AMD / 4 ARM cores, 12-24 GB RAM, 50-100 GB storage.
###############################################################################

variable "compartment_ocid" {
  description = "Compartment OCID to create resources in."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
}

variable "tags" {
  description = "Freeform tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "vcn_id" {
  description = "VCN ID to deploy the VM into."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for the VM."
  type        = string
}

variable "availability_domain" {
  description = "Availability domain for the VM."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access."
  type        = string
}

variable "shape" {
  description = "VM shape. VM.Standard.E2.1.Micro (AMD) or VM.Standard.A1.Flex (ARM) for Always Free."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "OCPUs for Flex shape."
  type        = number
  default     = 4
}

variable "memory_gbs" {
  description = "Memory in GB for Flex shape."
  type        = number
  default     = 24
}

variable "boot_volume_gbs" {
  description = "Boot volume size in GB."
  type        = number
  default     = 100
}

variable "image_ocid" {
  description = "OCID of the OS image (Ubuntu 22.04)."
  type        = string
  default     = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaacj2qaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}