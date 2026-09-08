import base64
import json
import os
import uuid
from decimal import Decimal, InvalidOperation

import boto3
from botocore.exceptions import ClientError

ORDERS_TABLE = os.environ.get("ORDERS_TABLE", "orders")
ORDER_QUEUE_URL = os.environ.get("ORDER_QUEUE_URL", "")
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "Portfolio/Orders")

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")
cloudwatch = boto3.client("cloudwatch")


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }


def customer_id_from(event):
    return (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
        .get("sub")
    )


def parse_body(event):
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    return json.loads(raw)


def validate_order(payload):
    items = payload.get("items")
    if not isinstance(items, list) or not items or len(items) > 50:
        raise ValueError("items must contain between 1 and 50 entries")

    normalized = []
    total = Decimal(0)
    for item in items:
        if not isinstance(item, dict):
            raise ValueError("each item must be an object")  # noqa: TRY004
        sku = str(item.get("sku", "")).strip()
        quantity = item.get("quantity")
        try:
            price = Decimal(str(item.get("unit_price")))
        except (InvalidOperation, TypeError):
            raise ValueError("unit_price must be a valid number") from None
        if not sku or len(sku) > 64:
            raise ValueError("sku is required and must be 64 characters or fewer")
        if not isinstance(quantity, int) or isinstance(quantity, bool) or quantity < 1 or quantity > 100:
            raise ValueError("quantity must be an integer between 1 and 100")
        if price <= 0 or price > Decimal(100000):
            raise ValueError("unit_price must be greater than 0 and at most 100000")
        price = price.quantize(Decimal("0.01"))
        normalized.append({"sku": sku, "quantity": quantity, "unit_price": price})
        total += price * quantity
    return normalized, total.quantize(Decimal("0.01"))


def handler(event, _context):
    customer_id = customer_id_from(event)
    if not customer_id:
        return response(401, {"message": "authenticated customer identity is missing"})

    headers = {str(k).lower(): v for k, v in (event.get("headers") or {}).items()}
    idempotency_key = str(headers.get("idempotency-key", "")).strip()
    if not idempotency_key or len(idempotency_key) > 128:
        return response(400, {"message": "Idempotency-Key is required and must be 128 characters or fewer"})

    try:
        payload = parse_body(event)
        items, total = validate_order(payload)
    except (ValueError, json.JSONDecodeError) as exc:
        return response(400, {"message": str(exc)})

    order_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{customer_id}:{idempotency_key}"))
    table = dynamodb.Table(ORDERS_TABLE)
    item = {
        "order_id": order_id,
        "customer_id": customer_id,
        "idempotency_key": idempotency_key,
        "status": "PENDING",
        "items": items,
        "total": total,
    }

    created = True
    try:
        table.put_item(Item=item, ConditionExpression="attribute_not_exists(order_id)")
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
            raise
        created = False
        item = table.get_item(Key={"order_id": order_id}, ConsistentRead=True).get("Item", item)

    sqs.send_message(
        QueueUrl=ORDER_QUEUE_URL,
        MessageBody=json.dumps({"order_id": order_id, "customer_id": customer_id}),
    )
    cloudwatch.put_metric_data(
        Namespace=METRIC_NAMESPACE,
        MetricData=[{"MetricName": "OrdersAccepted", "Value": 1, "Unit": "Count"}],
    )
    return response(
        202 if created else 200,
        {
            "order_id": order_id,
            "status": item.get("status", "PENDING"),
            "duplicate": not created,
            "message": "Order accepted for asynchronous processing",
        },
    )
