
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
  agw-public-ip-name             = data.terraform_remote_state.globals.outputs.agw-public-ip-name
  aks-outbound-public-ip-name    = data.terraform_remote_state.globals.outputs.aks-outbound-public-ip-name
}

data "azurerm_resource_group" "persistent-resource-group" {
  name = local.persistent-resource-group-name
}

# Application Gateway Public IP
resource "azurerm_public_ip" "agw-public-ip" {
  name                = local.agw-public-ip-name
  resource_group_name = data.azurerm_resource_group.persistent-resource-group.name
  location            = data.azurerm_resource_group.persistent-resource-group.location
  sku                 = "Standard"
  allocation_method   = "Static"

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

# AKS Load Balancer Outbound Public IP
resource "azurerm_public_ip" "aks-outbound-public-ip" {
  name                = local.aks-outbound-public-ip-name
  resource_group_name = data.azurerm_resource_group.persistent-resource-group.name
  location            = data.azurerm_resource_group.persistent-resource-group.location
  sku                 = "Standard"
  allocation_method   = "Static"

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

output "agw-public-name" {
  value = azurerm_public_ip.agw-public-ip.name
}

output "agw-public-ip" {
  value = azurerm_public_ip.agw-public-ip.ip_address
}

output "agw-public-ip-id" {
  value = azurerm_public_ip.agw-public-ip.id
}

output "aks-outbound-public-name" {
  value = azurerm_public_ip.aks-outbound-public-ip.name
}

output "aks-outbound-public-ip" {
  value = azurerm_public_ip.aks-outbound-public-ip.ip_address
}

output "aks-outbound-public-ip-id" {
  value = azurerm_public_ip.aks-outbound-public-ip.id
}

