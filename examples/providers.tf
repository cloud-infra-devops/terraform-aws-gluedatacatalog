# https://releases.hashicorp.com/terraform-provider-aws/
terraform {
  cloud {
    organization = "dukeenergy-corp"
    workspaces {
      name    = "infra-dev-aim-automation-poc"
      project = "aim-automation-poc"
    }
  }
  required_version = ">= 1.5, < 2.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # version = "> 4.0.0"
      version = "6.28.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

