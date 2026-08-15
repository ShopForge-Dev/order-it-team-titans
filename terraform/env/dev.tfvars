###############################################################################
# dev — $0 footprint, entirely inside Always-Free.
#
# Workers sit in the public subnet so no NAT gateway is billed. Acceptable for
# a learning cluster; never for prod.
###############################################################################

environment = "dev"
region      = "ap-mumbai-1"

# Networking
vcn_cidr                 = "10.0.0.0/16"
lb_subnet_cidr           = "10.0.1.0/24"
worker_subnet_cidr       = "10.0.10.0/24"
api_subnet_cidr          = "10.0.0.0/28"
workers_in_public_subnet = true
enable_nat_gateway       = false
api_endpoint_is_public   = true

# Narrow this to your egress IP: `curl -s ifconfig.me`
api_allowed_cidrs = ["0.0.0.0/0"]

# Compute — 1 node x 2 OCPU / 12 GB, half the Always-Free A1 allowance.
cluster_type         = "BASIC_CLUSTER"
node_shape           = "VM.Standard.A1.Flex"
node_ocpus           = 2
node_memory_gbs      = 12
node_count           = 1
node_boot_volume_gbs = 50

buckets = {
  assets = { access_type = "NoPublicAccess" }
}
