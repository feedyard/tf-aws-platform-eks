terraform {
  required_version = ">= 0.11.11"
}

provider "aws" {
  version = "~> 1.57"
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
  source = "github.com/feedyard/tf-aws-platform-vpc?ref=2.0.1"

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

data "aws_vpc" "ci_vpc" {
  tags = {
    Cluster = "${var.cluster_name}"
  }
}

data "aws_subnet_ids" "cluster_internal" {
  vpc_id = "${data.aws_vpc.ci_vpc.id}"

  tags = {
    Tier = "Internal"
  }
}

module "eks" {
  source = "../.."

  cluster_name       = "${var.cluster_name}"
  cluster_subnet_ids = ["${data.aws_subnet_ids.cluster_internal.ids}"]
  cluster_vpc_id     = "${data.aws_vpc.ci_vpc.id}"

  tags {
    "test"     = "terraform module continuous integration testing"
    "pipeline" = "feedyard/tf-aws-cluster-eks"
  }
}
