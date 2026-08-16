###############################################################################
# Staging VM module — Main resources
###############################################################################

# Get Ubuntu 22.04 image
data "oci_core_images" "ubuntu" {
  compartment_id = var.compartment_ocid
  operating_system = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape = var.shape
  sort_by = "TIMECREATED"
  sort_order = "DESC"
}

# Security list for staging VM (allow SSH, HTTP, HTTPS, K3s)
resource "oci_core_security_list" "staging" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.name_prefix}-staging-seclist"

  # Ingress rules
  ingress_security_rules = [
    # SSH
    {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        destination_port_range {
          max = 22
          min = 22
        }
      }
      stateless = false
    },
    # HTTP
    {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        destination_port_range {
          max = 80
          min = 80
        }
      }
      stateless = false
    },
    # HTTPS
    {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        destination_port_range {
          max = 443
          min = 443
        }
      }
      stateless = false
    },
    # K3s API (for kubectl from CI)
    {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        destination_port_range {
          max = 6443
          min = 6443
        }
      }
      stateless = false
    },
    # NodePort range (for K3s services)
    {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        destination_port_range {
          max = 32767
          min = 30000
        }
      }
      stateless = false
    }
  ]

  # Egress - allow all outbound
  egress_security_rules = [
    {
      protocol = "all"
      destination = "0.0.0.0/0"
      stateless = false
    }
  ]

  freeform_tags = var.tags
}

# Network security group for staging VM
resource "oci_core_network_security_group" "staging" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.name_prefix}-staging-nsg"
  freeform_tags  = var.tags
}

# NSG security rules (same as security list)
resource "oci_core_network_security_group_security_rule" "staging_ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.staging.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 22
      min = 22
    }
  }
  stateless = false
  description = "SSH"
}

resource "oci_core_network_security_group_security_rule" "staging_ingress_http" {
  network_security_group_id = oci_core_network_security_group.staging.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 80
      min = 80
    }
  }
  stateless = false
  description = "HTTP"
}

resource "oci_core_network_security_group_security_rule" "staging_ingress_https" {
  network_security_group_id = oci_core_network_security_group.staging.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 443
      min = 443
    }
  }
  stateless = false
  description = "HTTPS"
}

resource "oci_core_network_security_group_security_rule" "staging_ingress_k3s" {
  network_security_group_id = oci_core_network_security_group.staging.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 6443
      min = 6443
    }
  }
  stateless = false
  description = "K3s API"
}

resource "oci_core_network_security_group_security_rule" "staging_ingress_nodeport" {
  network_security_group_id = oci_core_network_security_group.staging.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 32767
      min = 30000
    }
  }
  stateless = false
  description = "K3s NodePort range"
}

resource "oci_core_network_security_group_security_rule" "staging_egress" {
  network_security_group_id = oci_core_network_security_group.staging.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
  description               = "Allow all outbound"
}

# Staging VM instance
resource "oci_core_instance" "staging" {
  compartment_id = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name = "${var.name_prefix}-staging"
  shape = var.shape
  shape_config {
    ocpus = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  create_vnic_details {
    subnet_id = var.subnet_id
    assign_public_ip = true
    nsg_ids = [oci_core_network_security_group.staging.id]
    hostname_label = "${var.name_prefix}-staging"
  }

  source_details {
    source_type = "image"
    source_id = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      name_prefix = var.name_prefix
    }))
  }

  freeform_tags = var.tags

  # Boot volume
  boot_volume_details = {
    size_in_gbs = var.boot_volume_gbs
  }
}

# Output public IP for CI/CD
output "public_ip" {
  description = "Public IP of the staging VM"
  value       = oci_core_instance.staging.public_ip
}

output "private_ip" {
  description = "Private IP of the staging VM"
  value       = oci_core_instance.staging.private_ip
}

output "instance_id" {
  description = "OCID of the staging VM"
  value       = oci_core_instance.staging.id
}