output "bucket_id" {
  value = aws_s3_bucket.main.id
}

output "bucket_arn" {
  value = aws_s3_bucket.main.arn
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.eks.arn
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}

output "record_fqdn" {
  value = aws_route53_record.alb.fqdn
}
