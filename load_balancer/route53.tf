# ================================
# 기존 Hosted Zone 참조 (콘솔에서 생성된 것)
# ================================
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# ================================
# A 레코드 → NLB (maesoongan.xyz)
# ================================
resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = true
  }
}

# ================================
# A 레코드 → NLB (www.maesoongan.xyz)
# ================================
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = true
  }
}
