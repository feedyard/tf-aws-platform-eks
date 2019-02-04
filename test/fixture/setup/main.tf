module "vpc" {
  source = "github.com/feedyard/tf-aws-platform-vpc?ref=2.0.2"

  name                   = "${var.vpc_name}"
  cluster_name           = "${var.cluster_name}"
  cidr_reservation_start = "${var.vpc_cidr_reservation_start}"
  azs                    = "${var.vpc_azs}"

  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
  enable_nat_gateway   = "${var.vpc_enable_nat_gateway}"

  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "feedyard/tf-aws-cluster-eks"
  }
}
