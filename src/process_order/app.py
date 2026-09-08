import json
import os
from datetime import UTC, datetime
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

ORDERS_TABLE = os.environ.get("ORDERS_TABLE", "orders")
RECEIPTS_BUCKET = os.environ.get("RECEIPTS_BUCKET", "")
EVENT_BUS_NAME = os.environ.get("EVENT_BUS_NAME", "default")
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "Portfolio/Orders")

dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")
events = boto3.client("events")
cloudwatch = boto3.client("cloudwatch")


class DecimalEncoder(json.JSONEncoder):
    def default(self, value):
        if isinstance(value, Decimal):
            return float(value)
        return super().default(value)


def process_record(record):
    body = json.loads(record["body"])
    if body.get("simulate_failure"):
        raise RuntimeError("controlled failure drill")

    order_id = body["order_id"]
    table = dynamodb.Table(ORDERS_TABLE)
    order = table.get_item(Key={"order_id": order_id}, ConsistentRead=True).get("Item")
    if not order:
        raise ValueError(f"order {order_id} does not exist")
    if order.get("status") == "PROCESSED":
        return

    processed_at = datetime.now(UTC).isoformat()
    receipt = {
        "order_id": order_id,
        "customer_id": order["customer_id"],
        "items": order["items"],
        "total": order["total"],
        "processed_at": processed_at,
    }
    receipt_key = f"receipts/{order_id}.json"
    s3.put_object(
        Bucket=RECEIPTS_BUCKET,
        Key=receipt_key,
        Body=json.dumps(receipt, cls=DecimalEncoder).encode("utf-8"),
        ContentType="application/json",
        ServerSideEncryption="AES256",
    )

    try:
        table.update_item(
            Key={"order_id": order_id},
            UpdateExpression="SET #status = :processed, processed_at = :at, receipt_key = :key",
            ConditionExpression="#status <> :processed",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":processed": "PROCESSED",
                ":at": processed_at,
                ":key": receipt_key,
            },
        )
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
            raise
        return

    events.put_events(
        Entries=[
            {
                "Source": "com.rakeem.orders",
                "DetailType": "OrderProcessed",
                "Detail": json.dumps({"order_id": order_id, "processed_at": processed_at}),
                "EventBusName": EVENT_BUS_NAME,
            }
        ]
    )
    cloudwatch.put_metric_data(
        Namespace=METRIC_NAMESPACE,
        MetricData=[{"MetricName": "OrdersProcessed", "Value": 1, "Unit": "Count"}],
    )


def handler(event, _context):
    failures = []
    for record in event.get("Records", []):
        try:
            process_record(record)
        except Exception as exc:  # noqa: BLE001 - isolate individual SQS record failures
            print(json.dumps({"level": "ERROR", "message_id": record.get("messageId"), "error": str(exc)}))
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}
