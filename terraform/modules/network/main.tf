###############################################################################
# VCN
###############################################################################

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = replace(var.name_prefix, "-", "")
  freeform_tags  = var.tags
}

###############################################################################
# Gateways
#
# Internet gateway  : free.
# Service gateway   : free. Keeps image pulls from OCIR and Object Storage
#                     traffic on the Oracle backbone instead of the NAT.
# NAT gateway       : BILLED hourly + per GB. Only created when private
#                     workers actually need egress.
###############################################################################

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-igw"
  enabled        = true
  freeform_tags  = var.tags
}

data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-sgw"
  freeform_tags  = var.tags

  services {
    service_id = data.oci_core_services.all.services[0].id
  }
}

locals {
  # A NAT is only meaningful when workers sit in a private subnet.
  create_nat = var.enable_nat_gateway && !var.workers_in_public_subnet
}

resource "oci_core_nat_gateway" "this" {
  count = local.create_nat ? 1 : 0

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-natgw"
  freeform_tags  = var.tags
}

###############################################################################
# Route tables
###############################################################################

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-public"
  freeform_tags  = var.tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-private"
  freeform_tags  = var.tags

  dynamic "route_rules" {
    for_each = local.create_nat ? [1] : []
    content {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_nat_gateway.this[0].id
    }
  }

  route_rules {
    destination       = data.oci_core_services.all.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }
}

###############################################################################
# Security list — load balancer subnet
#
# ingress-nginx terminates TLS, so only 80/443 are exposed publicly. Egress is
# restricted to the NodePort range plus the kube-proxy health port.
###############################################################################

resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-sl-lb"
  freeform_tags  = var.tags

  dynamic "ingress_security_rules" {
    for_each = [80, 443]
    content {
      description = "Public HTTP(S) to the ingress load balancer"
      protocol    = "6" # TCP
      source      = "0.0.0.0/0"
      source_type = "CIDR_BLOCK"
      stateless   = false

      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  egress_security_rules {
    description      = "Load balancer to worker NodePort range"
    protocol         = "6"
    destination      = var.worker_subnet_cidr
    destination_type = "CIDR_BLOCK"
    stateless        = false

    tcp_options {
      min = 30000
      max = 32767
    }
  }

  egress_security_rules {
    description      = "Load balancer to kube-proxy health check port"
    protocol         = "6"
    destination      = var.worker_subnet_cidr
    destination_type = "CIDR_BLOCK"
    stateless        = false

    tcp_options {
      min = 10256
      max = 10256
    }
  }
}

###############################################################################
# Security list — worker subnet
###############################################################################

resource "oci_core_security_list" "workers" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-sl-workers"
  freeform_tags  = var.tags

  ingress_security_rules {
    description = "Pod-to-pod and node-to-node traffic"
    protocol    = "all"
    source      = var.worker_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "Control plane to kubelet"
    protocol    = "6"
    source      = var.api_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "Path MTU discovery from the control plane"
    protocol    = "1" # ICMP
    source      = var.api_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    description = "Load balancer to NodePort services"
    protocol    = "6"
    source      = var.lb_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 30000
      max = 32767
    }
  }

  ingress_security_rules {
    description = "Load balancer health checks"
    protocol    = "6"
    source      = var.lb_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 10256
      max = 10256
    }
  }

  # Egress is open: workers must reach MongoDB Atlas, Stripe, Cloudinary,
  # Mailtrap, Let's Encrypt and GHCR. Lock this down per-destination only once
  # the external dependency IP ranges are pinned.
  egress_security_rules {
    description      = "Worker egress to the internet"
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    stateless        = false
  }
}

###############################################################################
# Security list — Kubernetes API endpoint subnet
###############################################################################

resource "oci_core_security_list" "api" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-sl-api"
  freeform_tags  = var.tags

  dynamic "ingress_security_rules" {
    for_each = var.api_endpoint_is_public ? var.api_allowed_cidrs : []
    content {
      description = "kubectl and CI access to the Kubernetes API"
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false

      tcp_options {
        min = 6443
        max = 6443
      }
    }
  }

  ingress_security_rules {
    description = "Workers to the Kubernetes API"
    protocol    = "6"
    source      = var.worker_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    description = "Worker node registration (OKE control plane port)"
    protocol    = "6"
    source      = var.worker_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    description = "Path MTU discovery from workers"
    protocol    = "1"
    source      = var.worker_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  egress_security_rules {
    description      = "Control plane to OCI services"
    protocol         = "6"
    destination      = data.oci_core_services.all.services[0].cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    stateless        = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    description      = "Control plane to workers"
    protocol         = "6"
    destination      = var.worker_subnet_cidr
    destination_type = "CIDR_BLOCK"
    stateless        = false
  }

  egress_security_rules {
    description      = "Path MTU discovery to workers"
    protocol         = "1"
    destination      = var.worker_subnet_cidr
    destination_type = "CIDR_BLOCK"
    stateless        = false

    icmp_options {
      type = 3
      code = 4
    }
  }
}

###############################################################################
# Subnets — all regional, so a node pool can spread across every AD and pick up
# whatever Always-Free A1 capacity happens to exist.
###############################################################################

resource "oci_core_subnet" "lb" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.lb_subnet_cidr
  display_name               = "${var.name_prefix}-subnet-lb"
  dns_label                  = "lb"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.lb.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.tags
}

resource "oci_core_subnet" "workers" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.worker_subnet_cidr
  display_name               = "${var.name_prefix}-subnet-workers"
  dns_label                  = "workers"
  route_table_id             = var.workers_in_public_subnet ? oci_core_route_table.public.id : oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.workers.id]
  prohibit_public_ip_on_vnic = !var.workers_in_public_subnet
  freeform_tags              = var.tags
}

resource "oci_core_subnet" "api" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.api_subnet_cidr
  display_name               = "${var.name_prefix}-subnet-api"
  dns_label                  = "api"
  route_table_id             = var.api_endpoint_is_public ? oci_core_route_table.public.id : oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.api.id]
  prohibit_public_ip_on_vnic = !var.api_endpoint_is_public
  freeform_tags              = var.tags
}
