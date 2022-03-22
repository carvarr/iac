
variable "resource-group-basename" {
  type = string
}

variable "basename" {
  type = string
}

variable "acr-basename" {
  type = string
}

variable "virtual-network-main-address-space" {
  type = string
}

variable "deployment-environment" {
  default = "dllo"

  validation {
    condition     = contains(["sbox", "dllo","lab", "pdn"], var.deployment-environment)
    error_message = "The 'deployment-environment' value must be in: 'sbox', 'dllo','lab', 'pdn'."
  }
}

variable "company-identifier" {
  validation {
    condition     = contains(["sr", "eps","arl", "din", "seg"], var.company-identifier)
    error_message = "The 'company-identifier' value must be in: 'sr', 'eps','arl', 'din', 'seg'."
  }
}

variable "centro-de-costos" {
  default = "PENDIENTE POR ASIGNAR"
}

resource "tls_private_key" "ssh-private-key" {
  algorithm   = "RSA"
  rsa_bits    = 2048
}

resource "random_id" "random-seed" {
  byte_length = 4
}

locals {
  # VLSM Calc
  # 2^1 = 2  : |       0       |       1       |
  # 2^2 = 4  : |   0   |   1   |   2   |   3   |
  # 2^3 = 8  : | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
  # 2^4 = 16 : |0|1|2|3|4|5|6|7|8|9|A|B|C|D|E|F|
  basename                       = var.basename
  virtual-network-subnets-cidrs  = {
    "aks"    : cidrsubnet(var.virtual-network-main-address-space, 1, 0),
    "pg"     : cidrsubnet(var.virtual-network-main-address-space, 4, 8),
    "agw"    : cidrsubnet(var.virtual-network-main-address-space, 3, 5),
  }
  resource-group-name            = "rg-${var.resource-group-basename}-${var.deployment-environment}-001"
  persistent-resource-group-name = "rg-${var.resource-group-basename}-persistence-${var.deployment-environment}-001"
  #acr-name                       = "acr${var.basename}${var.deployment-environment}${random_id.random-seed.hex}"
  acr-name                       = var.acr-basename

  uai-agw-name                   = "uai-agw-${var.basename}-${var.deployment-environment}"
  uai-aks-name                   = "uai-aks-${var.basename}-${var.deployment-environment}"
  uai-aks-kubelet-name           = "uai-aks-kubelet-${var.basename}-${var.deployment-environment}"
  uai-aks-agic-name              = "uai-aks-agic-${var.basename}-${var.deployment-environment}"
  uai-aks-keyvault-name          = "uai-aks-keyvault-${var.basename}-${var.deployment-environment}"

  agw-public-ip-name             = "pip-agw-${var.basename}"
  aks-outbound-public-ip-name    = "pip-aks-outbound-${var.basename}"

  cdn-profile-name               = "cdnp-${var.basename}"
}

resource "local_file" "ssh-private-key-file" {
    sensitive_content    = tls_private_key.ssh-private-key.private_key_pem
    filename             = "${path.module}/keys/ssh_private_key.pem"
    file_permission      = "0600"
    directory_permission = "0755"
}

resource "local_file" "ssh-public-key-file" {
    content              = tls_private_key.ssh-private-key.public_key_openssh
    filename             = "${path.module}/keys/ssh_private_key.pub"
    file_permission      = "0644"
    directory_permission = "0755"
}

output "basename" {
  value = local.basename
}

output "virtual-network-main-address-space" {
  value = var.virtual-network-main-address-space
}

output "virtual-network-subnets-cidrs" {
  value = local.virtual-network-subnets-cidrs
}

output "resource-group-name" {
  value = local.resource-group-name
}

output "persistent-resource-group-name" {
  value = local.persistent-resource-group-name
}

output "deployment-environment" {
  value = var.deployment-environment
}

output "company-identifier" {
  value = var.company-identifier
}

output "centro-de-costos" {
  value = var.centro-de-costos
}

output "acr-name" {
  value = local.acr-name
}

output "ssh-private-key-file" {
  value = local_file.ssh-private-key-file.filename
}

output "ssh-public-key-file" {
  value = local_file.ssh-public-key-file.filename
}

output "ssh-public-key" {
  value = tls_private_key.ssh-private-key.public_key_openssh
}

output "random-seed-hex" {
  value = random_id.random-seed.hex
}

output "uai-agw-name" {
  value = local.uai-agw-name
}

output "uai-aks-name" {
  value = local.uai-aks-name
}

output "uai-aks-kubelet-name" {
  value = local.uai-aks-kubelet-name
}

output "uai-aks-agic-name" {
  value = local.uai-aks-agic-name
}

output "uai-aks-keyvault-name" {
  value = local.uai-aks-keyvault-name
}

output "agw-public-ip-name" {
  value = local.agw-public-ip-name
}

output "aks-outbound-public-ip-name" {
  value = local.aks-outbound-public-ip-name
}

output "cdn-profile-name" {
  value = local.cdn-profile-name
}

