#!/usr/bin/env bash
set -euo pipefail

: "${API_URL:?Set API_URL}"
: "${ACCESS_TOKEN:?Set ACCESS_TOKEN}"

IDEMPOTENCY_KEY="portfolio-${RANDOM-${RANDOM"
PAYLOAD='{"items":[{"sku":"BOOK-001","quantity":2,"unit_price":"12.50"}]}'

FIRST="$(curl -fsS -X POST "$API_URL/orders" \
  -H "authorization: Bearer $ACCESS_TOKEN" \
  -H "idempotency-key: $IDEMPOTENCY_KEY" \
  -H "content-type: application/json" \
  -d "$PAYLOAD")"
echo "$FIRST"

ORDER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["order_id"])' <<<"$FIRST")"

SECOND="$(curl -fsS -X POST "$API_URL/orders" \
  -H "authorization: Bearer $ACCESS_TOKEN" \
  -H "idempotency-key: $IDEMPOTENCY_KEY" \
  -H "content-type: application/json" \
  -d "$PAYLOAD")"
echo "$SECOND"

SECOND_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["order_id"])' <<<"$SECOND")"
test "$ORDER_ID" = "$SECOND_ID"

for _attempt in {1..20}; do
  RESULT="$(curl -fsS "$API_URL/orders/$ORDER_ID" -H "authorization: Bearer $ACCESS_TOKEN")"
  echo "$RESULT"
  STATUS="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' <<<"$RESULT")"
  test "$STATUS" = "PROCESSED" && exit 0
  sleep 2
done

echo "Order did not reach PROCESSED state" >&2
exit 1

