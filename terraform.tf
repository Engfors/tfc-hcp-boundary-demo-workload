terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      version = "~> 4.35.0"
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.1.9"
    }
  }
}



data "terraform_remote_state" "boundary" {
  backend = "remote"

  config = {
    organization = var.tfc_state_org
    workspaces = {
      name = var.tfc_state_ws
    }
  }
}