variable "project_name" {
  type = string
}

variable "alert_email" {
  description = "Email address to receive alerts"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the visitor counter Lambda function"
  type        = string
}

variable "api_id" {
  description = "API Gateway ID for monitoring"
  type        = string
}

variable "visitor_alarm_threshold" {
  description = "Max Lambda invocations per hour before alerting"
  type        = number
  default     = 10
}
