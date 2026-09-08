#!/usr/bin/env bash
set -euo pipefail

: "${ORDER_QUEUE_URL:?Set ORDER_QUEUE_URL}"

aws sqs send-message \
  --queue-url "$ORDER_QUEUE_URL" \
  --message-body '{"order_id":"failure-drill","simulate_failure":true}'

echo "Controlled failure submitted. Watch the processor logs, DLQ metric, and alarm."

