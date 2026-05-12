terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# S3 Bucket: Almacenamiento para archivos del sitio
# ¿Por qué S3?
# - Barato: 5GB gratis/mes (tu sitio es <1MB)
# - Integra perfecto con CloudFront
# - Versionado: puedes recuperar versiones antiguas si algo se daña
# - Sin servidor que mantener
resource "aws_s3_bucket" "site" {
  bucket = "${var.project_name}-site"
}

# Versionado S3: Mantener histórico de cambios
# ¿Por qué?
# - Accidente: alguien borra index.html
# - Sin versionado: contenido desaparece del sitio
# - Con versionado: recuperas versión anterior en 2 segundos
# - Costo: mínimo (solo almacenamiento de versiones anteriores)
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bloqueo de acceso público a S3
# ¿Por qué?
# - Por defecto: S3 podría ser público (acceso directo a archivos)
# - Problema: bypass de CloudFront, pérdida de cachés, acceso sin control
# - Solución: bucketprivado, SOLO CloudFront puede leer
# - Usuarios acceden por CloudFront → benefician de CDN, compresión, caché
# - Analogía: tienda privada con empleado que vende puerta a puerta (CloudFront)
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OAC: Origin Access Control — credenciales para que CloudFront acceda a S3
# ¿Por qué?
# - CloudFront necesita permiso para leer S3 (S3 es privado)
# - OAC = "credencial segura" que CloudFront usa
# - SigV4 = firma criptográfica (más seguro que AWS Access Keys antiguas)
# - Resultado: usuario no puede acceder a S3 directo, solo a través de CloudFront
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Políticas de headers de seguridad
# ¿Por qué?
# - HSTS (1 año): fuerza HTTPS incluso si usuario tipea http://
# - Frame-Options DENY: previene ataques de clickjacking (página embebida en iframe malicioso)
# - X-Content-Type-Options: previene que navegador ejecute archivos como script
# - XSS Protection: protección adicional contra cross-site scripting
# - Referrer Policy: no envía información de referencia a sitios externos
# Sin estos headers: navegador no sabe que debe proteger al usuario
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.project_name}-security-headers"

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

# CloudFront Distribution: CDN global
# ¿Por qué?
# - PriceClass_100: 100 locaciones en 5 continentes (North America, Europe, Asia, Australia, South Africa)
# - default_root_object: /index.html (cuando abres diegoayala.click, sirve index.html)
# - compress: comprime archivos automáticamente (reduces tamaño 70%)
# - 403 error → 200 index.html: permite SPA routing (URLs como /about funcionan)
# ¿Sin CloudFront? Usuario en Australia espera 250ms+ para cada request
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${var.project_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${var.project_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = [var.domain_name, "www.${var.domain_name}"]

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
}

# S3 Bucket Policy: SOLO CloudFront puede leer archivos
# ¿Por qué?
# - Sin esta política: S3 sigue siendo privado pero nadie puede acceder (ni CloudFront)
# - Con esta política: CloudFront puede leer S3, usuario NO puede (solo por CloudFront)
# - Condición: "SourceArn = CloudFront distribution ARN" (verificación de identidad)
# - Resultado: seguridad + rendimiento (todos acceden por CloudFront)
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })
}
