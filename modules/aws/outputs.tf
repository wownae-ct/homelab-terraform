output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "nat_public_ip" {
  description = "Elastic IP of NAT EC2 instance"
  value       = aws_eip.nat.public_ip
}

output "nat_instance_id" {
  description = "Instance ID of NAT EC2"
  value       = aws_instance.nat.id
}
