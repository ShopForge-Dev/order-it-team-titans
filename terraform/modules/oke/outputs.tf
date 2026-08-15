output "cluster_id" {
  description = "OCID of the OKE cluster."
  value       = oci_containerengine_cluster.this.id
}

output "cluster_name" {
  description = "Display name of the OKE cluster."
  value       = oci_containerengine_cluster.this.name
}

output "kubernetes_version" {
  description = "Kubernetes version the cluster runs."
  value       = local.k8s_version
}

output "node_pool_id" {
  description = "OCID of the worker node pool. Needed by the nightly scale-to-zero job."
  value       = oci_containerengine_node_pool.this.id
}

output "node_image_id" {
  description = "OCID of the worker node image selected for this Kubernetes version."
  value       = local.node_image_id
}

output "public_endpoint" {
  description = "Public Kubernetes API endpoint, empty when the endpoint is private."
  value       = try(oci_containerengine_cluster.this.endpoints[0].public_endpoint, "")
}

output "private_endpoint" {
  description = "Private Kubernetes API endpoint."
  value       = try(oci_containerengine_cluster.this.endpoints[0].private_endpoint, "")
}

output "kube_config" {
  description = "Rendered kubeconfig for the cluster."
  value       = data.oci_containerengine_cluster_kube_config.this.content
  sensitive   = true
}
