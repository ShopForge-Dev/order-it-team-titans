variable "compartment_ocid" {
  description = "Compartment to create network resources in."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource display names."
  type        = string
}

variable "tags" {
  description = "Freeform tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "vcn_cidr" {
  type = string
}

variable "lb_subnet_cidr" {
  type = string
}

variable "worker_subnet_cidr" {
  type = string
}

variable "api_subnet_cidr" {
  type = string
}

variable "enable_nat_gateway" {
  type = bool
}

variable "workers_in_public_subnet" {
  type = bool
}

variable "api_endpoint_is_public" {
  type = bool
}

variable "api_allowed_cidrs" {
  type = list(string)
}
