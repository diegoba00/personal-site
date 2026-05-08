terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# Route53: Sistema de DNS de AWS
# ¿Por qué?
# - Cuando usuario tipea diegoayala.click, Route53 lo resuelve a CloudFront IP
# - Sin Route53: necesitarías registrador de dominio externo (GoDaddy, etc)
# - Con Route53: integración perfecta con CloudFront + ACM para SSL
# - Costo: $0.50/mes por zona DNS (muy barato)
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# ACM Certificate: Certificado SSL/TLS para HTTPS
# ¿Por qué?
# - Sin HTTPS: navegador muestra "No es seguro"
# - Con HTTPS: conexión encriptada, browser confía
# - ACM = Certificate Management automático
# - Validación DNS: Terraform prueba que tienes el dominio
# - GRATIS: AWS da certificados gratis (costo cero)
# ¿Sin ACM? Comprar certificado a $50-100/año
# - aws.us_east_1: ACM para CloudFront DEBE estar en us-east-1 (requisito AWS)
resource "aws_acm_certificate" "main" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = ["www.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 Records para validación de certificado
# ¿Por qué?
# - AWS: "Demuéstrame que tienes diegoayala.click"
# - Solución: agrega un registro DNS especial
# - Terraform: busca el registro especial que ACM requiere y lo agrega automáticamente
# - Resultado: en 2 minutos el certificado se valida
# ¿Sin esto? Certificado nunca se valida, HTTPS no funciona
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# ACM Certificate Validation: Confirmar que Route53 records se propagaron
# ¿Por qué?
# - Certificado está creado pero NO validado aún
# - Este recurso espera a que Route53 records existan en DNS
# - Una vez que DNS los ve: certificado se valida automáticamente
# - Terraform espera hasta 75 segundos por validación
# - Resultado: certificado HTTPS ready para CloudFront
resource "aws_acm_certificate_validation" "main" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
