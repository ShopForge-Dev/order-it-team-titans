output "compartment_ocid" {
  description = "OCID of the compartment the stack deploys into."
  value       = local.compartment_ocid
}

output "dynamic_group_name" {
  description = "Name of the worker node dynamic group."
  value       = oci_identity_dynamic_group.nodes.name
}
