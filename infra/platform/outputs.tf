output "api_url" {
  value = aws_apigatewayv2_api.orders.api_endpoint
}

output "user_pool_id" {
  value = aws_cognito_user_pool.customers.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.api.id
}

output "order_queue_url" {
  value = aws_sqs_queue.orders.url
}

output "dead_letter_queue_url" {
  value = aws_sqs_queue.orders_dlq.url
}

output "receipts_bucket" {
  value = aws_s3_bucket.receipts.id
}

output "alarm_topic_arn" {
  description = "Pass this ARN to Project 5 as source_alarm_topic_arn."
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.orders.dashboard_name
}

