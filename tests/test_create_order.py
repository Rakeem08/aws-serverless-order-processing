import importlib.util
import json
from pathlib import Path
from unittest.mock import MagicMock


def load_module(name, relative_path):
    path = Path(__file__).parents[1] / relative_path
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


app = load_module("create_order_app", "src/create_order/app.py")


def event(body, key="order-123", customer="customer-1"):
    return {
        "headers": {"idempotency-key": key},
        "body": json.dumps(body),
        "requestContext": {"authorizer": {"jwt": {"claims": {"sub": customer}}}},
    }


def test_rejects_missing_idempotency_key():
    result = app.handler(event({"items": []}, key=""), None)
    assert result["statusCode"] == 400
    assert "Idempotency-Key" in result["body"]


def test_rejects_invalid_quantity():
    result = app.handler(
        event({"items": [{"sku": "BOOK", "quantity": 0, "unit_price": "12.50"}]}),
        None,
    )
    assert result["statusCode"] == 400


def test_accepts_valid_order(monkeypatch):
    table = MagicMock()
    monkeypatch.setattr(app.dynamodb, "Table", lambda _name: table)
    monkeypatch.setattr(app.sqs, "send_message", MagicMock())
    monkeypatch.setattr(app.cloudwatch, "put_metric_data", MagicMock())

    result = app.handler(
        event({"items": [{"sku": "BOOK", "quantity": 2, "unit_price": "12.50"}]}),
        None,
    )
    body = json.loads(result["body"])
    assert result["statusCode"] == 202
    assert body["status"] == "PENDING"
    assert body["duplicate"] is False
    table.put_item.assert_called_once()

