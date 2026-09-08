resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name          = "${local.name}-dlq-messages"
  alarm_description   = "One or more order messages could not be processed after retries."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.orders_dlq.name
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_age" {
  alarm_name          = "${local.name}-queue-age"
  alarm_description   = "The oldest order has waited more than two minutes."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 120
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.orders.name
  }
}

resource "aws_cloudwatch_metric_alarm" "processor_errors" {
  alarm_name          = "${local.name}-processor-errors"
  alarm_description   = "The order processor Lambda returned an error."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.function["process"].function_name
  }
}

resource "aws_cloudwatch_dashboard" "orders" {
  dashboard_name = "${local.name}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Order flow"
          region = data.aws_region.current.region
          stat   = "Sum"
          period = 60
          metrics = [
            [local.metric_namespace, "OrdersAccepted"],
            [".", "OrdersProcessed"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Queue health"
          region = data.aws_region.current.region
          period = 60
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", aws_sqs_queue.orders.name],
            [".", "ApproximateNumberOfMessagesVisible", ".", aws_sqs_queue.orders.name],
            [".", "ApproximateNumberOfMessagesVisible", ".", aws_sqs_queue.orders_dlq.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Lambda errors and throttles"
          region = data.aws_region.current.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.function["create"].function_name],
            [".", "Errors", ".", aws_lambda_function.function["process"].function_name],
            [".", "Throttles", ".", aws_lambda_function.function["process"].function_name]
          ]
        }
      }
    ]
  })
}

