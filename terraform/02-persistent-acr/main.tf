
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
  resource-group-name            = data.terraform_remote_state.globals.outputs.resource-group-name
  persistent-resource-group-name = data.terraform_remote_state.globals.outputs.persistent-resource-group-name
  centro-de-costos               = data.terraform_remote_state.globals.outputs.centro-de-costos
  deployment-environment         = data.terraform_remote_state.globals.outputs.deployment-environment
  acr-name                       = data.terraform_remote_state.globals.outputs.acr-name
}

data "azurerm_resource_group" "persistent-resource-group" {
  name = local.persistent-resource-group-name
}

#
# Container Registry
#
resource "azurerm_container_registry" "acr-registry" {
  name                     = local.acr-name
  resource_group_name      = data.azurerm_resource_group.persistent-resource-group.name
  location                 = data.azurerm_resource_group.persistent-resource-group.location
  sku                      = "Basic"
  admin_enabled            = true
  
  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

output "acr-name" {
  value = azurerm_container_registry.acr-registry.name
}

output "acr-id" {
  value = azurerm_container_registry.acr-registry.id
}

