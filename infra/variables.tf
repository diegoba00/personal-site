variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dha-personal-site"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Custom domain name"
  type        = string
  default     = "diegoayala.click"
}
