# grainger-di-tf-aws-cluster-eks module

# Name of the EKS cluster. Also used as a prefix in names of related resources.
variable "cluster_name" {}

# Kubernetes version to use for the EKS cluster.
variable "cluster_version" {
  default = "1.11"
}

# Whether to write and apply the aws-auth configmap file.
variable "manage_aws_auth" {
  default = true
}

# Whether to create a security group for the cluster or attach the cluster to `cluster_security_group_id`.
variable "cluster_create_security_group" {
  default = true
}

# If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32.
variable "cluster_security_group_id" {
  default = ""
}

# Where to save the Kubectl config file (if `write_kubeconfig = true`). Should end in a forward slash `/` .
variable "config_output_path" {
  default = "./"
}

variable "write_kubeconfig" {
  description = "Whether to write a Kubectl config file containing the cluster configuration. Saved to `config_output_path`."
  default     = true
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
  type        = "list"
  default     = []
}

variable "map_accounts_count" {
  description = "The count of accounts in the map_accounts list."
  type        = "string"
  default     = 0
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
  type        = "list"
  default     = []
}

variable "map_roles_count" {
  description = "The count of roles in the map_roles list."
  type        = "string"
  default     = 0
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
  type        = "list"
  default     = []
}

variable "map_users_count" {
  description = "The count of roles in the map_users list."
  type        = "string"
  default     = 0
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = "map"
  default     = {}
}

variable "worker_groups" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Configurations. See workers_group_defaults for valid keys."
  type        = "list"

  default = [
    {
      "name" = "default"
    },
  ]
}

variable "worker_group_count" {
  description = "The number of maps contained within the worker_groups list."
  type        = "string"
  default     = "1"
}

variable "workers_group_defaults" {
  description = "Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys."
  type        = "map"
  default     = {}
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

variable "worker_group_launch_template_count" {
  description = "The number of maps contained within the worker_groups_launch_template list."
  type        = "string"
  default     = "0"
}

variable "workers_group_launch_template_defaults" {
  description = "Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys."
  type        = "map"
  default     = {}
}

variable "worker_security_group_id" {
  description = "If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster."
  default     = ""
}

variable "worker_additional_security_group_ids" {
  description = "A list of additional security group ids to attach to worker instances"
  type        = "list"
  default     = []
}

variable "worker_sg_ingress_from_port" {
  description = "Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80, or 443)."
  default     = "1025"
}

variable "kubeconfig_aws_authenticator_command" {
  description = "Command to use to fetch AWS EKS credentials."
  default     = "aws-iam-authenticator"
}

variable "kubeconfig_aws_authenticator_command_args" {
  description = "Default arguments passed to the authenticator command. Defaults to [token -i $cluster_name]."
  type        = "list"
  default     = []
}

variable "kubeconfig_aws_authenticator_additional_args" {
  description = "Any additional arguments to pass to the authenticator such as the role to assume. e.g. [\"-r\", \"MyEksRole\"]."
  type        = "list"
  default     = []
}

variable "kubeconfig_aws_authenticator_env_variables" {
  description = "Environment variables that should be used when executing the authenticator. e.g. { AWS_PROFILE = \"eks\"}."
  type        = "map"
  default     = {}
}

variable "kubeconfig_name" {
  description = "Override the default name used for items kubeconfig."
  default     = ""
}

variable "cluster_create_timeout" {
  description = "Timeout value when creating the EKS cluster."
  default     = "15m"
}

variable "cluster_delete_timeout" {
  description = "Timeout value when deleting the EKS cluster."
  default     = "15m"
}

variable "local_exec_interpreter" {
  description = "Command to run for local-exec resources. Must be a shell-style interpreter. If you are on Windows Git Bash is a good choice."
  type        = "list"
  default     = ["/bin/sh", "-c"]
}

variable "worker_create_security_group" {
  description = "Whether to create a security group for the workers or attach the workers to `worker_security_group_id`."
  default     = true
}

locals {
  asg_tags = ["${null_resource.tags_as_list_of_maps.*.triggers}"]

  # Followed recommendation http://67bricks.com/blog/?p=85
  # to workaround terraform not supporting short circut evaluation
  cluster_security_group_id = "${coalesce(join("", aws_security_group.cluster.*.id), var.cluster_security_group_id)}"

  worker_security_group_id = "${coalesce(join("", aws_security_group.workers.*.id), var.worker_security_group_id)}"
  default_iam_role_id      = "${element(concat(aws_iam_role.workers.*.id, list("")), 0)}"
  kubeconfig_name          = "${var.kubeconfig_name == "" ? "eks_${var.cluster_name}" : var.kubeconfig_name}"

  workers_group_defaults_defaults = {
    name                          = "count.index"                          # Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used.
    ami_id                        = "${data.aws_ami.eks_worker.id}"        # AMI ID for the eks workers. If none is provided, Terraform will search for the latest version of their EKS optimized worker AMI.
    asg_desired_capacity          = "1"                                    # Desired worker capacity in the autoscaling group.
    asg_max_size                  = "3"                                    # Maximum worker capacity in the autoscaling group.
    asg_min_size                  = "1"                                    # Minimum worker capacity in the autoscaling group.
    instance_type                 = "t2.xlarge"                            # Size of the workers instances.
    spot_price                    = ""                                     # Cost of spot instance.
    placement_tenancy             = ""                                     # The tenancy of the instance. Valid values are "default" or "dedicated".
    root_volume_size              = "100"                                  # root volume size of workers instances.
    root_volume_type              = "gp2"                                  # root volume type of workers instances, can be 'standard', 'gp2', or 'io1'
    root_iops                     = "0"                                    # The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    key_name                      = ""                                     # The key name that should be used for the instances in the autoscaling group
    pre_userdata                  = ""                                     # userdata to pre-append to the default userdata.
    additional_userdata           = ""                                     # userdata to append to the default userdata.
    ebs_optimized                 = true                                   # sets whether to use ebs optimization on supported types.
    enable_monitoring             = true                                   # Enables/disables detailed monitoring.
    public_ip                     = false                                  # Associate a public ip address with a worker
    kubelet_extra_args            = ""                                     # This string is passed directly to kubelet if set. Useful for adding labels or taints.
    subnets                       = "${join(",", var.cluster_subnet_ids)}" # A comma delimited string of subnets to place the worker nodes in. i.e. subnet-123,subnet-456,subnet-789
    autoscaling_enabled           = true                                   # Sets whether policy and matching tags will be added to allow autoscaling.
    additional_security_group_ids = ""                                     # A comma delimited list of additional security group ids to include in worker launch config
    protect_from_scale_in         = false                                  # Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible.
    iam_role_id                   = "${local.default_iam_role_id}"         # Use the specified IAM role if set.
    suspended_processes           = ""                                     # A comma delimited string of processes to to suspend. i.e. AZRebalance,HealthCheck,ReplaceUnhealthy
    target_group_arns             = ""                                     # A comma delimited list of ALB target group ARNs to be associated to the ASG
  }

  workers_group_defaults = "${merge(local.workers_group_defaults_defaults, var.workers_group_defaults)}"

  workers_group_launch_template_defaults_defaults = {
    name                                     = "count.index"                                 # Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used.
    ami_id                                   = "${data.aws_ami.eks_worker.id}"               # AMI ID for the eks workers. If none is provided, Terraform will search for the latest version of their EKS optimized worker AMI.
    root_block_device_id                     = "${data.aws_ami.eks_worker.root_device_name}" # Root device name for workers. If non is provided, will assume default AMI was used.
    asg_desired_capacity                     = "1"                                           # Desired worker capacity in the autoscaling group.
    asg_max_size                             = "3"                                           # Maximum worker capacity in the autoscaling group.
    asg_min_size                             = "1"                                           # Minimum worker capacity in the autoscaling group.
    instance_type                            = "t2.xlarge"                                   # Size of the workers instances.
    override_instance_type                   = "m4.xlarge"                                   # Need to specify at least one additional instance type for mixed instances policy. The instance_type holds  higher priority for on demand instances.
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
    subnets                                  = "${join(",", var.cluster_subnet_ids)}"        # A comma delimited string of subnets to place the worker nodes in. i.e. subnet-123,subnet-456,subnet-789
    autoscaling_enabled                      = true                                          # Sets whether policy and matching tags will be added to allow autoscaling.
    additional_security_group_ids            = ""                                            # A comma delimited list of additional security group ids to include in worker launch config
    protect_from_scale_in                    = false                                         # Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible.
    iam_role_id                              = "${local.default_iam_role_id}"                # Use the specified IAM role if set.
    suspended_processes                      = ""                                            # A comma delimited string of processes to to suspend. i.e. AZRebalance,HealthCheck,ReplaceUnhealthy
    target_group_arns                        = ""                                            # A comma delimited list of ALB target group ARNs to be associated to the ASG
  }

  workers_group_launch_template_defaults = "${merge(local.workers_group_launch_template_defaults_defaults, var.workers_group_launch_template_defaults)}"

  ebs_optimized = {
    "c1.medium"    = false
    "c1.xlarge"    = true
    "c3.large"     = false
    "c3.xlarge"    = true
    "c3.2xlarge"   = true
    "c3.4xlarge"   = true
    "c3.8xlarge"   = false
    "c4.large"     = true
    "c4.xlarge"    = true
    "c4.2xlarge"   = true
    "c4.4xlarge"   = true
    "c4.8xlarge"   = true
    "c5.large"     = true
    "c5.xlarge"    = true
    "c5.2xlarge"   = true
    "c5.4xlarge"   = true
    "c5.9xlarge"   = true
    "c5.18xlarge"  = true
    "c5d.large"    = true
    "c5d.xlarge"   = true
    "c5d.2xlarge"  = true
    "c5d.4xlarge"  = true
    "c5d.9xlarge"  = true
    "c5d.18xlarge" = true
    "cc2.8xlarge"  = false
    "cr1.8xlarge"  = false
    "d2.xlarge"    = true
    "d2.2xlarge"   = true
    "d2.4xlarge"   = true
    "d2.8xlarge"   = true
    "f1.2xlarge"   = true
    "f1.4xlarge"   = true
    "f1.16xlarge"  = true
    "g2.2xlarge"   = true
    "g2.8xlarge"   = false
    "g3.4xlarge"   = true
    "g3.8xlarge"   = true
    "g3.16xlarge"  = true
    "h1.2xlarge"   = true
    "h1.4xlarge"   = true
    "h1.8xlarge"   = true
    "h1.16xlarge"  = true
    "hs1.8xlarge"  = false
    "i2.xlarge"    = true
    "i2.2xlarge"   = true
    "i2.4xlarge"   = true
    "i2.8xlarge"   = false
    "i3.large"     = true
    "i3.xlarge"    = true
    "i3.2xlarge"   = true
    "i3.4xlarge"   = true
    "i3.8xlarge"   = true
    "i3.16xlarge"  = true
    "i3.metal"     = true
    "m1.small"     = false
    "m1.medium"    = false
    "m1.large"     = true
    "m1.xlarge"    = true
    "m2.xlarge"    = false
    "m2.2xlarge"   = true
    "m2.4xlarge"   = true
    "m3.medium"    = false
    "m3.large"     = false
    "m3.xlarge"    = true
    "m3.2xlarge"   = true
    "m4.large"     = true
    "m4.xlarge"    = true
    "m4.2xlarge"   = true
    "m4.4xlarge"   = true
    "m4.10xlarge"  = true
    "m4.16xlarge"  = true
    "m5.large"     = true
    "m5.xlarge"    = true
    "m5.2xlarge"   = true
    "m5.4xlarge"   = true
    "m5.9xlarge"   = true
    "m5.18xlarge"  = true
    "m5d.large"    = true
    "m5d.xlarge"   = true
    "m5d.2xlarge"  = true
    "m5d.4xlarge"  = true
    "m5d.12xlarge" = true
    "m5d.24xlarge" = true
    "p2.xlarge"    = true
    "p2.8xlarge"   = true
    "p2.16xlarge"  = true
    "p3.2xlarge"   = true
    "p3.8xlarge"   = true
    "p3.16xlarge"  = true
    "r3.large"     = false
    "r3.xlarge"    = true
    "r3.2xlarge"   = true
    "r3.4xlarge"   = true
    "r3.8xlarge"   = false
    "r4.large"     = true
    "r4.xlarge"    = true
    "r4.2xlarge"   = true
    "r4.4xlarge"   = true
    "r4.8xlarge"   = true
    "r4.16xlarge"  = true
    "t1.micro"     = false
    "t2.nano"      = false
    "t2.micro"     = false
    "t2.small"     = false
    "t2.medium"    = false
    "t2.large"     = false
    "t2.xlarge"    = false
    "t2.2xlarge"   = false
    "t3.nano"      = true
    "t3.micro"     = true
    "t3.small"     = true
    "t3.medium"    = true
    "t3.large"     = true
    "t3.xlarge"    = true
    "t3.2xlarge"   = true
    "x1.16xlarge"  = true
    "x1.32xlarge"  = true
    "x1e.xlarge"   = true
    "x1e.2xlarge"  = true
    "x1e.4xlarge"  = true
    "x1e.8xlarge"  = true
    "x1e.16xlarge" = true
    "x1e.32xlarge" = true
  }
}

data "aws_region" "current" {}

data "aws_iam_policy_document" "workers_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
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

data "aws_iam_policy_document" "cluster_assume_role_policy" {
  statement {
    sid = "EKSClusterAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "template_file" "kubeconfig" {
  template = "${file("${path.module}/templates/kubeconfig.tpl")}"

  vars {
    kubeconfig_name                   = "${local.kubeconfig_name}"
    endpoint                          = "${aws_eks_cluster.mod.endpoint}"
    region                            = "${data.aws_region.current.name}"
    cluster_auth_base64               = "${aws_eks_cluster.mod.certificate_authority.0.data}"
    aws_authenticator_command         = "${var.kubeconfig_aws_authenticator_command}"
    aws_authenticator_command_args    = "${length(var.kubeconfig_aws_authenticator_command_args) > 0 ? "        - ${join("\n        - ", var.kubeconfig_aws_authenticator_command_args)}" : "        - ${join("\n        - ", formatlist("\"%s\"", list("token", "-i", aws_eks_cluster.mod.name)))}"}"
    aws_authenticator_additional_args = "${length(var.kubeconfig_aws_authenticator_additional_args) > 0 ? "        - ${join("\n        - ", var.kubeconfig_aws_authenticator_additional_args)}" : ""}"
    aws_authenticator_env_variables   = "${length(var.kubeconfig_aws_authenticator_env_variables) > 0 ? "      env:\n${join("\n", data.template_file.aws_authenticator_env_variables.*.rendered)}" : ""}"
  }
}

data "template_file" "aws_authenticator_env_variables" {
  template = <<EOF
        - name: $${key}
          value: $${value}
EOF

  count = "${length(var.kubeconfig_aws_authenticator_env_variables)}"

  vars {
    value = "${element(values(var.kubeconfig_aws_authenticator_env_variables), count.index)}"
    key   = "${element(keys(var.kubeconfig_aws_authenticator_env_variables), count.index)}"
  }
}

data "template_file" "userdata" {
  template = "${file("${path.module}/templates/userdata.sh.tpl")}"
  count    = "${var.worker_group_count}"

  vars {
    cluster_name        = "${aws_eks_cluster.mod.name}"
    endpoint            = "${aws_eks_cluster.mod.endpoint}"
    cluster_auth_base64 = "${aws_eks_cluster.mod.certificate_authority.0.data}"
    pre_userdata        = "${lookup(var.worker_groups[count.index], "pre_userdata", local.workers_group_defaults["pre_userdata"])}"
    additional_userdata = "${lookup(var.worker_groups[count.index], "additional_userdata", local.workers_group_defaults["additional_userdata"])}"
    kubelet_extra_args  = "${lookup(var.worker_groups[count.index], "kubelet_extra_args", local.workers_group_defaults["kubelet_extra_args"])}"
  }
}

data "template_file" "launch_template_userdata" {
  template = "${file("${path.module}/templates/userdata.sh.tpl")}"
  count    = "${var.worker_group_launch_template_count}"

  vars {
    cluster_name        = "${aws_eks_cluster.mod.name}"
    endpoint            = "${aws_eks_cluster.mod.endpoint}"
    cluster_auth_base64 = "${aws_eks_cluster.mod.certificate_authority.0.data}"
    pre_userdata        = "${lookup(var.worker_groups_launch_template[count.index], "pre_userdata", local.workers_group_defaults["pre_userdata"])}"
    additional_userdata = "${lookup(var.worker_groups_launch_template[count.index], "additional_userdata", local.workers_group_defaults["additional_userdata"])}"
    kubelet_extra_args  = "${lookup(var.worker_groups_launch_template[count.index], "kubelet_extra_args", local.workers_group_defaults["kubelet_extra_args"])}"
  }
}
