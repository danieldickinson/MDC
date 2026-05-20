variable "env_tag" {
  type        = string
  default     = "pc"
  description = "Two-letter env tag, e.g. 'pc' for PoC."
}

variable "location" {
  type        = string
  default     = "westeurope"
}

variable "admin_username" {
  type    = string
  default = "mdcadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "allowed_source_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Restrict to your egress IP /32 in real use."
}

variable "tags" {
  type = map(string)
  default = {
    env      = "poc-mdc"
    workshop = "cwpp-simulation"
    owner    = "replace-me@contoso.com"
    expires  = "2026-06-30"
  }
}
