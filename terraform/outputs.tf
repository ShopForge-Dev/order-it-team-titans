output "compartment_ocid" {
  description = "Compartment holding the stack."
  value       = module.iam.compartment_ocid
}

output "region" {
  description = "Region the stack is deployed in."
  value       = var.region
}

output "cluster_id" {
  description = "OKE cluster OCID."
  value       = module.oke.cluster_id
}

output "cluster_name" {
  description = "OKE cluster display name."
  value       = module.oke.cluster_name
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster."
  value       = module.oke.kubernetes_version
}

output "node_pool_id" {
  description = "Worker node pool OCID — pass to the nightly scale-to-zero job."
  value       = module.oke.node_pool_id
}

output "cluster_public_endpoint" {
  description = "Public Kubernetes API endpoint."
  value       = module.oke.public_endpoint
}

output "vcn_id" {
  description = "VCN OCID."
  value       = module.network.vcn_id
}

output "lb_subnet_id" {
  description = "Subnet OCID for the ingress load balancer. Referenced by the ingress-nginx Service annotation."
  value       = module.network.lb_subnet_id
}

output "object_storage_namespace" {
  description = "Object Storage namespace."
  value       = module.storage.namespace
}

output "bucket_names" {
  description = "Created Object Storage buckets."
  value       = module.storage.bucket_names
}

output "kubeconfig_command" {
  description = "Command that writes a kubeconfig for this cluster."
  value = join(" ", [
    "oci ce cluster create-kubeconfig",
    "--cluster-id ${module.oke.cluster_id}",
    "--file $HOME/.kube/config",
    "--region ${var.region}",
    "--token-version 2.0.0",
    "--kube-endpoint ${var.api_endpoint_is_public ? "PUBLIC_ENDPOINT" : "PRIVATE_ENDPOINT"}",
  ])
}

output "scale_to_zero_command" {
  description = "Park the node pool overnight to preserve trial credits."
  value       = "oci ce node-pool update --node-pool-id ${module.oke.node_pool_id} --size 0"
}

output "scale_up_command" {
  description = "Restore the node pool."
  value       = "oci ce node-pool update --node-pool-id ${module.oke.node_pool_id} --size ${var.node_count}"
}
