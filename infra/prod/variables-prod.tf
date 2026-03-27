# --- Contabo Variables ---
variable "contabo_client_id" {
  type      = string
  sensitive = true
}

variable "contabo_client_secret" {
  type      = string
  sensitive = true
}

variable "contabo_api_user" {
  type      = string
  sensitive = true
}

variable "contabo_api_password" {
  type      = string
  sensitive = true
}

# --- GoDaddy Variables ---
variable "godaddy_api_key" {
  type      = string
  sensitive = true
}

variable "godaddy_api_secret" {
  type      = string
  sensitive = true
}

# --- Application & SSH Variables ---
variable "public_ssh_key" {
  description = "The content of your id_erp_prod.pub file"
  type        = string
}

variable "gh_pat" {
  description = "GitHub Personal Access Token to clone your private repo"
  type        = string
  sensitive   = true
}

variable "repo_path" {
  description = "Format: username/repository-name"
  type        = string
}