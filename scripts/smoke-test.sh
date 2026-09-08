#!/usr/bin/env bash
set -euo pipefail

: "${API_URL:?Set API_URL}"
: "${ACCESS_TOKEN:?Set ACCESS_TOKEN}"

IDEMPOTENCY_KEY="portfolio-$(python3 -c 'import uuid; print(uuid.uuid4())')"
PAYLOAD='{"items":[{"sku":"BOOK-001","quantity":2,"unit_price":"12.50"}]}'

echo "Submitting the first order..."

FIRST="$(curl -fsS -X POST "$API_URL/orders" \
  -H "authorization: Bearer $ACCESS_TOKEN" \
  -H "idempotency-key: $IDEMPOTENCY_KEY" \
  -H "content-type: application/json" \
  -d "$PAYLOAD")"

echo "$FIRST"

ORDER_ID="$(python3 -c \
  'import json,sys; print(json.load(sys.stdin)["order_id"])' \
  <<<"$FIRST")"

echo "Submitting the same order again..."

SECOND="$(curl -fsS -X POST "$API_URL/orders" \
  -H "authorization: Bearer $ACCESS_TOKEN" \
  -H "idempotency-key: $IDEMPOTENCY_KEY" \
  -H "content-type: application/json" \
  -d "$PAYLOAD")"

echo "$SECOND"

SECOND_ID="$(python3 -c \
  'import json,sys; print(json.load(sys.stdin)["order_id"])' \
  <<<"$SECOND")"

if [[ "$ORDER_ID" != "$SECOND_ID" ]]; then
  echo "FAIL: Duplicate request returned a different order ID." >&2
  exit 1
fi

echo "PASS: Both requests returned the same order ID."
echo "Waiting for processing..."

for attempt in {1..20}; do
  RESULT="$(curl -fsS "$API_URL/orders/$ORDER_ID" \
    -H "authorization: Bearer $ACCESS_TOKEN")"

  echo "$RESULT"

  STATUS="$(python3 -c \
    'import json,sys; print(json.load(sys.stdin)["status"])' \
    <<<"$RESULT")"

  if [[ "$STATUS" == "PROCESSED" ]]; then
    echo "PASS: Order reached PROCESSED."
    exit 0
  fi

  sleep 2
done

echo "FAIL: Order did not reach PROCESSED within the test window." >&2
exit 1