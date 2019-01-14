# feedyard/tf-aws-platforom-eks module
locals {

  # Followed recommendation http://67bricks.com/blog/?p=85
  # to workaround terraform not supporting short circut evaluation
  cluster_security_group_id = "${coalesce(join("", aws_security_group.cluster.*.id), var.cluster_security_group_id)}"
  worker_security_group_id = "${coalesce(join("", aws_security_group.workers.*.id), var.worker_security_group_id)}"
}




# ----------------------------------------------------------------------- Cluster Security Group
resource "aws_security_group" "cluster" {
  description = "EKS cluster security group."
  count       = "${var.cluster_create_security_group ? 1 : 0}"

  name_prefix = "${var.cluster_name}"
  vpc_id      = "${var.cluster_vpc_id}"
  tags        = "${merge(var.tags, map("Name", "${var.cluster_name}_eks_cluster_sg"))}"
}

resource "aws_security_group_rule" "cluster_egress_internet" {
  description       = "Allow cluster egress access to the Internet."
  count             = "${var.cluster_create_security_group ? 1 : 0}"

  protocol          = "-1"
  security_group_id = "${aws_security_group.cluster.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "cluster_https_worker_ingress" {
  description              = "Allow pods to communicate with the EKS cluster API."
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cluster.id}"
  source_security_group_id = "${local.worker_security_group_id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
  count                    = "${var.cluster_create_security_group ? 1 : 0}"
}