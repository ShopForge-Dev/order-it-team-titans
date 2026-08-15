variable "compartment_ocid" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vcn_id" {
  type = string
}

variable "lb_subnet_id" {
  type = string
}

variable "worker_subnet_id" {
  type = string
}

variable "api_subnet_id" {
  type = string
}

variable "availability_domains" {
  description = "AD names to spread worker nodes across."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version, or null for the newest OKE offers."
  type        = string
  default     = null
}

variable "cluster_type" {
  type = string
}

variable "cni_type" {
  type = string
}

variable "api_endpoint_is_public" {
  type = bool
}

variable "node_shape" {
  type = string
}

variable "node_ocpus" {
  type = number
}

variable "node_memory_gbs" {
  type = number
}

variable "node_count" {
  type = number
}

variable "node_boot_volume_gbs" {
  type = number
}

variable "ssh_public_key" {
  type    = string
  default = null
}
