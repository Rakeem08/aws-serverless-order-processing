data "archive_file" "create_order" {
  type        = "zip"
  source_file = "${path.module}/../../src/create_order/app.py"
  output_path = "${path.module}/create-order.zip"
}

data "archive_file" "get_order" {
  type        = "zip"
  source_file = "${path.module}/../../src/get_order/app.py"
  output_path = "${path.module}/get-order.zip"
}

data "archive_file" "process_order" {
  type        = "zip"
  source_file = "${path.module}/../../src/process_order/app.py"
  output_path = "${path.module}/process-order.zip"
}

locals {
  lambda_functions = {
    create = {
      source_hash = data.archive_file.create_order.output_base64sha256
      filename    = data.archive_file.create_order.output_path
      timeout     = 10
    }
    get = {
      source_hash = data.archive_file.get_order.output_base64sha256
      filename    = data.archive_file.get_order.output_path
      timeout     = 10
    }
    process = {
      source_hash = data.archive_file.process_order.output_base64sha256
      filename    = data.archive_file.process_order.output_path
      timeout     = 30
    }
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  for_each           = local.lambda_functions
  name               = "${local.name}-${each.key}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "create_order" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.orders.arn]
  }
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [local.metric_namespace]
    }
  }
}

data "aws_iam_policy_document" "get_order" {
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }
}

data "aws_iam_policy_document" "process_order" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }
  statement {
    actions   = ["sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage"]
    resources = [aws_sqs_queue.orders.arn]
  }
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.receipts.arn}/receipts/*"]
  }
  statement {
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.orders.arn]
  }
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [local.metric_namespace]
    }
  }
}

resource "aws_iam_role_policy" "function" {
  for_each = {
    create  = data.aws_iam_policy_document.create_order.json
    get     = data.aws_iam_policy_document.get_order.json
    process = data.aws_iam_policy_document.process_order.json
  }
  name   = "ApplicationPermissions"
  role   = aws_iam_role.lambda[each.key].id
  policy = each.value
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each          = local.lambda_functions
  name              = "/aws/lambda/${local.name}-${each.key}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.region}:*:log-group:/aws/lambda/${local.name}-*:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  for_each = local.lambda_functions
  name     = "WriteCloudWatchLogs"
  role     = aws_iam_role.lambda[each.key].id
  policy   = data.aws_iam_policy_document.logs.json
}

resource "aws_lambda_function" "function" {
  for_each = local.lambda_functions

  function_name    = "${local.name}-${each.key}"
  role             = aws_iam_role.lambda[each.key].arn
  handler          = "app.handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = each.value.filename
  source_code_hash = each.value.source_hash
  timeout          = each.value.timeout
  memory_size      = each.key == "process" ? 256 : 128

  environment {
    variables = {
      ORDERS_TABLE     = aws_dynamodb_table.orders.name
      ORDER_QUEUE_URL  = aws_sqs_queue.orders.url
      RECEIPTS_BUCKET  = aws_s3_bucket.receipts.id
      EVENT_BUS_NAME   = aws_cloudwatch_event_bus.orders.name
      METRIC_NAMESPACE = local.metric_namespace
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.function,
    aws_iam_role_policy.logs
  ]
}

resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn                   = aws_sqs_queue.orders.arn
  function_name                      = aws_lambda_function.function["process"].arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5
  }
}

