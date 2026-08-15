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

variable "buckets" {
  type = map(object({
    access_type = optional(string, "NoPublicAccess")
    versioning  = optional(string, "Disabled")
    tier        = optional(string, "Standard")
  }))
  default = {}
}

variable "container_repositories" {
  type    = list(string)
  default = []
}
