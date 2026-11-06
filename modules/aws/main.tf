terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  common_tags = {
    Project     = "hybrid-devops-platform"
    Owner       = "jiong"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------
# ECR
# -----------------------------------------------
resource "aws_ecr_repository" "main" {
  name                 = "jiong-registry"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = "jiong-registry"
    Role = "container-registry"
  })
}

# 아래 내용부터 추가
# 아래 ECR은 [5-2] Jenkins 수동 빌드 → ECR Push → ArgoCD 자동 배포
# 4번 항목에서 수동으로 생성했던 레지스트리. import

# -----------------------------------------------
# ECR - portfolio-web
# -----------------------------------------------
resource "aws_ecr_repository" "portfolio_web" {
  name                 = "portfolio-web"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = "portfolio-web"
    Role = "container-registry"
  })
}

resource "aws_ecr_repository" "portfolio_web_cache" {
  name                 = "portfolio-web/cache"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = "portfolio-web-cache"
    Role = "container-registry"
  })
}

# -----------------------------------------------
# EC2 NAT Instance
# -----------------------------------------------
data "aws_ssm_parameter" "ubuntu2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "jiong" {
  key_name   = "jiong-key"
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    Name = "jiong-key"
    Role = "ssh-access"
  })
}

resource "aws_security_group" "nat" {
  name        = "jiong-nat-sg"
  description = "NAT instance SG - HTTP/HTTPS inbound + WireGuard UDP"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "WireGuard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "jiong-nat-sg"
    Role = "nat-gateway"
  })
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ssm_parameter.ubuntu2404_ami.value
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.jiong.key_name
  vpc_security_group_ids      = [aws_security_group.nat.id]
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "jiong-nat"
    Role = "nat-gateway"
  })
  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "nat" {
  instance = aws_instance.nat.id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "jiong-nat-eip"
    Role = "nat-gateway"
  })
}
