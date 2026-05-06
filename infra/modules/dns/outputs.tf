output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.main.certificate_arn
}

output "name_servers" {
  description = "Route 53 name servers — configure these in your domain registrar"
  value       = aws_route53_zone.main.name_servers
}
