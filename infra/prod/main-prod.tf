terraform {
  required_providers {
    contabo = {
      source  = "contabo/contabo"
      version = ">= 0.1.32"
    }
    godaddy = {
      source  = "n3integration/godaddy"
      version = ">= 1.9.1"
    }
  }
}

# 1. Provide Contabo Credentials
provider "contabo" {
  oauth2_client_id     = var.contabo_client_id
  oauth2_client_secret = var.contabo_client_secret
  oauth2_user          = var.contabo_api_user
  oauth2_pass          = var.contabo_api_password
}

# 2. Provide GoDaddy Credentials
provider "godaddy" {
  key    = var.godaddy_api_key
  secret = var.godaddy_api_secret
}

# 3. Register your SSH Public Key with Contabo
resource "contabo_secret" "deploy_ssh_key" {
  name  = "erp-deployment-key"
  type  = "ssh"
  value = var.public_ssh_key # The .pub key you generated
}

data "contabo_image" "ubuntu" {
  id = "ubuntu-22.04"
}

# 4. Create the Contabo VPS Instance
resource "contabo_instance" "erp_server" {
  display_name = "ERP-Prod"
  product_id   = "vps_s_ssdv_10" 
  region       = "IN"
  image_id     = data.contabo_image.ubuntu.id
  ssh_keys     = [contabo_secret.deploy_ssh_key.id]

  # The automation script runs on the first boot
  user_data = <<-USERDATA
#!/bin/bash
set -e
apt-get update && 
apt-get install -y docker.io docker-compose-plugin git rclone ufw
              
systemctl enable --now docker

ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw --force enable

# Setup rclone config for S3
mkdir -p /root/.config/rclone
echo "[contabo-s3]" > /root/.config/rclone/rclone.conf
echo "type = s3" >> /root/.config/rclone/rclone.conf
echo "provider = Ceph" >> /root/.config/rclone/rclone.conf
echo "access_key_id = ${var.s3_access_key}" >> /root/.config/rclone/rclone.conf
echo "secret_access_key = ${var.s3_secret_key}" >> /root/.config/rclone/rclone.conf
echo "endpoint = ${var.s3_endpoint}" >> /root/.config/rclone/rclone.conf

# setup initial bucket if not already exist
rclone mkdir contabo-s3:erp-prod-bucket || true

# Add public ssh key to the server so deploy pipeline can enter
mkdir -p /root/.ssh
echo "${var.public_ssh_key}" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Clone your private repo using your PAT
git clone https://${var.gh_pat}@github.com/${var.repo_path}.git /opt/erp || true
cd /opt/erp

echo "${var.env_file_content}" > .env

echo "Waiting for DNS propagation..."
sleep 120
              
# Initial Setup and SSL
chmod +x init.sh
DB_USER=${var.db_user} DB_NAME=${var.db_name} DOMAIN_NAME=${var.domain_name} EMAIL="constructiveindia@gmail.com" ./init.sh
USERDATA
}

# 5. Automatically update GoDaddy DNS for ://yourcompany.com
resource "godaddy_domain_record" "erp_dns" {
  domain   = var.domain_name # Replace with your actual domain
  
  record {
    name = "erp" # This creates the 'erp' subdomain
    type = "A"
    data = contabo_instance.erp_server.ip_config[0].v4[0].ip # Points to the new VPS IP
    ttl  = 600
  }
}

# Outputs for your reference
output "new_vps_ip" {
  value = contabo_instance.erp_server.ip_config[0].v4[0].ip
}

output "full_domain" {
  value = "https://erp.${var.domain_name}"
}

output "debug_ip_config" {
  value = contabo_instance.erp_server.ip_config
}
