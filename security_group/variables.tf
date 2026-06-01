variable "prefix" {
  description = "리소스명 prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
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
