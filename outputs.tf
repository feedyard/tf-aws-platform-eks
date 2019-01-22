# cluster id
output "cluster_id" {
  value = "${aws_eks_cluster.mod.id}"
}

# The Amazon Resource Name (ARN) of the cluster
output "cluster_arn" {
  value = "${aws_eks_cluster.mod.arn}"
}

# Nested attribute containing certificate-authority-data for the cluster
output "cluster_certificate_authority" {
  value = "${aws_eks_cluster.mod.certificate_authority}"
}

# endpoint for your Kubernetes API server
output "cluster_endpoint" {
  value = "${aws_eks_cluster.mod.endpoint}"
}

# platform version for the cluster
output "cluster_platform_version" {
  value = "${aws_eks_cluster.mod.platform_version}"
}

# Kubernetes server version for the cluster
output "cluster_version" {
  value = "${aws_eks_cluster.mod.version}"
}

# Additional nested attributes
output "cluster_vpc_config" {
  value = "${aws_eks_cluster.mod.vpc_config}"
}

# Security group ID attached to the EKS cluster.
output "cluster_security_group_id" {
  value = "${local.cluster_security_group_id}"
}

# Security group ID attached to the EKS workers.
output "worker_security_group_id" {
  value = "${local.worker_security_group_id}"
}
