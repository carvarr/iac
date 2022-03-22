
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.94.0"
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

# https://www.terraform.io/docs/providers/terraform/d/remote_state.html
data "terraform_remote_state" "networking" {
  # FIXME: Change local Terraform state to remote state backend
  backend = "local"

  config = {
    path = "${path.module}/../03-persistent-networking/terraform.tfstate"
  }
}

locals {
  # Globals
  basename                                 = data.terraform_remote_state.globals.outputs.basename
  resource-group-name                      = data.terraform_remote_state.globals.outputs.resource-group-name
  persistent-resource-group-name           = data.terraform_remote_state.globals.outputs.persistent-resource-group-name
  centro-de-costos                         = data.terraform_remote_state.globals.outputs.centro-de-costos
  deployment-environment                   = data.terraform_remote_state.globals.outputs.deployment-environment
  agw-public-ip-name                       = data.terraform_remote_state.globals.outputs.agw-public-ip-name
  aks-outbound-public-ip-name              = data.terraform_remote_state.globals.outputs.aks-outbound-public-ip-name
  uai-agw-name                             = data.terraform_remote_state.globals.outputs.uai-agw-name
  uai-aks-name                             = data.terraform_remote_state.globals.outputs.uai-aks-name
  uai-aks-kubelet-name                     = data.terraform_remote_state.globals.outputs.uai-aks-kubelet-name
  acr-name                                 = data.terraform_remote_state.globals.outputs.acr-name
  ssh-public-key                           = data.terraform_remote_state.globals.outputs.ssh-public-key
  virtual-network-subnets-cidrs            = data.terraform_remote_state.globals.outputs.virtual-network-subnets-cidrs
  virtual-network-main-address-space       = data.terraform_remote_state.globals.outputs.virtual-network-main-address-space

  # Networking
  main-virtual-network-resource-group-name = data.terraform_remote_state.networking.outputs.main-virtual-network-resource-group-name
  main-virtual-network-name                = data.terraform_remote_state.networking.outputs.main-virtual-network-name
  main-virtual-network-id                  = data.terraform_remote_state.networking.outputs.main-virtual-network-id
}

module "agw" {
  source = "git::https://SuraColombia@dev.azure.com/SuraColombia/Gerencia_Tecnologia/_git/ti-lego-iac-azurerm-agw-lb?ref=v1.1"

  resource-group-name                 = local.resource-group-name
  basename                            = local.basename
  virtual-network-resource-group-name = local.main-virtual-network-resource-group-name
  virtual-network-name                = local.main-virtual-network-name
  virtual-network-subnets-cidrs       = local.virtual-network-subnets-cidrs
  subnet-cidr                         = local.virtual-network-subnets-cidrs["agw"]
  centro-de-costos                    = local.centro-de-costos
  public-ip-id                        = data.azurerm_public_ip.agw-public-ip.id
  uai-agw-id                          = data.azurerm_user_assigned_identity.uai-agw.id
  uai-agw-client-id                   = data.azurerm_user_assigned_identity.uai-agw.client_id
  uai-agw-principal-id                = data.azurerm_user_assigned_identity.uai-agw.principal_id
  private-is-main                     = true

  extra-tags                          = {
    deployment-environment = local.deployment-environment
  }
}

module "aks" {
  source = "git::https://SuraColombia@dev.azure.com/SuraColombia/Gerencia_Tecnologia/_git/ti-lego-iac-azurerm-aks-lb?ref=v1.3"

  resource-group-name                 = local.resource-group-name
  cluster-name                        = local.basename
  virtual-network-resource-group-name = local.main-virtual-network-resource-group-name
  virtual-network-id                  = local.main-virtual-network-id
  virtual-network-name                = local.main-virtual-network-name
  virtual-network-subnets-cidrs       = local.virtual-network-subnets-cidrs
  cluster-subnet-cidr                 = local.virtual-network-subnets-cidrs["aks"]
  cluster-subnet-service-endpoints    = ["Microsoft.Sql", "Microsoft.Storage", "Microsoft.KeyVault"]
  private-cluster-enabled             = false
  attach-acr-ids                      = [data.azurerm_container_registry.acr-registry.id]
  agent-pool-max-pods                 = 15
  ssh-public-key                      = local.ssh-public-key
  centro-de-costos                    = local.centro-de-costos
  api-server-authorized-ip-ranges     = ["200.1.173.0/24", "${chomp(data.http.deployer-public-ip.body)}/32"]
  availability-zones                  = ["1", "2", "3"]
  outbound-ip-address-ids             = [ data.azurerm_public_ip.aks-outbound-public-ip.id ]

  uai-aks-id                          = data.azurerm_user_assigned_identity.uai-aks.id
  uai-aks-principal-id                = data.azurerm_user_assigned_identity.uai-aks.principal_id
  uai-aks-client-id                   = data.azurerm_user_assigned_identity.uai-aks.client_id
  uai-aks-kubelet-id                  = data.azurerm_user_assigned_identity.uai-aks-kubelet.id
  uai-aks-kubelet-client-id           = data.azurerm_user_assigned_identity.uai-aks-kubelet.client_id
  uai-aks-kubelet-principal-id        = data.azurerm_user_assigned_identity.uai-aks-kubelet.principal_id

  extra-tags                          = {
    deployment-environment = local.deployment-environment
  }
}

# Application Gateway Public IP
data "azurerm_public_ip" "agw-public-ip" {
  name                = local.agw-public-ip-name
  resource_group_name = local.persistent-resource-group-name
}

# AKS Load Balancer Outbound Public IP
data "azurerm_public_ip" "aks-outbound-public-ip" {
  name                = local.aks-outbound-public-ip-name
  resource_group_name = local.persistent-resource-group-name
}

# Application Gateway user-assigned managed identity
data "azurerm_user_assigned_identity" "uai-agw" {
  name                = local.uai-agw-name
  resource_group_name = local.persistent-resource-group-name
}

# AKS user-assigned managed identity
data "azurerm_user_assigned_identity" "uai-aks" {
  name                = local.uai-aks-name
  resource_group_name = local.persistent-resource-group-name
}

# AKS Kubelet user-assigned managed identity
data "azurerm_user_assigned_identity" "uai-aks-kubelet" {
  name                = local.uai-aks-kubelet-name
  resource_group_name = local.persistent-resource-group-name
}

#
# Container Registry
#
data "azurerm_container_registry" "acr-registry" {
  name                = local.acr-name
  resource_group_name = local.persistent-resource-group-name
}

#
# Deployer current plublic IP
#
data "http" "deployer-public-ip" {
  url = "https://ipv4.icanhazip.com"
}

output "kubernetes-provider-arguments" {
  value     = module.aks.kubernetes-provider-arguments
  sensitive = true
}

output "services-cidr" {
  value = module.aks.services-cidr
}

output "cluster-name" {
  value = module.aks.cluster-name
}

output "cluster-fqdn" {
  value = module.aks.cluster-fqdn
}

output "kubelet-identity-object-id" {
  value = module.aks.kubelet-identity-object-id
}

output "kubelet-identity-uai-id" {
  value = module.aks.kubelet-identity-uai-id
}

output "kubelet-identity-client-id" {
  value = module.aks.kubelet-identity-client-id
}

output "omsagent-identity-principal-id" {
  value = module.aks.omsagent-identity-principal-id
}

output "omsagent-identity-uai-id" {
  value = module.aks.omsagent-identity-uai-id
}

output "omsagent-identity-client-id" {
  value = module.aks.omsagent-identity-client-id
}

output "agw-name" {
  value = module.agw.agw-name
}

output "agw-id" {
  value = module.agw.agw-id
}

output "agw-uai-id" {
  value = module.agw.uai-agw-id
}

output "agw-uai-client-id" {
  value = module.agw.uai-agw-client-id
}

output "agw-uai-principal-id" {
  value = module.agw.uai-agw-principal-id
}
