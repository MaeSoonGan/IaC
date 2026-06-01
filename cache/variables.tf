variable "prefix" {
  description = "리소스명 prefix"
  type        = string
}

variable "redis_subnet_a_id" {
  description = "Redis Private Subnet A ID"
  type        = string
}

variable "redis_subnet_c_id" {
  description = "Redis Private Subnet C ID"
  type        = string
}

variable "cache_sg_id" {
  description = "ElastiCache Security Group ID"
  type        = string
}

variable "redis_password" {
  description = "Redis 인증 토큰"
  type        = string
  sensitive   = true
}
