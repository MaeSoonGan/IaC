variable "prefix" {
  description = "리소스명 앞에 붙는 prefix"
  type        = string
  default     = "maesoongan"
}

variable "db_password" {
  description = "RDS 마스터 비밀번호"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis 인증 토큰"
  type        = string
  sensitive   = true
}

# variable "acm_certificate_arn" {
#   description = "ACM 인증서 ARN (HTTPS 리스너용)"
#   type        = string
# }

variable "domain_name" {
  description = "Route 53 도메인명"
  type        = string
}

variable "onprem_main_cidr" {
  description = "온프레미스 Main Center CIDR"
  type        = string
}

variable "onprem_dr_cidr" {
  description = "온프레미스 DR Center CIDR"
  type        = string
}

variable "onprem_monitoring_cidr" {
  description = "온프레미스 Monitoring Center CIDR"
  type        = string
}
