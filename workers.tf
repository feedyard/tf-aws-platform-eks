# platform eks-worker nodes

resource "aws_security_group" "workers" {
  description = "Security group for all nodes in the cluster."
  count       = "${var.worker_create_security_group ? 1 : 0}"

  name_prefix = "${var.cluster_name}"
  vpc_id      = "${var.cluster_vpc_id}"
  tags        = "${merge(var.tags, map("Name", "${var.cluster_name}_eks_worker_sg", "kubernetes.io/cluster/${var.cluster_name}", "shared"))}"
}

resource "aws_security_group_rule" "workers_egress_internet" {
  description       = "Allow nodes all egress to the Internet."
  count             = "${var.worker_create_security_group ? 1 : 0}"

  protocol          = "-1"
  security_group_id = "${aws_security_group.workers.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "workers_ingress_self" {
  description              = "Allow node to communicate with each other."
  count                    = "${var.worker_create_security_group ? 1 : 0}"

  protocol                 = "-1"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_cluster" {
  description              = "Allow workers Kubelets and pods to receive communication from the cluster control plane."
  count                    = "${var.worker_create_security_group ? 1 : 0}"

  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = "${var.worker_sg_ingress_from_port}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_cluster_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane."
  count                    = "${var.worker_create_security_group ? 1 : 0}"

  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}