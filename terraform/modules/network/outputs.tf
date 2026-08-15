output "vcn_id" {
  description = "OCID of the VCN."
  value       = oci_core_vcn.this.id
}

output "lb_subnet_id" {
  description = "OCID of the public load balancer subnet."
  value       = oci_core_subnet.lb.id
}

output "worker_subnet_id" {
  description = "OCID of the worker node subnet."
  value       = oci_core_subnet.workers.id
}

output "api_subnet_id" {
  description = "OCID of the Kubernetes API endpoint subnet."
  value       = oci_core_subnet.api.id
}

output "nat_gateway_id" {
  description = "OCID of the NAT gateway, or null when workers are public."
  value       = try(oci_core_nat_gateway.this[0].id, null)
}
