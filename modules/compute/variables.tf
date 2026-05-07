variable "infrastructure_csv_path" {
  type = string
}

variable "linux_bootstrap_script_path" {
  type = string
}

variable "windows_bootstrap_script_path" {
  type = string
}

variable "compute_subnet_id" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "windows_admin_password" {
  type      = string
  sensitive = true
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
