# Virtual Cloud Network (VCN)
resource "oci_core_vcn" "orderit_vcn" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${local.name_prefix}-vcn"
  dns_label      = "orderitvcn"

  freeform_tags = local.tags
}

# Internet Gateway (for public load balancers & OKE API endpoint)
resource "oci_core_internet_gateway" "orderit_igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.orderit_vcn.id
  display_name   = "${local.name_prefix}-igw"
  enabled        = true

  freeform_tags = local.tags
}

# NAT Gateway (for private worker node outbound access)
resource "oci_core_nat_gateway" "orderit_nat" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.orderit_vcn.id
  display_name   = "${local.name_prefix}-nat"

  freeform_tags = local.tags
}

# Service Gateway (for private access to Oracle Services Network)
data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "orderit_sgw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.orderit_vcn.id
  display_name   = "${local.name_prefix}-sgw"

  services {
    service_id = data.oci_core_services.all_oci_services.services[0]["id"]
  }

  freeform_tags = local.tags
}

# Route Table for Public Subnet
resource "oci_core_route_table" "public_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.orderit_vcn.id
  display_name   = "${local.name_prefix}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.orderit_igw.id
  }

  freeform_tags = local.tags
}

# Route Table for Private Subnet
resource "oci_core_route_table" "private_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.orderit_vcn.id
  display_name   = "${local.name_prefix}-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.orderit_nat.id
  }

  route_rules {
    destination       = data.oci_core_services.all_oci_services.services[0]["cidr_block"]
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.orderit_sgw.id
  }

  freeform_tags = local.tags
}

# Public Subnet (Load Balancers & API Endpoint)
resource "oci_core_subnet" "public_subnet" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.orderit_vcn.id
  cidr_block        = local.public_subnet_cidr
  display_name      = "${local.name_prefix}-public-subnet"
  dns_label         = "publicsub"
  route_table_id    = oci_core_route_table.public_route_table.id
  security_list_ids = [oci_core_security_list.public_security_list.id]

  prohibit_public_ip_on_vnic = false

  freeform_tags = local.tags
}

# Private Subnet (OKE Worker Nodes)
resource "oci_core_subnet" "private_subnet" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.orderit_vcn.id
  cidr_block        = local.private_subnet_cidr
  display_name      = "${local.name_prefix}-private-subnet"
  dns_label         = "privatesub"
  route_table_id    = oci_core_route_table.private_route_table.id
  security_list_ids = [oci_core_security_list.private_security_list.id]

  prohibit_public_ip_on_vnic = true

  freeform_tags = local.tags
}
