locals {
  name_prefix  = "orderit-${var.environment}"
  cluster_name = "${local.name_prefix}-oke"

  # Subnet allocations
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.10.0/24"
  pod_subnet_cidr     = "10.0.20.0/24"

  tags = merge(
    {
      "Project"     = "orderit"
      "Environment" = var.environment
      "ManagedBy"   = "Terraform"
    },
    var.freeform_tags
  )
}
