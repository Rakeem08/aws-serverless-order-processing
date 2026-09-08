# Operations runbook

## Alarm: dead-letter queue contains messages

1. Confirm the alarm and record its timestamp.
2. Inspect the processor Lambda logs around that time.
3. Receive one DLQ message without deleting it:

~~~bash
aws sqs receive-message --queue-url "$DLQ_URL" --max-number-of-messages 1
~~~

4. Identify whether the failure is bad input, missing permissions, dependency failure, or a code defect.
5. Fix and deploy the cause.
6. Redrive the message through the AWS console or the SQS redrive API.
7. Confirm the order becomes PROCESSED, the queue drains, and the alarm returns to OK.
8. Record the root cause and prevention step.

Do not blindly redrive messages before fixing the failure.

## Controlled failure drill

The script sends a synthetic message directly to SQS with simulate_failure=true. The worker deliberately rejects it. After the configured retries, it reaches the DLQ and triggers the alarm.

~~~bash
export ORDER_QUEUE_URL="$(terraform -chdir=infra/platform output -raw order_queue_url)"
./scripts/simulate-failure.sh
~~~

The test message is not a customer order and does not contain personal data.

## High queue age

1. Check ApproximateAgeOfOldestMessage.
2. Compare Lambda concurrency, errors, throttles, and duration.
3. Verify reserved concurrency was not set too low.
4. Check downstream DynamoDB and S3 errors.
5. Increase safe concurrency only after identifying downstream capacity.

## Rollback

Application code is packaged by Terraform. Revert the failing Git commit, run CI, and apply the previous known-good code. Confirm health metrics before resolving the incident.

