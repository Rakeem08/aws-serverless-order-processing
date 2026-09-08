provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name             = "${var.project_name}-${var.environment}"
  metric_namespace = "Portfolio/Orders"
}

