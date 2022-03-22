
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.76.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# https://www.terraform.io/docs/providers/terraform/d/remote_state.html
data "terraform_remote_state" "globals" {
  # FIXME: Change local Terraform state to remote state backend
  backend = "local"

  config = {
    path = "${path.module}/../00-globals/terraform.tfstate"
  }
}

locals {
  basename                            = data.terraform_remote_state.globals.outputs.basename
  resource-group-name                 = data.terraform_remote_state.globals.outputs.resource-group-name
  persistent-resource-group-name      = data.terraform_remote_state.globals.outputs.persistent-resource-group-name
  centro-de-costos                    = data.terraform_remote_state.globals.outputs.centro-de-costos
  deployment-environment              = data.terraform_remote_state.globals.outputs.deployment-environment
  ssh-public-key                      = data.terraform_remote_state.globals.outputs.ssh-public-key
  virtual-network-subnets-cidrs       = data.terraform_remote_state.globals.outputs.virtual-network-subnets-cidrs
  virtual-network-main-address-space  = data.terraform_remote_state.globals.outputs.virtual-network-main-address-space
  virtual-network-resource-group-name = local.persistent-resource-group-name
}

module "networking" {
  source = "git::https://SuraColombia@dev.azure.com/SuraColombia/Gerencia_Tecnologia/_git/ti-lego-iac-azurerm-networking-lb?ref=v1.0"

  resource-group-name           = local.virtual-network-resource-group-name
  basename                      = local.basename
  #dns-servers                   = ["10.41.18.40"]
  #enable-azure-internal-dns     = false
  enable-azure-internal-dns     = true
  virtual-network-address-space = [local.virtual-network-main-address-space]
  virtual-network-subnets-cidrs = local.virtual-network-subnets-cidrs
  centro-de-costos              = local.centro-de-costos
  extra-tags               = {
    deployment-environment = local.deployment-environment
  }
}

output "main-virtual-network-resource-group-name" {
  value = local.virtual-network-resource-group-name
}

output "main-virtual-network-name" {
  value = module.networking.main-virtual-network-name
}

output "main-virtual-network-id" {
  value = module.networking.main-virtual-network-id
}

