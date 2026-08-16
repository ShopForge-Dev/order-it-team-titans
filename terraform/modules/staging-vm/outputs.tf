###############################################################################
# Staging VM module — Outputs
###############################################################################

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

output "kubeconfig" {
  description = "Kubeconfig for the K3s cluster (base64 encoded)"
  value       = base64encode(templatefile("${path.module}/kubeconfig.tmpl", {
    public_ip = oci_core_instance.staging.public_ip
  }))
  sensitive   = true
}