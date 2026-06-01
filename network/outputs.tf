output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_a_id" {
  value = aws_subnet.public_a.id
}

output "public_subnet_c_id" {
  value = aws_subnet.public_c.id
}

output "eks_subnet_a_id" {
  value = aws_subnet.eks_a.id
}

output "eks_subnet_c_id" {
  value = aws_subnet.eks_c.id
}

output "db_subnet_a_id" {
  value = aws_subnet.db_a.id
}

output "db_subnet_c_id" {
  value = aws_subnet.db_c.id
}

output "redis_subnet_a_id" {
  value = aws_subnet.redis_a.id
}

output "redis_subnet_c_id" {
  value = aws_subnet.redis_c.id
}
