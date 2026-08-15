# Security List for Public Subnet (Load Balancer & API Endpoint)
resource "oci_core_security_list" "public_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.orderit_vcn.id
  display_name   = "${local.name_prefix}-public-sl"

  # Ingress HTTP
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress HTTPS
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress Kubernetes API Endpoint
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Egress to all destinations
  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }

  freeform_tags = local.tags
}

# Security List for Private Subnet (Worker Nodes)
resource "oci_core_security_list" "private_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.orderit_vcn.id
  display_name   = "${local.name_prefix}-private-sl"

  # Internal worker node communication within VCN
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
  }

  # Egress to all destinations
  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }

  freeform_tags = local.tags
}
