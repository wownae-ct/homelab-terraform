# ──────────────────────────────────────
# SNS Topic — K8s Alertmanager 알림용
# ──────────────────────────────────────
resource "aws_sns_topic" "k8s_alerts" {
  name = "k8s-cluster-alerts"

  tags = {
    Project     = "cloud-native-platform"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# 이메일 구독
resource "aws_sns_topic_subscription" "alert_email" {
  topic_arn = aws_sns_topic.k8s_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Output — 나중에 Alertmanager 설정에 사용
output "sns_topic_arn" {
  description = "SNS Topic ARN for Alertmanager webhook"
  value       = aws_sns_topic.k8s_alerts.arn
}
