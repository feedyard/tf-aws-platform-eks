module "eks" {
  source = "../.."

  cluster_name   = "${var.cluster_name}"
  cluster_region = "${var.cluster_region}"

  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "feedyard/tf-aws-cluster-eks"
  }
}
