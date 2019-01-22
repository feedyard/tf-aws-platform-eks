# platform eks-worker nodes

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
      map("key", "Name", "value", "${aws_eks_cluster.mod.name}-${lookup(var.worker_groups[count.index], "name", count.index)}-eks_asg", "propagate_at_launch", true),
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

resource "aws_security_group" "workers" {
  description = "Security group for all nodes in the cluster."
  count       = "${var.worker_create_security_group ? 1 : 0}"

  name_prefix = "${var.cluster_name}"
  vpc_id      = "${var.cluster_vpc_id}"
  tags        = "${merge(var.tags, map("Name", "${var.cluster_name}-eks-worker-sg", "kubernetes.io/cluster/${var.cluster_name}", "shared"))}"
}

resource "aws_security_group_rule" "workers_egress_internet" {
  description = "Allow nodes all egress to the Internet."
  count       = "${var.worker_create_security_group ? 1 : 0}"

  protocol          = "-1"
  security_group_id = "${aws_security_group.workers.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "workers_ingress_self" {
  description = "Allow node to communicate with each other."
  count       = "${var.worker_create_security_group ? 1 : 0}"

  protocol                 = "-1"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_cluster" {
  description = "Allow workers Kubelets and pods to receive communication from the cluster control plane."
  count       = "${var.worker_create_security_group ? 1 : 0}"

  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = "${var.worker_sg_ingress_from_port}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_cluster_https" {
  description = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane."
  count       = "${var.worker_create_security_group ? 1 : 0}"

  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_iam_role" "workers" {
  name_prefix           = "${aws_eks_cluster.mod.name}"
  assume_role_policy    = "${data.aws_iam_policy_document.workers_assume_role_policy.json}"
  force_detach_policies = true
}

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

resource "null_resource" "tags_as_list_of_maps" {
  count = "${length(keys(var.tags))}"

  triggers = {
    key                 = "${element(keys(var.tags), count.index)}"
    value               = "${element(values(var.tags), count.index)}"
    propagate_at_launch = "true"
  }
}

locals {
  asg_tags                 = ["${null_resource.tags_as_list_of_maps.*.triggers}"]
  worker_security_group_id = "${coalesce(join("", aws_security_group.workers.*.id), var.worker_security_group_id)}"
  default_iam_role_id      = "${element(concat(aws_iam_role.workers.*.id, list("")), 0)}"

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

# Worker Groups using Launch Templates

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
      map("key", "Name", "value", "${aws_eks_cluster.this.name}-${lookup(var.worker_groups_launch_template[count.index], "name", count.index)}-eks_asg", "propagate_at_launch", true),
      map("key", "kubernetes.io/cluster/${aws_eks_cluster.this.name}", "value", "owned", "propagate_at_launch", true),
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
