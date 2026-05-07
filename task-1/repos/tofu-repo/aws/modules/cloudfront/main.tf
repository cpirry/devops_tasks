data "aws_cloudfront_cache_policy" "this" {
  name = var.cache_policy_name
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.s3_bucket_name}-oac"
  description                       = "OAC for ${var.s3_bucket_name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name              = var.s3_bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = var.s3_bucket_name
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.description
  default_root_object = "index.html"

  aliases = var.domain_aliases

  default_cache_behavior {
    # cache dehaviour
  }

  custom_error_response {
    # error responses
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    # logging config
  }

  web_acl_id = var.waf_web_acl_arn

  tags = var.tags
}
