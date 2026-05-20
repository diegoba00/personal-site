terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ACM must be in us-east-1 for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "cloudflare" {
  # Token leído de CLOUDFLARE_API_TOKEN (env var / GitHub secret)
}

module "dns" {
  source = "./modules/dns"

  domain_name        = var.domain_name
  cloudflare_zone_id = var.cloudflare_zone_id

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

module "cdn" {
  source = "./modules/cdn"

  project_name    = var.project_name
  aws_region      = var.aws_region
  domain_name     = var.domain_name
  certificate_arn = module.dns.certificate_arn
}

module "api" {
  source = "./modules/api"

  project_name    = var.project_name
  aws_region      = var.aws_region
  allowed_origins = [
    "https://${var.domain_name}",
    "https://www.${var.domain_name}",
  ]
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name         = var.project_name
  alert_email          = var.alert_email
  lambda_function_name = module.api.lambda_function_name
  api_id               = module.api.api_id
}

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = module.cdn.cloudfront_domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = module.cdn.cloudfront_domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
