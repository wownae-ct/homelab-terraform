variable "proxmox_api_url" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "cloudflare_account_id" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "alert_email" {
  description = "알림 수신 이메일 주소"
  type        = string
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for K8s alerts"
  type        = string
  sensitive   = true
}

variable "admin_ssh_cidr" {
  description = "NAT 인스턴스 SSH를 허용할 관리자 공인 IP (예: 203.0.113.10/32)"
  type        = string
}

variable "proxmox_node_name" {
  description = "VM을 만들 Proxmox 노드 이름"
  type        = string
  default     = "pve"
}
