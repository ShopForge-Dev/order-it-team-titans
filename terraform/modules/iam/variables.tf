terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source                = "oracle/oci"
      version               = "~> 6.0"
      configuration_aliases = [oci.home]
    }
  }
}

variable "tenancy_ocid" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "compartment_name" {
  description = "Name of the compartment to create."
  type        = string
}

variable "create_compartment" {
  type = bool
}

variable "existing_compartment_ocid" {
  description = "Compartment to use when create_compartment = false."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
