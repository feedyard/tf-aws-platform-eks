resource "aws_autoscaling_group" "workers" {
  name_prefix           = "${aws_eks_cluster.mod.name}-${lookup(var.worker_groups[count.index], "name", count.index)}"
  desired_capacity      = "${lookup(var.worker_groups[count.index], "asg_desired_capacity", local.workers_group_defaults["asg_desired_capacity"])}"
  max_size              = "${lookup(var.worker_groups[count.index], "asg_max_size", local.workers_group_defaults["asg_max_size"])}"
  min_size              = "${lookup(var.worker_groups[count.index], "asg_min_size", local.workers_group_defaults["asg_min_size"])}"
  target_group_arns     = ["${compact(split(",", coalesce(lookup(var.worker_groups[count.index], "target_group_arns", ""), local.workers_group_defaults["target_group_arns"])))}"]
  launch_configuration  = "${element(aws_launch_configuration.workers.*.id, count.index)}"
  vpc_zone_identifier   = ["${split(",", coalesce(lookup(var.worker_groups[count.index], "subnets", ""), local.workers_group_defaults["subnets"]))}"]
  protect_from_scale_in = "${lookup(var.worker_groups[count.index], "protect_from_scale_in", local.workers_group_defaults["protect_from_scale_in"])}"
  suspended_processes   = ["${compact(split(",", coalesce(lookup(var.worker_groups[count.index], "suspended_processes", ""), local.workers_group_defaults["suspended_processes"])))}"]
  count                 = "${var.worker_group_count}"

  tags = ["${concat(
    list(
      map("key", "Cluster", "value", "${aws_eks_cluster.mod.name}", "propagate_at_launch", true),
      map("key", "Name", "value", "${aws_eks_cluster.mod.name}-${lookup(var.worker_groups[count.index], "name", count.index)}-eks-asg", "propagate_at_launch", true),
      map("key", "kubernetes.io/cluster/${aws_eks_cluster.mod.name}", "value", "owned", "propagate_at_launch", true),
      map("key", "k8s.io/cluster-autoscaler/${lookup(var.worker_groups[count.index], "autoscaling_enabled", local.workers_group_defaults["autoscaling_enabled"]) == 1 ? "enabled" : "disabled"  }", "value", "true", "propagate_at_launch", false)
    ),
    local.asg_tags)
  }"]

  lifecycle {
    ignore_changes = ["desired_capacity"]
  }
}

resource "aws_launch_configuration" "workers" {
  name_prefix                 = "${aws_eks_cluster.mod.name}-${lookup(var.worker_groups[count.index], "name", count.index)}"
  associate_public_ip_address = "${lookup(var.worker_groups[count.index], "public_ip", local.workers_group_defaults["public_ip"])}"
  security_groups             = ["${local.worker_security_group_id}", "${var.worker_additional_security_group_ids}", "${compact(split(",",lookup(var.worker_groups[count.index],"additional_security_group_ids", local.workers_group_defaults["additional_security_group_ids"])))}"]
  iam_instance_profile        = "${element(aws_iam_instance_profile.workers.*.id, count.index)}"
  image_id                    = "${lookup(var.worker_groups[count.index], "ami_id", local.workers_group_defaults["ami_id"])}"
  instance_type               = "${lookup(var.worker_groups[count.index], "instance_type", local.workers_group_defaults["instance_type"])}"
  key_name                    = "${lookup(var.worker_groups[count.index], "key_name", local.workers_group_defaults["key_name"])}"
  user_data_base64            = "${base64encode(element(data.template_file.userdata.*.rendered, count.index))}"
  ebs_optimized               = "${lookup(var.worker_groups[count.index], "ebs_optimized", lookup(local.ebs_optimized, lookup(var.worker_groups[count.index], "instance_type", local.workers_group_defaults["instance_type"]), false))}"
  enable_monitoring           = "${lookup(var.worker_groups[count.index], "enable_monitoring", local.workers_group_defaults["enable_monitoring"])}"
  spot_price                  = "${lookup(var.worker_groups[count.index], "spot_price", local.workers_group_defaults["spot_price"])}"
  placement_tenancy           = "${lookup(var.worker_groups[count.index], "placement_tenancy", local.workers_group_defaults["placement_tenancy"])}"
  count                       = "${var.worker_group_count}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_size           = "${lookup(var.worker_groups[count.index], "root_volume_size", local.workers_group_defaults["root_volume_size"])}"
    volume_type           = "${lookup(var.worker_groups[count.index], "root_volume_type", local.workers_group_defaults["root_volume_type"])}"
    iops                  = "${lookup(var.worker_groups[count.index], "root_iops", local.workers_group_defaults["root_iops"])}"
    delete_on_termination = true
  }
}

# Security group for all nodes in the cluster
resource "aws_security_group" "workers" {
  name   = "${aws_eks_cluster.mod.name}-eks-worker-sg"
  vpc_id = "${data.aws_vpc.cluster_vpc.id}"
  count  = "${var.worker_create_security_group ? 1 : 0}"
  tags   = "${merge(var.tags, map("Name", "${aws_eks_cluster.mod.name}-eks-worker-sg", "kubernetes.io/cluster/${aws_eks_cluster.mod.name}", "owned"
  ))}"
}

# Allow nodes all egress to the Internet
resource "aws_security_group_rule" "workers_egress_internet" {
  protocol          = "-1"
  security_group_id = "${aws_security_group.workers.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
  count             = "${var.worker_create_security_group ? 1 : 0}"
}

# Allow node to communicate with each other
resource "aws_security_group_rule" "workers_ingress_self" {
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
  count                    = "${var.worker_create_security_group ? 1 : 0}"
}

# Allow workers Kubelets and pods to receive communication from the cluster control plane
resource "aws_security_group_rule" "workers_ingress_cluster" {
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = "${var.worker_sg_ingress_from_port}"
  to_port                  = 65535
  type                     = "ingress"
  count                    = "${var.worker_create_security_group ? 1 : 0}"
}

# Allow pods running extension API servers on port 443 to receive communication from cluster control plane
resource "aws_security_group_rule" "workers_ingress_cluster_https" {
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
  count                    = "${var.worker_create_security_group ? 1 : 0}"
}

resource "aws_iam_role" "workers" {
  name                  = "${aws_eks_cluster.mod.name}"
  assume_role_policy    = "${data.aws_iam_policy_document.workers_assume_role_policy.json}"
  force_detach_policies = true
}

resource "aws_iam_instance_profile" "workers" {
  name_prefix = "${aws_eks_cluster.mod.name}"
  role        = "${lookup(var.worker_groups[count.index], "iam_role_id",  lookup(local.workers_group_defaults, "iam_role_id"))}"
  count       = "${var.worker_group_count}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.workers.name}"
}

resource "null_resource" "tags_as_list_of_maps" {
  count = "${length(keys(var.tags))}"

  triggers = {
    key                 = "${element(keys(var.tags), count.index)}"
    value               = "${element(values(var.tags), count.index)}"
    propagate_at_launch = "true"
  }
}

resource "aws_iam_role_policy_attachment" "workers_dns" {
  policy_arn = "${aws_iam_policy.worker_dns.arn}"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_policy" "worker_dns" {
  name = "eks-worker-dns-${aws_eks_cluster.mod.name}"

  policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Effect": "Allow",
    "Action": [
      "route53:ChangeResourceRecordSets"
    ],
    "Resource": [
      "arn:aws:route53:::hostedzone/*"
    ]
  },
  {
    "Effect": "Allow",
    "Action": [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ],
    "Resource": [
      "*"
    ]
  }
]
}

EOF
}

resource "aws_iam_role_policy_attachment" "workers_autoscaling" {
  policy_arn = "${aws_iam_policy.worker_autoscaling.arn}"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_policy" "worker_autoscaling" {
  name_prefix = "eks-worker-autoscaling-${aws_eks_cluster.mod.name}"
  description = "EKS worker node autoscaling policy for cluster ${aws_eks_cluster.mod.name}"
  policy      = "${data.aws_iam_policy_document.worker_autoscaling.json}"
}

data "aws_iam_policy_document" "worker_autoscaling" {
  statement {
    sid    = "eksWorkerAutoscalingAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "eksWorkerAutoscalingOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${aws_eks_cluster.mod.name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}

resource "aws_autoscaling_group" "workers_launch_template" {
  name_prefix       = "${aws_eks_cluster.mod.name}-${lookup(var.worker_groups_launch_template[count.index], "name", count.index)}"
  desired_capacity  = "${lookup(var.worker_groups_launch_template[count.index], "asg_desired_capacity", local.workers_group_launch_template_defaults["asg_desired_capacity"])}"
  max_size          = "${lookup(var.worker_groups_launch_template[count.index], "asg_max_size", local.workers_group_launch_template_defaults["asg_max_size"])}"
  min_size          = "${lookup(var.worker_groups_launch_template[count.index], "asg_min_size", local.workers_group_launch_template_defaults["asg_min_size"])}"
  target_group_arns = ["${compact(split(",", coalesce(lookup(var.worker_groups_launch_template[count.index], "target_group_arns", ""), local.workers_group_launch_template_defaults["target_group_arns"])))}"]

  mixed_instances_policy {
    instances_distribution {
      on_demand_allocation_strategy            = "${lookup(var.worker_groups_launch_template[count.index], "on_demand_allocation_strategy", local.workers_group_launch_template_defaults["on_demand_allocation_strategy"])}"
      on_demand_base_capacity                  = "${lookup(var.worker_groups_launch_template[count.index], "on_demand_base_capacity", local.workers_group_launch_template_defaults["on_demand_base_capacity"])}"
      on_demand_percentage_above_base_capacity = "${lookup(var.worker_groups_launch_template[count.index], "on_demand_percentage_above_base_capacity", local.workers_group_launch_template_defaults["on_demand_percentage_above_base_capacity"])}"
      spot_allocation_strategy                 = "${lookup(var.worker_groups_launch_template[count.index], "spot_allocation_strategy", local.workers_group_launch_template_defaults["spot_allocation_strategy"])}"
      spot_instance_pools                      = "${lookup(var.worker_groups_launch_template[count.index], "spot_instance_pools", local.workers_group_launch_template_defaults["spot_instance_pools"])}"
      spot_max_price                           = "${lookup(var.worker_groups_launch_template[count.index], "spot_max_price", local.workers_group_launch_template_defaults["spot_max_price"])}"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = "${element(aws_launch_template.workers_launch_template.*.id, count.index)}"
        version            = "$Latest"
      }

      override {
        instance_type = "${lookup(var.worker_groups_launch_template[count.index], "instance_type", local.workers_group_launch_template_defaults["instance_type"])}"
      }

      override {
        instance_type = "${lookup(var.worker_groups_launch_template[count.index], "override_instance_type", local.workers_group_launch_template_defaults["override_instance_type"])}"
      }
    }
  }

  vpc_zone_identifier   = ["${split(",", coalesce(lookup(var.worker_groups_launch_template[count.index], "subnets", ""), local.workers_group_launch_template_defaults["subnets"]))}"]
  protect_from_scale_in = "${lookup(var.worker_groups_launch_template[count.index], "protect_from_scale_in", local.workers_group_launch_template_defaults["protect_from_scale_in"])}"
  suspended_processes   = ["${compact(split(",", coalesce(lookup(var.worker_groups_launch_template[count.index], "suspended_processes", ""), local.workers_group_launch_template_defaults["suspended_processes"])))}"]
  count                 = "${var.worker_group_launch_template_count}"

  tags = ["${concat(
    list(
      map("key", "Name", "value", "${aws_eks_cluster.mod.name}-${lookup(var.worker_groups_launch_template[count.index], "name", count.index)}-eks_asg", "propagate_at_launch", true),
      map("key", "kubernetes.io/cluster/${aws_eks_cluster.mod.name}", "value", "owned", "propagate_at_launch", true),
      map("key", "k8s.io/cluster-autoscaler/${lookup(var.worker_groups_launch_template[count.index], "autoscaling_enabled", local.workers_group_launch_template_defaults["autoscaling_enabled"]) == 1 ? "enabled" : "disabled"  }", "value", "true", "propagate_at_launch", false)
    ),
    local.asg_tags)
  }"]

  lifecycle {
    ignore_changes = ["desired_capacity"]
  }
}

resource "aws_launch_template" "workers_launch_template" {
  name_prefix = "${aws_eks_cluster.mod.name}-${lookup(var.worker_groups_launch_template[count.index], "name", count.index)}"

  network_interfaces {
    associate_public_ip_address = "${lookup(var.worker_groups_launch_template[count.index], "public_ip", local.workers_group_launch_template_defaults["public_ip"])}"
    security_groups             = ["${local.worker_security_group_id}", "${var.worker_additional_security_group_ids}", "${compact(split(",",lookup(var.worker_groups_launch_template[count.index],"additional_security_group_ids", local.workers_group_launch_template_defaults["additional_security_group_ids"])))}"]
  }

  iam_instance_profile = {
    name = "${element(aws_iam_instance_profile.workers_launch_template.*.name, count.index)}"
  }

  image_id      = "${lookup(var.worker_groups_launch_template[count.index], "ami_id", local.workers_group_launch_template_defaults["ami_id"])}"
  instance_type = "${lookup(var.worker_groups_launch_template[count.index], "instance_type", local.workers_group_launch_template_defaults["instance_type"])}"
  key_name      = "${lookup(var.worker_groups_launch_template[count.index], "key_name", local.workers_group_launch_template_defaults["key_name"])}"
  user_data     = "${base64encode(element(data.template_file.launch_template_userdata.*.rendered, count.index))}"
  ebs_optimized = "${lookup(var.worker_groups_launch_template[count.index], "ebs_optimized", lookup(local.ebs_optimized, lookup(var.worker_groups_launch_template[count.index], "instance_type", local.workers_group_launch_template_defaults["instance_type"]), false))}"

  monitoring {
    enabled = "${lookup(var.worker_groups_launch_template[count.index], "enable_monitoring", local.workers_group_launch_template_defaults["enable_monitoring"])}"
  }

  placement {
    tenancy = "${lookup(var.worker_groups_launch_template[count.index], "placement_tenancy", local.workers_group_launch_template_defaults["placement_tenancy"])}"
  }

  count = "${var.worker_group_launch_template_count}"

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = "${data.aws_ami.eks_worker.root_device_name}"

    ebs {
      volume_size           = "${lookup(var.worker_groups_launch_template[count.index], "root_volume_size", local.workers_group_launch_template_defaults["root_volume_size"])}"
      volume_type           = "${lookup(var.worker_groups_launch_template[count.index], "root_volume_type", local.workers_group_launch_template_defaults["root_volume_type"])}"
      iops                  = "${lookup(var.worker_groups_launch_template[count.index], "root_iops", local.workers_group_launch_template_defaults["root_iops"])}"
      delete_on_termination = true
    }
  }
}

resource "aws_iam_instance_profile" "workers_launch_template" {
  name_prefix = "${aws_eks_cluster.mod.name}"
  role        = "${lookup(var.worker_groups_launch_template[count.index], "iam_role_id",  lookup(local.workers_group_launch_template_defaults, "iam_role_id"))}"
  count       = "${var.worker_group_launch_template_count}"
}
