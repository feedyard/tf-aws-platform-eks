variable "cluster_region" {}

variable "cluster_name" {}
variable "cluster_vpc_name" {}

variable "cluster_cidr_reservation_start" {}

variable "cluster_azs" {
  type = "list"
}

variable "cluster_enable_nat_gateway" {}
