# Project 4 — Verified Results

## Purpose

Build a serverless order-processing platform that accepts authenticated
orders, processes them in the background, stores receipts, and sends
operational alerts.

This is a portfolio lab based on a simulated retail business.

## Successful tests

- Created a Cognito test user and authenticated successfully.
- Submitted an order through API Gateway.
- Submitted a duplicate request and received the same order ID.
- Confirmed the order reached PROCESSED.
- Verified the JSON receipt was stored in S3.
- Repeated the order test successfully after deployment through GitHub Actions.

## Monitoring and failure handling

- Submitted a deliberate failure message.
- Observed it reach the dead-letter queue.
- Verified CloudWatch changed the DLQ alarm to ALARM.
- Received the alarm email through SNS.
- Deleted the test message and confirmed recovery to OK.
- Received the recovery email.
- Confirmed all three configured alarms were OK.
- Viewed order and queue metrics in the CloudWatch dashboard.

## GitHub automation

- Passed Python linting and four unit tests.
- Passed Terraform formatting and validation.
- Authenticated to AWS using GitHub OIDC.
- Accessed encrypted S3 platform state with locking.
- Reviewed a plan updating three Lambda deployment packages.
- Applied the updates successfully through GitHub Actions.

The bootstrap stack uses local Terraform state.

## Problems fixed

### Python environment
Installed python3.12-venv to enable virtual-environment creation.

### Order test
Fixed the malformed idempotency-key expression in the smoke-test script.

### Alert email
Replaced the example email address and confirmed the SNS subscription.

### CloudWatch encryption permissions
Alarm history showed CloudWatch could not use the SNS encryption key.
Created a customer-managed KMS key with permissions for CloudWatch.
Verified alarm and recovery emails afterward.

### GitHub CI configuration
Set the cache dependency path to requirements-dev.txt.
Configured a region and dummy AWS credentials for unit tests.

### GitHub OIDC trust
Updated the AWS trust policy to match GitHub's actual subject claim,
including owner and repository IDs, restricted to the main branch.

## Testing limits

- Tests used a small number of synthetic orders.
- No load-capacity benchmark or cost savings were measured.
- Duplicate testing does not prove exactly-once processing under all conditions.
- Partial batch failures are not fully represented by Lambda Errors alone.
- The deployment role requires further permission restriction for production.
- The apply workflow generates a fresh plan rather than using the plan
  from an earlier workflow run.

## Cleanup status

- Destroyed all 46 platform resources.
- Emptied the versioned Terraform state bucket.
- Destroyed all 11 bootstrap resources.
- KMS keys were scheduled for deletion with a seven-day waiting period.
- Project code and verified results remain saved in GitHub.