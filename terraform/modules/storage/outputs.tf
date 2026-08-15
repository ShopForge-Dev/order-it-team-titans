output "namespace" {
  description = "Object Storage namespace for the tenancy."
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "bucket_names" {
  description = "Created bucket names keyed by logical name."
  value       = { for k, b in oci_objectstorage_bucket.this : k => b.name }
}

output "container_repository_paths" {
  description = "Created OCIR repository paths."
  value       = [for r in oci_artifacts_container_repository.this : r.display_name]
}
