# =============================================================================
# web.tf  —  Sitio estático HTTPS en play.mcserver01.xyz
# =============================================================================
# Arquitectura: S3 (privado) + CloudFront (HTTPS, CDN) + ACM (certificado) +
#   Route 53 (alias del subdominio -> CloudFront).
# CloudFront lee del S3 vía OAC (Origin Access Control). El bucket NO es público.
# =============================================================================

locals {
  site_domain = "${var.web_subdomain}.${var.domain}" # ej. play.ejemplo.xyz
}

# --- Bucket privado que guarda el sitio ---
resource "aws_s3_bucket" "site" {
  bucket = "cherryfrost-mc-site-${random_id.bucket_suffix.hex}"
  tags   = { Project = "cherryFrostMC", Name = "cherryfrost-mc-site" }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Subir el index.html del sitio.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.module}/../mcServer-staticWebsite/index.html"
  etag         = filemd5("${path.module}/../mcServer-staticWebsite/index.html")
  content_type = "text/html"
}

# --- Certificado ACM para el subdominio (us-east-1, requerido por CloudFront) ---
resource "aws_acm_certificate" "site" {
  domain_name       = local.site_domain
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}

# Registros DNS de validación del certificado (en tu zona Route 53).
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# --- Origin Access Control: CloudFront lee del bucket privado ---
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "cherryfrost-site-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- Distribución CloudFront (HTTPS) ---
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [local.site_domain]

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https" # fuerza HTTPS
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Project = "cherryFrostMC" }
}

# --- Policy del bucket: solo CloudFront (vía OAC) puede leer ---
data "aws_iam_policy_document" "site" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

# --- Alias Route 53: play.mcserver01.xyz -> CloudFront ---
resource "aws_route53_record" "site" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.site_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

output "site_url" {
  value = "https://${local.site_domain}"
}
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}
