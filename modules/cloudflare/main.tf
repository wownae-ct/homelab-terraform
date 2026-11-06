terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

resource "cloudflare_r2_bucket" "main" {
  account_id = var.account_id
  name       = "portfolio-web"

  lifecycle {
    prevent_destroy = true
  }
}
