terraform {
  required_version = ">= 0.11.11"
}

provider "aws" {
  version = "~> 1.56"
  region  = "${var.cluster_region}"
}

provider "random" {
  version = "~> 2.0"
}

provider "local" {
  version = "~> 1.1"
}

provider "null" {
  version = "~> 2.0"
}

provider "template" {
  version = "~> 2.0"
}

module "vpc" {
  source = "github.com/feedyard/tf-aws-platform-vpc?ref=1.0.0"

  name                   = "${var.cluster_vpc_name}"
  cluster_name           = "${var.cluster_name}"
  cidr_reservation_start = "${var.cluster_cidr_reservation_start}"
  azs                    = "${var.cluster_azs}"

  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
  enable_nat_gateway   = "${var.cluster_enable_nat_gateway}"

  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "grainger-di-tf-aws-cluster-eks"
  }
}

module "eks" {
  source = "../.."

  #source = "github.com/terraform-aws-modules/terraform-aws-eks"

  cluster_name       = "${var.cluster_name}"
  cluster_subnet_ids = ["${module.vpc.nat_subnet_ids}"]
  cluster_vpc_id     = "${module.vpc.vpc_id}"
  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "grainger-di-tf-aws-cluster-eks"
  }
}
