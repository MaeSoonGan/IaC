variable "prefix" {
  description = "리소스명 prefix"
  type        = string
}

variable "db_subnet_a_id" {
  description = "DB Private Subnet A ID"
  type        = string
}

variable "db_subnet_c_id" {
  description = "DB Private Subnet C ID"
  type        = string
}

variable "rds_sg_id" {
  description = "RDS Security Group ID"
  type        = string
}

variable "db_password" {
  description = "RDS Master Password"
  type        = string
  sensitive   = true
}
