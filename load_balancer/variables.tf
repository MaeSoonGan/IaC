variable "prefix" {
  description = "리소스명 prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_a_id" {
  description = "Public Subnet A ID (ap-northeast-2a)"
  type        = string
}

variable "public_subnet_c_id" {
  description = "Public Subnet C ID (ap-northeast-2c)"
  type        = string
}

variable "alb_sg_id" {
  description = "ALB Security Group ID"
  type        = string
}

variable "domain_name" {
  description = "Route 53 Hosted Zone 도메인명"
  type        = string
}

# variable "acm_certificate_arn" {
#   description = "ACM 인증서 ARN (HTTPS 리스너용)"
#   type        = string
# }
