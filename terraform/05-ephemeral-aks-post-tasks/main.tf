
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.94.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.7.1"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = local.kubernetes-provider-arguments.host
  username               = local.kubernetes-provider-arguments.username
  password               = local.kubernetes-provider-arguments.password
  client_certificate     = local.kubernetes-provider-arguments.client-certificate
  client_key             = local.kubernetes-provider-arguments.client-key
  cluster_ca_certificate = local.kubernetes-provider-arguments.cluster-ca-certificate
  insecure               = local.kubernetes-provider-arguments.insecure
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

# https://www.terraform.io/docs/providers/terraform/d/remote_state.html
data "terraform_remote_state" "aks" {
  # FIXME: Change local Terraform state to remote state backend
  backend = "local"

  config = {
    path = "${path.module}/../04-ephemeral-aks/terraform.tfstate"
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
  uai-aks-agic-name                        = data.terraform_remote_state.globals.outputs.uai-aks-agic-name
  uai-aks-keyvault-name                    = data.terraform_remote_state.globals.outputs.uai-aks-keyvault-name
  acr-name                                 = data.terraform_remote_state.globals.outputs.acr-name
  ssh-public-key                           = data.terraform_remote_state.globals.outputs.ssh-public-key
  virtual-network-subnets-cidrs            = data.terraform_remote_state.globals.outputs.virtual-network-subnets-cidrs
  virtual-network-main-address-space       = data.terraform_remote_state.globals.outputs.virtual-network-main-address-space

  # Networking
  main-virtual-network-resource-group-name = data.terraform_remote_state.networking.outputs.main-virtual-network-resource-group-name
  main-virtual-network-name                = data.terraform_remote_state.networking.outputs.main-virtual-network-name
  main-virtual-network-id                  = data.terraform_remote_state.networking.outputs.main-virtual-network-id

  # AKS Cluster
  cluster-fqdn                  = data.terraform_remote_state.aks.outputs.cluster-fqdn
  cluster-name                  = data.terraform_remote_state.aks.outputs.cluster-name
  kubernetes-provider-arguments = data.terraform_remote_state.aks.outputs.kubernetes-provider-arguments
  services-cidr                 = data.terraform_remote_state.aks.outputs.services-cidr
  agw-name                      = data.terraform_remote_state.aks.outputs.agw-name
  agw-id                        = data.terraform_remote_state.aks.outputs.agw-id
}

module "post-tasks" {
  source = "git::https://SuraColombia@dev.azure.com/SuraColombia/Gerencia_Tecnologia/_git/ti-lego-iac-azurerm-aks-post-tasks-lb?ref=v1.0"

  cluster-name                             = local.cluster-name
  cluster-fqdn                             = local.cluster-fqdn
  resource-group-name                      = local.resource-group-name
  non-masquerade-cidrs                     = distinct(compact(concat([local.virtual-network-main-address-space], values(local.virtual-network-subnets-cidrs), [local.services-cidr], ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"])))
  kubelet-identity-object-id               = data.azurerm_user_assigned_identity.uai-aks-kubelet.principal_id
  kubelet-identity-uai-id                  = data.azurerm_user_assigned_identity.uai-aks-kubelet.id
  kubelet-identity-client-id               = data.azurerm_user_assigned_identity.uai-aks-kubelet.client_id
  enable-keyvault-secrets-store-csi-driver = false
  centro-de-costos                         = local.centro-de-costos
  multi-agic-config                        = {
    main = {
      agw-name           = local.agw-name
      agw-id             = local.agw-id
      agw-uai-id         = data.azurerm_user_assigned_identity.uai-agw.id
      uai-id             = data.azurerm_user_assigned_identity.uai-aks-agic.id
      uai-principal-id   = data.azurerm_user_assigned_identity.uai-aks-agic.principal_id
      uai-client-id      = data.azurerm_user_assigned_identity.uai-aks-agic.client_id
      helm-chart-version = "1.5.0"
      use-private-ip     = true
      ingress-class      = "azure/application-gateway"
    }
  }

  extra-tags = {
    deployment-environment = local.deployment-environment
  }
}

# Application Gateway user-assigned managed identity
data "azurerm_user_assigned_identity" "uai-agw" {
  name                = local.uai-agw-name
  resource_group_name = local.persistent-resource-group-name
}

# AKS Kubelet user-assigned managed identity
data "azurerm_user_assigned_identity" "uai-aks-kubelet" {
  name                = local.uai-aks-kubelet-name
  resource_group_name = local.persistent-resource-group-name
}

# AKS AGIC user-assigned managed identity
data "azurerm_user_assigned_identity" "uai-aks-agic" {
  name                = local.uai-aks-agic-name
  resource_group_name = local.persistent-resource-group-name
}

# AKS Keyvault user-assigned managed identity
data "azurerm_user_assigned_identity" "uai-aks-keyvault" {
  name                = local.uai-aks-keyvault-name
  resource_group_name = local.persistent-resource-group-name
}

