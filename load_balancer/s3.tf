resource "aws_s3_bucket" "main" {
  bucket = "${var.prefix}-backup"

  tags = {
    Name = "${var.prefix}-backup"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ================================
# 프로필 이미지 버킷
# ================================
resource "aws_s3_bucket" "profile_images" {
  bucket = "${var.prefix}-profile-images"

  tags = {
    Name = "${var.prefix}-profile-images"
  }
}

# 쓰기 ACL은 차단, GetObject 버킷 정책은 허용
resource "aws_s3_bucket_public_access_block" "profile_images" {
  bucket = aws_s3_bucket.profile_images.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# profile-images/ 경로에 한해 GetObject만 공개
resource "aws_s3_bucket_policy" "profile_images" {
  bucket     = aws_s3_bucket.profile_images.id
  depends_on = [aws_s3_bucket_public_access_block.profile_images]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadProfileImages"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.profile_images.arn}/profile-images/*"
    }]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "profile_images" {
  bucket = aws_s3_bucket.profile_images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 수명주기 정책을 위해 버저닝 활성화
resource "aws_s3_bucket_versioning" "profile_images" {
  bucket = aws_s3_bucket.profile_images.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 교체된 이전 버전 이미지 30일 후 자동 삭제
resource "aws_s3_bucket_lifecycle_configuration" "profile_images" {
  bucket     = aws_s3_bucket.profile_images.id
  depends_on = [aws_s3_bucket_versioning.profile_images]

  rule {
    id     = "delete-noncurrent-versions"
    status = "Enabled"

    filter {
      prefix = "profile-images/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "profile_images" {
  bucket = aws_s3_bucket.profile_images.id

  cors_rule {
    allowed_headers = ["Content-Type"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = [
      "http://localhost:5173",
      "https://${var.domain_name}",
      "https://www.${var.domain_name}"
    ]
    max_age_seconds = 3000
  }
}

# ================================
# IAM 정책 - auth-service PutObject 전용
# ================================
resource "aws_iam_policy" "auth_service_s3" {
  name        = "${var.prefix}-auth-service-s3-policy"
  description = "auth-service 프로필 이미지 업로드 전용 최소 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.profile_images.arn}/profile-images/*"
    }]
  })
}
