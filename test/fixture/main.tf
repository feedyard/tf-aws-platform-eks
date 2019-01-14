module "cluster" {
  source = "../../"

  cluster_name = "${var.cluster_name}"
  cluster_vpc_id = "${var.cluster_vpc_id}"
  cluster_create_security_group = "${var.cluster_create_security_group}"
  worker_create_security_group = "${var.worker_create_security_group}"

  tags {
    "test" = "terraform module continuous integration testing"
    "pipeline" = "feedyard/tf-aws-platform-eks"
  }
}
