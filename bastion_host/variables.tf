variable "prefix" {
  description = "리소스명 prefix"
  type        = string
}

variable "public_subnet_a_id" {
  description = "Public Subnet A ID"
  type        = string
}

variable "bastion_sg_id" {
  description = "Bastion Security Group ID"
  type        = string
}
