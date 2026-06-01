resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.prefix}-cache-subnet-group"
  description = "Cache Subnet Group"
  subnet_ids  = [var.redis_subnet_a_id, var.redis_subnet_c_id]

  tags = {
    Name = "${var.prefix}-cache-subnet-group"
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.prefix}-redis-cluster"
  description          = "Redis OSS Cache"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.cache_sg_id]

  preferred_cache_cluster_azs = [
    "ap-northeast-2a"
  ]

  snapshot_retention_limit = 1
  snapshot_window          = "03:00-04:00"

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_password

  tags = {
    Name = "${var.prefix}-redis-cluster"
  }
}
