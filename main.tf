# feedyard/tf-aws-platforom-eks module
# adapted from https://github.com/terraform-aws-modules/terraform-aws-eks

resource "aws_eks_cluster" "mod" {
  name     = "${var.cluster_name}"
  role_arn = "${aws_iam_role.cluster.arn}"
  version  = "${var.cluster_version}"

  vpc_config {
    security_group_ids = ["${local.cluster_security_group_id}"]
    subnet_ids         = ["${var.cluster_vpc_subnet_ids}"]
  }

  timeouts {
    create = "${var.cluster_create_timeout}"
    delete = "${var.cluster_delete_timeout}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy",
  ]

  tags = "${merge(var.tags, map("Name", format("%s", var.cluster_name)), map(format("kubernetes.io/cluster/%s",var.cluster_name),"shared"))}"
}

resource "aws_security_group" "cluster" {
  description = "EKS cluster security group."
  count       = "${var.cluster_create_security_group ? 1 : 0}"

  name_prefix = "${var.cluster_name}"
  vpc_id      = "${var.cluster_vpc_id}"
  tags        = "${merge(var.tags, map("Name", "${var.cluster_name}-eks-cluster-sg"))}"
}

resource "aws_security_group_rule" "cluster_egress_internet" {
  description = "Allow cluster egress access to the Internet."
  count       = "${var.cluster_create_security_group ? 1 : 0}"

  protocol          = "-1"
  security_group_id = "${aws_security_group.cluster.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "cluster_https_worker_ingress" {
  description = "Allow pods to communicate with the EKS cluster API."
  count       = "${var.cluster_create_security_group ? 1 : 0}"

  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cluster.id}"
  source_security_group_id = "${local.worker_security_group_id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_iam_role" "cluster" {
  name_prefix           = "${var.cluster_name}"
  assume_role_policy    = "${data.aws_iam_policy_document.cluster_assume_role_policy.json}"
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.cluster.name}"
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.cluster.name}"
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

locals {
  # Followed recommendation http://67bricks.com/blog/?p=85
  # to workaround terraform not supporting short circut evaluation
  cluster_security_group_id = "${coalesce(join("", aws_security_group.cluster.*.id), var.cluster_security_group_id)}"
}
