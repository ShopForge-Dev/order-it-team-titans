###############################################################################
# staging — $0 footprint on Oracle Always Free VM with K3s
#
# Single VM running K3s (lightweight Kubernetes) for staging environment.
# Uses Oracle Always Free: 4 ARM cores, 24 GB RAM, 100 GB storage.
###############################################################################

environment = "staging"
region      = "ap-mumbai-1

# Networking (reuse prod VCN or create separate)
vcn_cidr                 = "10.2.0.0/16"
lb_subnet_cidr           = "10.2.1.0/24"
worker_subnet_cidr       = "10.2.10.0/24"
api_subnet_cidr          = "10.2.0.0/28"
workers_in_public_subnet = true
enable_nat_gateway       = false
api_endpoint_is_public   = true

# Narrow this to your egress IP: `curl -s ifconfig.me`
api_allowed_cidrs = ["0.0.0.0/0"]

# Staging VM Compute — VM.Standard.A1.Flex (ARM Always Free)
# Max: 4 OCPU, 24 GB RAM
staging_vm_shape           = "VM.Standard.A1.Flex"
staging_vm_ocpus           = 4
staging_vm_memory_gbs      = 24
staging_vm_boot_volume_gbs = 100

# SSH public key for VM access (will be added to authorized_keys)
ssh_public_key = "ssh-rsa AAAA... your-public-key-here"

# DuckDNS token for staging domain
duckdns_token = "your-duckdns-token-here"

# Storage buckets
buckets = {
  assets = { access_type = "NoPublicAccess" }
}