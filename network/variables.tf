variable "prefix" {
  description = "리소스명 prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.14.0.0/16"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "fisaschool-vpc"
}
