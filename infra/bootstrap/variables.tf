variable "aws_region" {
  description = "AWS Region for the state bucket and deployment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used in resource names."
  type        = string
  default     = "serverless-orders"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form."
  type        = string
}

variable "github_owner_id" {
  description = "Numeric GitHub owner ID used in the immutable OIDC subject."
  type        = string
}

variable "github_repository_id" {
  description = "Numeric GitHub repository ID used in the immutable OIDC subject."
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the deployment role."
  type        = string
  default     = "main"
}

variable "additional_role_prefixes" {
  description = "Additional project role prefixes the portfolio deployment role may manage."
  type        = list(string)
  default     = ["ai-incident-assistant"]
}
