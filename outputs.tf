# Security group ID attached to the EKS cluster.
output "cluster_security_group_id" {
  value       = "${local.cluster_security_group_id}"
}

# Security group ID attached to the EKS workers.
output "worker_security_group_id" {
  value       = "${local.worker_security_group_id}"
}