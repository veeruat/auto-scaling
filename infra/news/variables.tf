variable "instance_type" {
  default = "t3.nano"
}
variable "docker_image_tag" {
  default = "latest"
}
variable "prefix" {
  type = string
}
# --- placed here from provider.tf
variable "region" {
  default = "eu-west-1"
}

variable "ssh_cidr" {
  default = ["0.0.0.0/0"]

}

variable "frontend_service_port" {
  default = "8080"
}

variable "newsfeed_service_port" {
  default = "8081"
}

variable "quotes_service_port" {
  default = "8082"

}

variable "source_ip" {
  default = "49.204.0.78/32"
}
