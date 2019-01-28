variable "cluster_region" {}

variable "cluster_name" {}
variable "cluster_vpc_name" {}

variable "cluster_cidr_reservation_start" {}

variable "cluster_azs" {
  type = "list"
}

variable "cluster_enable_nat_gateway" {}

# Additional AWS account numbers to add to the aws-auth configmap
variable "map_accounts" {
  type    = "list"
  default = []
}

# The count of accounts in the map_accounts list
variable "map_accounts_count" {
  type    = "string"
  default = "0"
}

# Additional IAM roles to add to the aws-auth configmap
variable "map_roles" {
  type    = "list"
  default = []
}

# The count of roles in the map_roles list
variable "map_roles_count" {
  type    = "string"
  default = "0"
}

# Additional IAM users to add to the aws-auth configmap
variable "map_users" {
  type    = "list"
  default = []
}

# The count of roles in the map_users list
variable "map_users_count" {
  type    = "string"
  default = "0"
}
