# Serverless Order Processing Platform on AWS

A production-style portfolio project that accepts authenticated orders, processes them asynchronously, survives duplicate requests and worker failures, and alerts an operator when the system is unhealthy.

## Business problem

An online retailer was losing orders during traffic spikes and occasionally fulfilling duplicate orders after clients retried timed-out requests. The company needed fast API responses, reliable background processing, clear order status, and operational alarms without maintaining servers.

## Solution

- Amazon Cognito authenticates callers.
- API Gateway exposes POST /orders and GET /orders/{order_id}.
- A Python Lambda validates orders and returns HTTP 202 Accepted.
- DynamoDB stores order state and supports deterministic idempotency.
- SQS buffers traffic and retries temporary processing failures.
- A dead-letter queue isolates messages that repeatedly fail.
- A worker Lambda creates a receipt in S3 and emits an EventBridge event.
- CloudWatch dashboards, logs, metrics, and alarms expose failures and queue delay.
- SNS sends operational notifications.
- Terraform provisions the complete platform.

## Architecture

~~~mermaid
flowchart TD
    U[Customer] --> C[Cognito]
    U --> A[API Gateway]
    C --> A
    A --> L1[Order API Lambda]
    L1 --> D[DynamoDB]
    L1 --> Q[SQS]
    Q --> L2[Processor Lambda]
    Q --> DLQ[Dead-letter queue]
    L2 --> D
    L2 --> S3[S3 receipts]
    L2 --> EB[EventBridge]
    CW[CloudWatch alarms] --> SNS[SNS alerts]
    L1 --> CW
    L2 --> CW
    Q --> CW
~~~

## Real-world failures this project handles

| Failure | Design response |
| --- | --- |
| Customer submits the same order twice | The Idempotency-Key creates the same order ID and the worker safely ignores completed orders. |
| Sudden order spike | SQS absorbs the burst while Lambda scales consumers. |
| One message in a batch fails | Partial batch responses retry only the failed SQS record. |
| Repeated processing failure | SQS moves the message to a dead-letter queue and CloudWatch alarms. |
| Worker writes a receipt twice | The deterministic S3 object key makes the write repeatable. |
| Unauthorized caller | API Gateway verifies a Cognito JWT before invoking Lambda. |
| Operator cannot see the problem | Logs, custom metrics, a dashboard, alarms, and SNS expose the condition. |

## Repository layout

~~~text
src/                 Lambda application code
tests/               Unit tests
infra/bootstrap/     Remote-state and GitHub OIDC bootstrap
infra/platform/      Application infrastructure
scripts/             Authentication, smoke-test, and failure-drill helpers
docs/                Runbook, interview guide, and deployment checklist
.github/workflows/   CI and manual deployment pipelines
~~~

## Prerequisites

- AWS account and AWS CLI v2
- Terraform 1.10 or newer
- Python 3.12
- An email address for alarm notifications
- A GitHub repository if using the OIDC deployment workflow

## Deployment overview

1. Copy infra/bootstrap/terraform.tfvars.example to terraform.tfvars.
2. Deploy infra/bootstrap.
3. Copy the backend values from the bootstrap outputs into infra/platform/backend.hcl.
4. Copy infra/platform/terraform.tfvars.example to terraform.tfvars.
5. Deploy infra/platform.
6. Create a Cognito test user and retrieve a token with scripts/get-token.sh.
7. Run scripts/smoke-test.sh.
8. Run the failure drill in docs/runbook.md.
9. Destroy the platform when finished to stop charges.

Exact commands and evidence requirements are in [the deployment checklist](docs/deployment-checklist.md).

## Interview summary

> I built an authenticated, event-driven order platform with API Gateway and Lambda. I used SQS to absorb traffic spikes and retry temporary failures, DynamoDB and an idempotency key to prevent duplicate processing, and a dead-letter queue for messages that could not be recovered automatically. I added CloudWatch dashboards and alarms so the system could be operated, not merely deployed, and provisioned it with Terraform for repeatability.

## Project 5 connection

The companion AI Incident Assistant can subscribe to this project's alarm topic. It gathers bounded CloudWatch evidence and uses Amazon Bedrock to create a human-reviewed incident summary. The projects are separate repositories because order processing and AI operations are different business capabilities.

## Cost and cleanup

This architecture is serverless and should remain inexpensive at lab traffic levels, but it is not free. API requests, Lambda duration, DynamoDB, SQS, S3, CloudWatch, Cognito, SNS, and Terraform state storage can all generate charges. Set a budget, test briefly, and destroy the platform when finished:

~~~bash
terraform -chdir=infra/platform destroy
~~~

The remote-state bootstrap should be destroyed only after the platform state is no longer needed.

