terraform {
  required_version = ">= 0.11.11"

  backend "s3" {}
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

variable "cluster_name" {}
variable "cluster_region" {}
