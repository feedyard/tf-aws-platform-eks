terraform {
  required_version = ">= 0.11.11"
}

provider "aws" {
  version = "~> 1.55"
  region = "${var.cluster_aws_region}"
}

variable "cluster_name" {}
variable "cluster_aws_region" { default = "us-east-1" }

variable "cluster_vpc_id" {}
variable "cluster_create_security_group" {}
variable "worker_create_security_group" {}
