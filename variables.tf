# platform cluster name (e.g., prod-na1)
variable "cluster_name" {}

# platform-vpc id
variable "cluster_vpc_id" {}

# If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32.
variable "cluster_security_group_id" {
  default     = ""
}

# Whether to create a security group for the cluster or attach the cluster to `cluster_security_group_id`.
variable "cluster_create_security_group" {
  default = true
}

# If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster.
variable "worker_security_group_id" {
  default     = ""
}

# Whether to create a security group for the workers or attach the workers to `worker_security_group_id`.
variable "worker_create_security_group" {
  default = true
}

# Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80).
variable "worker_sg_ingress_from_port" {
  default     = "1025"
}

# A map of tags to add to all resources
variable "tags" {
  default     = {}
}