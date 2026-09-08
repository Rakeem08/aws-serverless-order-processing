# Interview guide

## 45-second answer

I built a serverless order-processing platform for a retailer that needed to handle traffic spikes without losing or duplicating orders. API Gateway and Cognito secured the API, Lambda accepted requests, SQS separated the fast customer response from slower processing, and DynamoDB tracked order state. I used idempotency and partial batch failures to make retries safe, then added a dead-letter queue, CloudWatch dashboard, alarms, and SNS notifications so failures were visible. Terraform made the environment repeatable.

## Why each choice

| Choice | Reason |
| --- | --- |
| Lambda | Scale per request without maintaining an always-on server. |
| API Gateway | Provide a managed HTTP entry point with throttling and JWT authorization. |
| Cognito | Authenticate users without building password storage. |
| SQS | Absorb traffic spikes and retry temporary worker failures. |
| DynamoDB | Provide low-maintenance order state and conditional writes. |
| Idempotency key | Make client retries safe and prevent duplicate fulfillment. |
| Dead-letter queue | Separate poison messages for investigation instead of retrying forever. |
| S3 | Store durable receipt objects inexpensively. |
| EventBridge | Publish a business event without coupling future consumers to the worker. |
| CloudWatch and SNS | Detect operational problems and notify a human. |
| Terraform | Version, review, reproduce, and safely destroy the infrastructure. |

## Honest tradeoffs

- Serverless is excellent for uneven workloads, but very steady high-volume workloads may be cheaper on containers.
- SQS provides at-least-once delivery, so the worker must be idempotent.
- DynamoDB requires access-pattern-first design and is not a relational database.
- Cognito reduces authentication work but introduces AWS-specific behavior.
- CloudWatch is convenient inside AWS, while cross-cloud teams may prefer an external observability platform.
- The AI assistant proposes a diagnosis but intentionally does not auto-remediate.

## Questions to practice

1. Why does the API return 202 instead of waiting for fulfillment?
2. What happens when Lambda processes the same SQS message twice?
3. How does a message reach the dead-letter queue?
4. Why use SQS instead of calling the processor Lambda directly?
5. Which alarm would you investigate first and why?
6. How would you recover a DLQ message after fixing the cause?
7. What would you change for payment-card data?

