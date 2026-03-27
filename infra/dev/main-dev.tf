terraform {
  required_providers {
    aws     = { source = "hashicorp/aws" version = "~> 5.0" }
    godaddy = { source = "n3integration/godaddy" version = "~> 1.9.1" }
  }
}

# 1. AWS Provider Configuration
provider "aws" {
  region = var.aws_region
}

# 2. GoDaddy Provider Configuration
provider "godaddy" {
  key    = var.godaddy_api_key
  secret = var.godaddy_api_secret
}

# 3. Create S3 Bucket for Backups
resource "aws_s3_bucket" "erp_backup" {
  bucket = var.s3_bucket_name
}

# 4. Create SSH Key Pair for EC2
resource "aws_key_pair" "deployer" {
  key_name   = "erp-deploy-key"
  public_key = var.public_ssh_key
}

# 5. Security Group (Firewall)
resource "aws_security_group" "erp_sg" {
  name = "erp-security-group"

  ingress { from_port = 22; to_port = 22; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

# 6. Provision EC2 Instance
resource "aws_instance" "erp_server" {
  ami           = "ami-053b12d3152c0cc71" # Amazon Linux 2023 (Verify for your region)
  instance_type = "t3.small"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.erp_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              # Install Docker, Docker Compose, Git, and Rclone
              dnf update -y
              dnf install -y docker git
              systemctl enable --now docker
              
              # Install Docker Compose V2
              mkdir -p /usr/local/lib/docker/cli-plugins
              curl -SL https://github.com -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Setup rclone for S3
              mkdir -p /root/.config/rclone
              cat <<EOC > /root/.config/rclone/rclone.conf
              [aws-s3]
              type = s3
              provider = AWS
              access_key_id = ${var.aws_access_key}
              secret_access_key = ${var.aws_secret_key}
              region = ${var.aws_region}
              EOC

              # Clone Repo and run Setup
              git clone https://${var.gh_pat}@://github.com{var.repo_path}.git /opt/erp
              cd /opt/erp
              chmod +x *.sh
              ./init.sh
              EOF
}

# 7. Update GoDaddy DNS
resource "godaddy_domain_record" "erp_dns" {
  domain = var.domain_name
  record {
    name = "dev-erp"
    type = "A"
    data = aws_instance.erp_server.public_ip
    ttl  = 600
  }
}
