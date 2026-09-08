variable "aws_region" {
  type        = string
  description = "AWS Region for the platform."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Short project name."
  default     = "serverless-orders"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"
}

variable "alert_email" {
  type        = string
  description = "Email that receives alarm notifications. Leave blank to skip the subscription."
  default     = ""
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention period."
  default     = 14
}

variable "allowed_origins" {
  type        = list(string)
  description = "Browser origins allowed by API Gateway CORS."
  default     = ["http://localhost:3000"]
}
