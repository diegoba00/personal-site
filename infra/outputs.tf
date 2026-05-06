output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${module.cdn.cloudfront_domain_name}"
}

output "site_url" {
  description = "Custom domain URL"
  value       = "https://${var.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name for website files"
  value       = module.cdn.s3_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cdn.cloudfront_distribution_id
}

output "api_endpoint" {
  description = "Visitor counter API endpoint"
  value       = module.api.api_endpoint
}

output "name_servers" {
  description = "Route 53 name servers — configure in your domain registrar if no usando Route 53"
  value       = module.dns.name_servers
}
