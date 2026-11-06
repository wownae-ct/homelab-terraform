output "nat_public_ip" {
  description = "Elastic IP of NAT EC2 instance"
  value       = module.aws.nat_public_ip
}

output "nat_instance_id" {
  description = "Instance ID of NAT EC2"
  value       = module.aws.nat_instance_id
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for Alertmanager"
  value       = module.aws.sns_topic_arn
}
