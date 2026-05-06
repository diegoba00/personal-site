output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${module.cdn.cloudfront_domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name for website files"
  value       = module.cdn.s3_bucket_name
}

output "api_endpoint" {
  description = "Visitor counter API endpoint"
  value       = module.api.api_endpoint
}
