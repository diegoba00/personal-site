variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "allowed_origins" {
  type        = list(string)
  description = "Additional CORS origins to allow (e.g., custom domains)"
  default     = []
}
