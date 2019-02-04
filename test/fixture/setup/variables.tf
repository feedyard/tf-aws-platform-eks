terraform {
  required_version = ">= 0.11.11"
}

provider "aws" {
  version = "~> 1.57"
  region  = "${var.vpc_region}"
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

variable "vpc_region" {}

variable "cluster_name" {}
variable "vpc_name" {}

variable "vpc_cidr_reservation_start" {}

variable "vpc_azs" {
  type = "list"
}

variable "vpc_enable_nat_gateway" {}
