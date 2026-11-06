provider "proxmox" {
  endpoint = var.proxmox_api_url
  insecure = true
  # api_token → PROXMOX_VE_API_TOKEN 환경 변수 사용
}

provider "aws" {
  region = var.aws_region
  # access_key / secret_key → ~/.aws/credentials 사용
}

provider "cloudflare" {
  # api_token → CLOUDFLARE_API_TOKEN 환경 변수 사용
}

module "proxmox" {
  source            = "./modules/proxmox"
  ssh_public_key    = var.ssh_public_key
  proxmox_node_name = var.proxmox_node_name
}

module "aws" {
  source              = "./modules/aws"
  ssh_public_key      = var.ssh_public_key
  alert_email         = var.alert_email
  discord_webhook_url = var.discord_webhook_url
  admin_ssh_cidr      = var.admin_ssh_cidr
}

module "cloudflare" {
  source     = "./modules/cloudflare"
  account_id = var.cloudflare_account_id
}
