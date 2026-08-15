###############################################################################
# prod — private workers behind a NAT gateway.
#
# Compute stays inside Always-Free (2 x 2 OCPU / 12 GB = the full A1
# allowance). The NAT gateway is the one billed component and draws on the
# $300 trial credits. Set workers_in_public_subnet = true to drop it to $0 at
# the cost of putting nodes on public IPs.
###############################################################################

environment = "prod"
region      = "ap-mumbai-1"

# Networking
vcn_cidr                 = "10.1.0.0/16"
lb_subnet_cidr           = "10.1.1.0/24"
worker_subnet_cidr       = "10.1.10.0/24"
api_subnet_cidr          = "10.1.0.0/28"
workers_in_public_subnet = false
enable_nat_gateway       = true
api_endpoint_is_public   = true

# Restrict to the CI runner egress range and the operator's IP before go-live.
api_allowed_cidrs = ["0.0.0.0/0"]

# Compute — 2 nodes x 2 OCPU / 12 GB, the full Always-Free A1 allowance.
# Matches the design doc's node pool size of 2 (scaled to 0 overnight).
cluster_type         = "BASIC_CLUSTER"
node_shape           = "VM.Standard.A1.Flex"
node_ocpus           = 2
node_memory_gbs      = 12
node_count           = 2
node_boot_volume_gbs = 50

buckets = {
  assets  = { access_type = "NoPublicAccess" }
  backups = { versioning = "Enabled" }
}
