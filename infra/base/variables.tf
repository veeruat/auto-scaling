variable "prefix" {
  type = string
}

variable "region" {
  default = "eu-west-1"
}

variable "vpc_cidr" {
  default = "10.5.0.0/16"
}

variable "pubsubnet_a_cidr" {
  default = "10.5.0.0/24"
}
variable "pubsubnet_b_cidr" {
  default = "10.5.1.0/24"
}
variable "pubsubnet_c_cidr" {
  default = "10.5.2.0/24"
}