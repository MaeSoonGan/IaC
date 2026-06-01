variable "prefix" {
  description = "리소스명 prefix"
  type        = string
}

variable "eks_subnet_a_id" {
  description = "EKS Private Subnet A ID"
  type        = string
}

variable "eks_subnet_c_id" {
  description = "EKS Private Subnet C ID"
  type        = string
}

variable "eks_node_sg_id" {
  description = "EKS Node Security Group ID"
  type        = string
}
