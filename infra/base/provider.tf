# Setup our aws provider

provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "s3" {
    region = "eu-west-1"
    key    = "base/terraform.tfstate"
  }
}
