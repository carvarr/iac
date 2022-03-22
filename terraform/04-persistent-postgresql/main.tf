
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
  basename                           = data.terraform_remote_state.globals.outputs.basename
  resource-group-name                = data.terraform_remote_state.globals.outputs.resource-group-name
  persistent-resource-group-name     = data.terraform_remote_state.globals.outputs.persistent-resource-group-name
  centro-de-costos                   = data.terraform_remote_state.globals.outputs.centro-de-costos
  deployment-environment             = data.terraform_remote_state.globals.outputs.deployment-environment
  virtual-network-subnets-cidrs      = data.terraform_remote_state.globals.outputs.virtual-network-subnets-cidrs
  virtual-network-main-address-space = data.terraform_remote_state.globals.outputs.virtual-network-main-address-space

  # Networking
  main-virtual-network-resource-group-name = data.terraform_remote_state.networking.outputs.main-virtual-network-resource-group-name
  main-virtual-network-name                = data.terraform_remote_state.networking.outputs.main-virtual-network-name
  main-virtual-network-id                  = data.terraform_remote_state.networking.outputs.main-virtual-network-id

  private_dns_zones_subscription = {
    "dllo" : "f299beb5-1fe7-4545-a8a6-bf418663139a"
    "lab"  : "04e289eb-5a69-470d-a2fb-0b40a0ee2687"
    "pdn"  : "dea3b5eb-475a-45a8-9c9b-0ef384e79015"
  }

  private_dns_zones_names = {
    "dllo" = "dllosura.postgres.database.azure.com"
    "lab"  = "labsura.postgres.database.azure.com"
    "pdn"  = "pdnsura.postgres.database.azure.com"
  }

  private_dns_zones_rg_names = {
    "dllo" = "rg-domaincontrollers-dll"
    "lab"  = "Lab_MS_Services"
    "pdn"  = "rg-servicios-dns-ldap-pdn"
  }

  private_dns_zones_ids = {
    "dllo" = "/subscriptions/${local.private_dns_zones_subscription["dllo"]}/resourceGroups/${local.private_dns_zones_rg_names["dllo"]}/providers/Microsoft.Network/privateDnsZones/${local.private_dns_zones_names["dllo"]}"
    "lab"  = "/subscriptions/${local.private_dns_zones_subscription["lab"]}/resourceGroups/${local.private_dns_zones_rg_names["lab"]}/providers/Microsoft.Network/privateDnsZones/${local.private_dns_zones_names["lab"]}"
    "pdn"  = "/subscriptions/${local.private_dns_zones_subscription["pdn"]}/resourceGroups/${local.private_dns_zones_rg_names["pdn"]}/providers/Microsoft.Network/privateDnsZones/${local.private_dns_zones_names["pdn"]}"
  }
}

data "azurerm_resource_group" "persistent-resource-group" {
  name = local.persistent-resource-group-name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-pg-${local.basename}"
  resource_group_name  = local.persistent-resource-group-name
  virtual_network_name = local.main-virtual-network-name
  address_prefixes     = [local.virtual-network-subnets-cidrs["pg"]]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_route_table" "route-table" {
  name                          = "route-pg-${local.basename}"
  location                      = data.azurerm_resource_group.persistent-resource-group.location
  resource_group_name           = local.persistent-resource-group-name
  disable_bgp_route_propagation = false

  tags = {
    iac-deployer           = "terraform"
    CentroDeCostos         = local.centro-de-costos
    deployment-environment = local.deployment-environment
  }
}

resource "azurerm_route" "vnet-routes" {
  for_each = local.virtual-network-subnets-cidrs

  name                = "r-pg-${each.key}-${local.basename}"
  resource_group_name = local.persistent-resource-group-name
  route_table_name    = azurerm_route_table.route-table.name
  address_prefix      = each.value
  next_hop_type       = "VnetLocal"
}

resource "azurerm_route" "default-route" {
  name                = "r-pg-default-${local.basename}"
  resource_group_name = local.persistent-resource-group-name
  route_table_name    = azurerm_route_table.route-table.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "route-table-association" {
  subnet_id      = azurerm_subnet.subnet.id
  route_table_id = azurerm_route_table.route-table.id
}

module "postgresql-server" {
  source = "git::https://SuraColombia@dev.azure.com/SuraColombia/Gerencia_Tecnologia/_git/ti-lego-iac-azurerm-postgresql-lb?ref=v1.1"

  resource-group-name   = local.persistent-resource-group-name
  basename              = local.basename
  company-identifier    = "sr"
  environment-letter    = substr(local.deployment-environment, 0, 1)
  centro-de-costos      = local.centro-de-costos
  subnet-id             = azurerm_subnet.subnet.id
  private-dns-zone-id   = local.private_dns_zones_ids[local.deployment-environment]
  sku-name              = "B_Standard_B1ms"
  max-storage-mb        = 32768
  backup-retention-days = 7

  extra-tags = {
    deployment-environment = local.deployment-environment
  }
}

# https://segurosti.atlassian.net/wiki/spaces/AR/pages/1381761738/Azure+Database+for+PostgreSQL
resource "azurerm_postgresql_flexible_server_database" "database" {
  name      = "${local.deployment-environment}${local.basename}"
  server_id = module.postgresql-server.server-id
  collation = "en_US.utf8"
  charset   = "utf8"
}

output "postgresql-server-id" {
  value = module.postgresql-server.server-id
}

output "postgresql-server-name" {
  value = module.postgresql-server.server-name
}

output "postgresql-server-fqdn" {
  value = module.postgresql-server.server-fqdn
}

output "postgresql-admin-username" {
  value = module.postgresql-server.admin-username
}

output "postgresql-admin-password" {
  value     = module.postgresql-server.admin-password
  sensitive = true
}
