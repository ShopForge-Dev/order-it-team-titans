variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
  default     = "ocid1.tenancy.oc1..exampletenancyocid"
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
  default     = "ocid1.user.oc1..exampleuserocid"
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API private key"
  type        = string
  default     = "20:3b:97:13:55:1c:5b:0d:d3:37:d0:7e:76:ee:74:a3"
}

variable "private_key_path" {
  description = "Path to the OCI API private key file"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI region (e.g. us-ashburn-1, eu-frankfurt-1, ap-mumbai-1)"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_id" {
  description = "OCI Compartment OCID where resources will be created"
  type        = string
  default     = "ocid1.compartment.oc1..examplecompartmentocid"
}

variable "environment" {
  description = "Environment stage (e.g. dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vcn_cidr" {
  description = "CIDR block for the Virtual Cloud Network (VCN)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "k8s_version" {
  description = "Kubernetes version for OKE Cluster"
  type        = string
  default     = "v1.28.2"
}

variable "node_shape" {
  description = "Compute shape for OKE worker nodes (VM.Standard.A1.Flex is OCI Always Free ARM)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus_per_node" {
  description = "Number of OCPUs per worker node (for flex shapes)"
  type        = number
  default     = 2
}

variable "memory_in_gbs_per_node" {
  description = "Amount of RAM in GB per worker node (for flex shapes)"
  type        = number
  default     = 12
}

variable "node_count" {
  description = "Number of worker nodes in the node pool"
  type        = number
  default     = 2
}

variable "ssh_public_key" {
  description = "Public SSH key to access worker nodes"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for Orderit application"
  type        = string
  default     = "orderit.example.com"
}

variable "freeform_tags" {
  description = "Freeform tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "orderit"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
