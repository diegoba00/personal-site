terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ACM must be in us-east-1 for CloudFront
# provider "aws" {
#   alias  = "us_east_1"
#   region = "us-east-1"
# }

# module "dns" {
#   source = "./modules/dns"
#
#   domain_name = var.domain_name
#
#   providers = {
#     aws           = aws
#     aws.us_east_1 = aws.us_east_1
#   }
# }

module "cdn" {
  source = "./modules/cdn"

  project_name = var.project_name
  aws_region   = var.aws_region
}

module "api" {
  source = "./modules/api"

  project_name = var.project_name
  aws_region   = var.aws_region
}

# A record apuntando a CloudFront — descomentar cuando el dominio esté activo
# resource "aws_route53_record" "root" {
#   zone_id = module.dns.zone_id
#   name    = var.domain_name
#   type    = "A"
#
#   alias {
#     name                   = module.cdn.cloudfront_domain_name
#     zone_id                = "Z2FDTNDATAQYW2"
#     evaluate_target_health = false
#   }
# }
#
# resource "aws_route53_record" "www" {
#   zone_id = module.dns.zone_id
#   name    = "www.${var.domain_name}"
#   type    = "A"
#
#   alias {
#     name                   = module.cdn.cloudfront_domain_name
#     zone_id                = "Z2FDTNDATAQYW2"
#     evaluate_target_health = false
#   }
# }
