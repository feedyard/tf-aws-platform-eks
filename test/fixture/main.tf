module "vpc" {
  source = "github.com/feedyard/tf-aws-platform-vpc?ref=2.0.2"

  name                   = "${var.cluster_vpc_name}"
  cluster_name           = "${var.cluster_name}"
  cidr_reservation_start = "${var.cluster_cidr_reservation_start}"
  azs                    = "${var.cluster_azs}"

  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
  enable_nat_gateway   = "${var.cluster_enable_nat_gateway}"

  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "feedyard/tf-aws-cluster-eks"
  }
}

module "eks" {
  source = "../.."

  #cluster_name = "${var.cluster_name}"
  cluster_name = "${module.vpc.cluster_name}"

  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "feedyard/tf-aws-cluster-eks"
  }
}
