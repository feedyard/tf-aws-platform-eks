module "eks" {
  source = "../.."

  cluster_name = "${var.cluster_name}"

  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "feedyard/tf-aws-cluster-eks"
  }
}
