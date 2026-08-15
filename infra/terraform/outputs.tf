output "vcn_id" {
  description = "OCID of the created VCN"
  value       = oci_core_vcn.orderit_vcn.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "OCID of the private subnet"
  value       = oci_core_subnet.private_subnet.id
}

output "oke_cluster_id" {
  description = "OCID of the OKE Kubernetes cluster"
  value       = oci_containerengine_cluster.orderit_oke.id
}

output "oke_cluster_k8s_version" {
  description = "Kubernetes version of the cluster"
  value       = oci_containerengine_cluster.orderit_oke.kubernetes_version
}

output "node_pool_id" {
  description = "OCID of the OKE node pool"
  value       = oci_containerengine_node_pool.orderit_node_pool.id
}

output "ocir_backend_repository_id" {
  description = "OCID of the backend container repository"
  value       = oci_artifacts_container_repository.ocir_backend.id
}

output "ocir_frontend_repository_id" {
  description = "OCID of the frontend container repository"
  value       = oci_artifacts_container_repository.ocir_frontend.id
}

output "kubeconfig_command" {
  description = "OCI CLI command to generate local kubeconfig for the OKE cluster"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.orderit_oke.id} --file ~/.kube/config --region ${var.region} --token-version 2.0.0"
}
