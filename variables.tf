# feedyard/platform eks module

# external values (parse from vpc pipeline tf outputs)

# platform-vpc id
variable "cluster_vpc_id" {}

# platform-vpc subnets. subnet-public and subnet-private ids
variable "cluster_vpc_subnet_ids" {
  type = "list"
}

# ================================================================
# platform cluster name (e.g., prod-na1)
variable "cluster_name" {}

# ekse cluster version
variable "cluster_version" {
  default = "1.11"
}

#========
# these are set to the expected platform sandbox environment settings
#
# Whether to create a security group for the cluster or attach the cluster to `cluster_security_group_id`.
variable "cluster_create_security_group" {
  default = true
}

# If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32.
variable "cluster_security_group_id" {
  default = ""
}

# Timeout value when creating the EKS cluster.
variable "cluster_create_timeout" {
  default = "15m"
}

# Timeout value when deleting the EKS cluster.
variable "cluster_delete_timeout" {
  default = "15m"
}

#================
#  worker node info
#
# Whether to create a security group for the workers or attach the workers to `worker_security_group_id`.
variable "worker_create_security_group" {
  default = true
}

# If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster.
variable "worker_security_group_id" {
  default = ""
}

# list of additional security group ids to include in worker launch config
variable "worker_additional_security_group_ids" {
  type    = "list"
  default = true
}

# Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80).
variable "worker_sg_ingress_from_port" {
  default = "1025"
}

locals {
  workers_group_defaults = "${merge(local.workers_group_defaults_defaults, var.workers_group_defaults)}"

  workers_group_defaults_defaults = {
    name                          = "count.index"                     # Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used.
    ami_id                        = "${data.aws_ami.eks_worker.id}"   # AMI ID for the eks workers. If none is provided, Terraform will search for the latest version of their EKS optimized worker AMI.
    asg_desired_capacity          = "3"                               # Desired worker capacity in the autoscaling group.
    asg_max_size                  = "5"                               # Maximum worker capacity in the autoscaling group.
    asg_min_size                  = "3"                               # Minimum worker capacity in the autoscaling group.
    instance_type                 = "t2.xlarge"                       # Size of the workers instances.
    spot_price                    = ""                                # Cost of spot instance.
    placement_tenancy             = ""                                # The tenancy of the instance. Valid values are "default" or "dedicated".
    root_volume_size              = "100"                             # root volume size of workers instances.
    root_volume_type              = "gp2"                             # root volume type of workers instances, can be 'standard', 'gp2', or 'io1'
    root_iops                     = "0"                               # The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    key_name                      = ""                                # The key name that should be used for the instances in the autoscaling group
    pre_userdata                  = ""                                # userdata to pre-append to the default userdata.
    additional_userdata           = ""                                # userdata to append to the default userdata.
    ebs_optimized                 = true                              # sets whether to use ebs optimization on supported types.
    enable_monitoring             = true                              # Enables/disables detailed monitoring.
    public_ip                     = false                             # Associate a public ip address with a worker
    kubelet_extra_args            = ""                                # This string is passed directly to kubelet if set. Useful for adding labels or taints.
    subnets                       = ["${var.cluster_vpc_subnet_ids}"] # A comma delimited string of subnets to place the worker nodes in. i.e. subnet-123,subnet-456,subnet-789
    autoscaling_enabled           = false                             # Sets whether policy and matching tags will be added to allow autoscaling.
    additional_security_group_ids = ""                                # A comma delimited list of additional security group ids to include in worker launch config
    protect_from_scale_in         = false                             # Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible.
    iam_role_id                   = "${local.default_iam_role_id}"    # Use the specified IAM role if set.
    suspended_processes           = ""                                # A comma delimited string of processes to to suspend. i.e. AZRebalance,HealthCheck,ReplaceUnhealthy
    target_group_arns             = ""                                # A comma delimited list of ALB target group ARNs to be associated to the ASG
  }

  workers_group_launch_template_defaults = "${merge(local.workers_group_launch_template_defaults_defaults, var.workers_group_launch_template_defaults)}"

  workers_group_launch_template_defaults_defaults = {
    name                                     = "count.index"                                 # Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used.
    ami_id                                   = "${data.aws_ami.eks_worker.id}"               # AMI ID for the eks workers. If none is provided, Terraform will search for the latest version of their EKS optimized worker AMI.
    root_block_device_id                     = "${data.aws_ami.eks_worker.root_device_name}" # Root device name for workers. If non is provided, will assume default AMI was used.
    asg_desired_capacity                     = "1"                                           # Desired worker capacity in the autoscaling group.
    asg_max_size                             = "3"                                           # Maximum worker capacity in the autoscaling group.
    asg_min_size                             = "1"                                           # Minimum worker capacity in the autoscaling group.
    instance_type                            = "m4.large"                                    # Size of the workers instances.
    override_instance_type                   = "t3.large"                                    # Need to specify at least one additional instance type for mixed instances policy. The instance_type holds  higher priority for on demand instances.
    on_demand_allocation_strategy            = "prioritized"                                 # Strategy to use when launching on-demand instances. Valid values: prioritized.
    on_demand_base_capacity                  = "0"                                           # Absolute minimum amount of desired capacity that must be fulfilled by on-demand instances
    on_demand_percentage_above_base_capacity = "100"                                         # Percentage split between on-demand and Spot instances above the base on-demand capacity
    spot_allocation_strategy                 = "lowest-price"                                # The only valid value is lowest-price, which is also the default value. The Auto Scaling group selects the cheapest Spot pools and evenly allocates your Spot capacity across the number of Spot pools that you specify.
    spot_instance_pools                      = 10                                            # "Number of Spot pools per availability zone to allocate capacity. EC2 Auto Scaling selects the cheapest Spot pools and evenly allocates Spot capacity across the number of Spot pools that you specify."
    spot_max_price                           = ""                                            # Maximum price per unit hour that the user is willing to pay for the Spot instances. Default is the on-demand price
    spot_price                               = ""                                            # Cost of spot instance.
    placement_tenancy                        = "default"                                     # The tenancy of the instance. Valid values are "default" or "dedicated".
    root_volume_size                         = "100"                                         # root volume size of workers instances.
    root_volume_type                         = "gp2"                                         # root volume type of workers instances, can be 'standard', 'gp2', or 'io1'
    root_iops                                = "0"                                           # The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    key_name                                 = ""                                            # The key name that should be used for the instances in the autoscaling group
    pre_userdata                             = ""                                            # userdata to pre-append to the default userdata.
    additional_userdata                      = ""                                            # userdata to append to the default userdata.
    ebs_optimized                            = true                                          # sets whether to use ebs optimization on supported types.
    enable_monitoring                        = true                                          # Enables/disables detailed monitoring.
    public_ip                                = false                                         # Associate a public ip address with a worker
    kubelet_extra_args                       = ""                                            # This string is passed directly to kubelet if set. Useful for adding labels or taints.
    subnets                                  = ["${var.cluster_vpc_subnet_ids}"]             # A comma delimited string of subnets to place the worker nodes in. i.e. subnet-123,subnet-456,subnet-789
    autoscaling_enabled                      = false                                         # Sets whether policy and matching tags will be added to allow autoscaling.
    additional_security_group_ids            = ""                                            # A comma delimited list of additional security group ids to include in worker launch config
    protect_from_scale_in                    = false                                         # Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible.
    iam_role_id                              = "${local.default_iam_role_id}"                # Use the specified IAM role if set.
    suspended_processes                      = ""                                            # A comma delimited string of processes to to suspend. i.e. AZRebalance,HealthCheck,ReplaceUnhealthy
    target_group_arns                        = ""                                            # A comma delimited list of ALB target group ARNs to be associated to the ASG
  }
}

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"]
}

variable "workers_group_defaults" {
  description = "Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys."
  type        = "map"
  default     = {}
}

# A list of maps defining worker group configurations to be defined using AWS Launch Configurations. See workers_group_defaults for valid keys.
variable "worker_groups" {
  type = "list"

  default = [
    {
      "name" = "default"
    },
  ]
}

# The number of maps contained within the worker_groups list.
variable "worker_group_count" {
  type    = "string"
  default = "1"
}

variable "worker_groups_launch_template" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults for valid keys."
  type        = "list"

  default = [
    {
      "name" = "default"
    },
  ]
}

variable "workers_group_launch_template_defaults" {
  description = "Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys."
  type        = "map"
  default     = {}
}

variable "worker_group_launch_template_count" {
  description = "The number of maps contained within the worker_groups_launch_template list."
  type        = "string"
  default     = "0"
}

# A map of tags to add to all resources
variable "tags" {
  default = {}
}
