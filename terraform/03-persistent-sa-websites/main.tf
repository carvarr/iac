
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

module "spa-storage" {
  source = "git::https://SuraColombia@dev.azure.com/SuraColombia/Gerencia_Tecnologia/_git/ti-lego-iac-azurerm-storage-lb?ref=v1.0"

  resource-group-name      = local.persistent-resource-group-name
  basename                 = local.basename
  enable-static-website    = true
  centro-de-costos         = local.centro-de-costos
  extra-tags               = {
    deployment-environment = local.deployment-environment
  }
}

resource "azurerm_storage_blob" "index-html" {
  name                   = "index.html"
  storage_account_name   = module.spa-storage.storage-account-name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = "<html><header><title>This is title</title></header><body>Hello world</body></html>"
}

# Para que Azure CDN emita y configure automáticamente el certificado
# para la comunicación HTTPS previamente debe existir en el dominio 
# 'example.com' un registro DNS tipo CNAME para el host 'www'
# que apunte a 'cdne-sitioweb-sufijo.azureedge.net'.
#
# El proveedor azurerm aún no soporta customs domains y mucho menos
# configurar o habilitar la característica Custom Domain HTTPS.
# https://github.com/terraform-providers/terraform-provider-azurerm/issues/398
# https://docs.microsoft.com/en-us/rest/api/cdn/customdomains/enablecustomhttps
#
# Por lo anterior es necesario que manualmente se configure la
# característica Custom Domain HTTPS al terminar el despliegue.
module "cdn-https-endpoints" {
  source = "git::https://SuraColombia@dev.azure.com/SuraColombia/Gerencia_Tecnologia/_git/ti-lego-iac-azurerm-cdn-https-endpoints-lb?ref=v1.1"

  resource-group-name      = local.persistent-resource-group-name
  basename                 = local.basename
  cdn-profile-name         = local.cdn-profile-name
  suffix                   = "-sufijo"
  endpoints-origin         = {
    "${local.basename}" = module.spa-storage.primary-web-host
  }
  endpoints-custom-domains = {
    "${local.basename}" = ["www.example.com"]
  }
  centro-de-costos         = local.centro-de-costos
  extra-tags               = {
    deployment-environment = local.deployment-environment
  }
}

output "spa-storage-account-name" {
  value = module.spa-storage.storage-account-name
}

