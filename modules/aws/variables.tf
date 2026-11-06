variable "ssh_public_key" {
  type        = string
  description = "SSH public key for EC2 key pair"
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
  description = "SSH를 허용할 관리자 공인 IP (예: 203.0.113.10/32)"
  type        = string
}
