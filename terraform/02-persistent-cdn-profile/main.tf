
provider "azurerm" {
  version = ">= 2.39"
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
  basename                       = data.terraform_remote_state.globals.outputs.basename
  resource-group-name            = data.terraform_remote_state.globals.outputs.resource-group-name
  persistent-resource-group-name = data.terraform_remote_state.globals.outputs.persistent-resource-group-name
  centro-de-costos               = data.terraform_remote_state.globals.outputs.centro-de-costos
  deployment-environment         = data.terraform_remote_state.globals.outputs.deployment-environment
  cdn-profile-name               = data.terraform_remote_state.globals.outputs.cdn-profile-name
}


data "azurerm_resource_group" "persistent-resource-group" {
  name = local.persistent-resource-group-name
}

resource "azurerm_cdn_profile" "main" {
  name                = local.cdn-profile-name
  location            = data.azurerm_resource_group.persistent-resource-group.location
  resource_group_name = local.persistent-resource-group-name
  sku                 = "Standard_Microsoft"

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

output "cdn-profile-name" {
  value = azurerm_cdn_profile.main.name
}

