variable "aws_region" { default = "us-east-1" }
variable "aws_access_key" { sensitive = true }
variable "aws_secret_key" { sensitive = true }
variable "godaddy_api_key" { sensitive = true }
variable "godaddy_api_secret" { sensitive = true }
variable "public_ssh_key" {}
variable "gh_pat" { sensitive = true }
variable "repo_path" {}
variable "domain_name" {}
variable "s3_bucket_name" {}