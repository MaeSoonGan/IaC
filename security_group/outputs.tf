output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "eks_node_sg_id" {
  value = aws_security_group.eks_node.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "cache_sg_id" {
  value = aws_security_group.cache.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}
