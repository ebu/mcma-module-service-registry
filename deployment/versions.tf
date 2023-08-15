terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.22.0"
    }
    mcma = {
      source  = "ebu/mcma"
      version = ">= 0.0.26"
    }
  }
  required_version = ">= 1.0"
}
