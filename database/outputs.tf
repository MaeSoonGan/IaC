output "primary_endpoint" {
  value = aws_db_instance.primary.endpoint
}

# 장애 테스트 시 주석 해제
# output "replica_endpoint" {
#   value = aws_db_instance.replica.endpoint
# }
