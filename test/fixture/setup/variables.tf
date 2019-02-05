terraform {
  required_version = ">= 0.11.11"
}

provider "aws" {
  version = "~> 1.57"
  region  = "${var.vpc_region}"
}

variable "vpc_region" {}

variable "cluster_name" {}
variable "vpc_name" {}

variable "vpc_cidr_reservation_start" {}

variable "vpc_azs" {
  type = "list"
}

variable "vpc_enable_nat_gateway" {}
