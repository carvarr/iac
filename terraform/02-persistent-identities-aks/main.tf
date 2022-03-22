
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

  uai-agw-name                   = data.terraform_remote_state.globals.outputs.uai-agw-name
  uai-aks-name                   = data.terraform_remote_state.globals.outputs.uai-aks-name
  uai-aks-kubelet-name           = data.terraform_remote_state.globals.outputs.uai-aks-kubelet-name
  uai-aks-agic-name              = data.terraform_remote_state.globals.outputs.uai-aks-agic-name
  uai-aks-keyvault-name          = data.terraform_remote_state.globals.outputs.uai-aks-keyvault-name
}

data "azurerm_resource_group" "persistent-resource-group" {
  name = local.persistent-resource-group-name
}

# Application Gateway user-assigned managed identity
resource "azurerm_user_assigned_identity" "uai-agw" {
  name                = local.uai-agw-name
  resource_group_name = data.azurerm_resource_group.persistent-resource-group.name
  location            = data.azurerm_resource_group.persistent-resource-group.location

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

# AKS user-assigned managed identity
resource "azurerm_user_assigned_identity" "uai-aks" {
  name                = local.uai-aks-name
  resource_group_name = data.azurerm_resource_group.persistent-resource-group.name
  location            = data.azurerm_resource_group.persistent-resource-group.location

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

# AKS Kubelet user-assigned managed identity
resource "azurerm_user_assigned_identity" "uai-aks-kubelet" {
  name                = local.uai-aks-kubelet-name
  resource_group_name = data.azurerm_resource_group.persistent-resource-group.name
  location            = data.azurerm_resource_group.persistent-resource-group.location

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

# AKS AGIC user-assigned managed identity
resource "azurerm_user_assigned_identity" "uai-aks-agic" {
  name                = local.uai-aks-agic-name
  resource_group_name = data.azurerm_resource_group.persistent-resource-group.name
  location            = data.azurerm_resource_group.persistent-resource-group.location

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

# AKS AGIC user-assigned managed identity
resource "azurerm_user_assigned_identity" "uai-aks-keyvault" {
  name                = local.uai-aks-keyvault-name
  resource_group_name = data.azurerm_resource_group.persistent-resource-group.name
  location            = data.azurerm_resource_group.persistent-resource-group.location

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

output "uai-agw-name" {
  value = azurerm_user_assigned_identity.uai-agw.name
}

output "uai-agw-id" {
  value = azurerm_user_assigned_identity.uai-agw.id
}

output "uai-agw-client-id" {
  value = azurerm_user_assigned_identity.uai-agw.client_id
}

output "uai-agw-principal-id" {
  value = azurerm_user_assigned_identity.uai-agw.principal_id
}

output "uai-aks-name" {
  value = azurerm_user_assigned_identity.uai-aks.name
}

output "uai-aks-id" {
  value = azurerm_user_assigned_identity.uai-aks.id
}

output "uai-aks-client-id" {
  value = azurerm_user_assigned_identity.uai-aks.client_id
}

output "uai-aks-principal-id" {
  value = azurerm_user_assigned_identity.uai-aks.principal_id
}

output "uai-aks-agic-name" {
  value = azurerm_user_assigned_identity.uai-aks-agic.name
}

output "uai-aks-agic-id" {
  value = azurerm_user_assigned_identity.uai-aks-agic.id
}

output "uai-aks-agic-client-id" {
  value = azurerm_user_assigned_identity.uai-aks-agic.client_id
}

output "uai-aks-agic-principal-id" {
  value = azurerm_user_assigned_identity.uai-aks-agic.principal_id
}

output "uai-aks-keyvault-name" {
  value = azurerm_user_assigned_identity.uai-aks-keyvault.name
}

output "uai-aks-keyvault-id" {
  value = azurerm_user_assigned_identity.uai-aks-keyvault.id
}

output "uai-aks-keyvault-client-id" {
  value = azurerm_user_assigned_identity.uai-aks-keyvault.client_id
}

output "uai-aks-keyvault-principal-id" {
  value = azurerm_user_assigned_identity.uai-aks-keyvault.principal_id
}

