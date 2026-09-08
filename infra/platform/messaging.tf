resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${local.name}-orders-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "orders" {
  name                       = "${local.name}-orders"
  visibility_timeout_seconds = 90
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_cloudwatch_event_bus" "orders" {
  name = "${local.name}-events"
}

data "aws_caller_identity" "alerts_key_owner" {}

resource "aws_kms_key" "alerts" {
  description             = "Encrypts operational alerts for ${local.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.alerts_key_owner.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchAlarmEncryption"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.alerts_key_owner.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.alerts_key_owner.account_id}:alarm:${local.name}-*"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "alerts" {
  name          = "alias/${local.name}-alerts"
  target_key_id = aws_kms_key.alerts.key_id
}

resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = aws_kms_key.alerts.arn
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

