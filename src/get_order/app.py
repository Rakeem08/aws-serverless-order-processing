import json
import os
from decimal import Decimal

import boto3

ORDERS_TABLE = os.environ.get("ORDERS_TABLE", "orders")
dynamodb = boto3.resource("dynamodb")


class DecimalEncoder(json.JSONEncoder):
    def default(self, value):
        if isinstance(value, Decimal):
            return float(value)
        return super().default(value)


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, cls=DecimalEncoder),
    }


def handler(event, _context):
    customer_id = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
        .get("sub")
    )
    if not customer_id:
        return response(401, {"message": "authenticated customer identity is missing"})

    order_id = (event.get("pathParameters") or {}).get("order_id")
    if not order_id:
        return response(400, {"message": "order_id is required"})

    item = (
        dynamodb.Table(ORDERS_TABLE)
        .get_item(Key={"order_id": order_id}, ConsistentRead=True)
        .get("Item")
    )
    if not item or item.get("customer_id") != customer_id:
        return response(404, {"message": "order not found"})
    item.pop("idempotency_key", None)
    return response(200, item)

