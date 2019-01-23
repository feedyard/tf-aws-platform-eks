resource "aws_eks_cluster" "mod" {
  name     = "${var.cluster_name}"
  role_arn = "${aws_iam_role.cluster.arn}"
  version  = "${var.cluster_version}"

  vpc_config {
    security_group_ids = ["${local.cluster_security_group_id}"]
    subnet_ids         = ["${var.cluster_subnet_ids}"]
  }

  timeouts {
    create = "${var.cluster_create_timeout}"
    delete = "${var.cluster_delete_timeout}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy",
  ]
}

resource "aws_security_group" "cluster" {
  #name_prefix = "${var.cluster_name}"
  name        = "${var.cluster_name}-eks-cluster-sg"
  description = "EKS cluster security group."
  vpc_id      = "${var.cluster_vpc_id}"
  tags        = "${merge(var.tags, map("Name", "${var.cluster_name}-eks-cluster-sg"))}"
  count       = "${var.cluster_create_security_group ? 1 : 0}"
}

resource "aws_security_group_rule" "cluster_egress_internet" {
  description       = "Allow cluster egress access to the Internet."
  protocol          = "-1"
  security_group_id = "${aws_security_group.cluster.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
  count             = "${var.cluster_create_security_group ? 1 : 0}"
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

resource "aws_iam_role" "cluster" {
  #name_prefix           = "${var.cluster_name}"
  name                  = "${var.cluster_name}-cluster-iam-role"
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

resource "local_file" "kubeconfig" {
  content  = "${data.template_file.kubeconfig.rendered}"
  filename = "${var.config_output_path}kubeconfig_${var.cluster_name}"
  count    = "${var.write_kubeconfig ? 1 : 0}"
}

resource "local_file" "config_map_aws_auth" {
  content  = "${data.template_file.config_map_aws_auth.rendered}"
  filename = "${var.config_output_path}config-map-aws-auth_${var.cluster_name}.yaml"
  count    = "${var.manage_aws_auth ? 1 : 0}"
}

resource "null_resource" "update_config_map_aws_auth" {
  depends_on = ["aws_eks_cluster.mod"]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-map-aws-auth_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig_${var.cluster_name} && exit 0 || sleep 10; done; exit 1"
    interpreter = ["${var.local_exec_interpreter}"]
  }

  triggers {
    config_map_rendered = "${data.template_file.config_map_aws_auth.rendered}"
    endpoint            = "${aws_eks_cluster.mod.endpoint}"
  }

  count = "${var.manage_aws_auth ? 1 : 0}"
}

data "aws_caller_identity" "current" {}

data "template_file" "launch_template_worker_role_arns" {
  count    = "${var.worker_group_launch_template_count}"
  template = "${file("${path.module}/templates/worker-role.tpl")}"

  vars {
    worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${element(aws_iam_instance_profile.workers_launch_template.*.role, count.index)}"
  }
}

data "template_file" "worker_role_arns" {
  count    = "${var.worker_group_count}"
  template = "${file("${path.module}/templates/worker-role.tpl")}"

  vars {
    worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${element(aws_iam_instance_profile.workers.*.role, count.index)}"
  }
}

data "template_file" "config_map_aws_auth" {
  template = "${file("${path.module}/templates/config-map-aws-auth.yaml.tpl")}"

  vars {
    worker_role_arn = "${join("", distinct(concat(data.template_file.launch_template_worker_role_arns.*.rendered, data.template_file.worker_role_arns.*.rendered)))}"
    map_users       = "${join("", data.template_file.map_users.*.rendered)}"
    map_roles       = "${join("", data.template_file.map_roles.*.rendered)}"
    map_accounts    = "${join("", data.template_file.map_accounts.*.rendered)}"
  }
}

data "template_file" "map_users" {
  count    = "${var.map_users_count}"
  template = "${file("${path.module}/templates/config-map-aws-auth-map_users.yaml.tpl")}"

  vars {
    user_arn = "${lookup(var.map_users[count.index], "user_arn")}"
    username = "${lookup(var.map_users[count.index], "username")}"
    group    = "${lookup(var.map_users[count.index], "group")}"
  }
}

data "template_file" "map_roles" {
  count    = "${var.map_roles_count}"
  template = "${file("${path.module}/templates/config-map-aws-auth-map_roles.yaml.tpl")}"

  vars {
    role_arn = "${lookup(var.map_roles[count.index], "role_arn")}"
    username = "${lookup(var.map_roles[count.index], "username")}"
    group    = "${lookup(var.map_roles[count.index], "group")}"
  }
}

data "template_file" "map_accounts" {
  count    = "${var.map_accounts_count}"
  template = "${file("${path.module}/templates/config-map-aws-auth-map_accounts.yaml.tpl")}"

  vars {
    account_number = "${element(var.map_accounts, count.index)}"
  }
}
