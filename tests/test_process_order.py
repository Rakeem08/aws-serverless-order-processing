import importlib.util
import json
from decimal import Decimal
from pathlib import Path
from unittest.mock import MagicMock


def load_module(name, relative_path):
    path = Path(__file__).parents[1] / relative_path
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


app = load_module("process_order_app", "src/process_order/app.py")


def test_partial_batch_response_reports_only_failed_record(monkeypatch):
    table = MagicMock()
    table.get_item.return_value = {
        "Item": {
            "order_id": "good",
            "customer_id": "customer-1",
            "items": [{"sku": "BOOK", "quantity": 1, "unit_price": Decimal("12.50")}],
            "total": Decimal("12.50"),
            "status": "PENDING",
        }
    }
    monkeypatch.setattr(app.dynamodb, "Table", lambda _name: table)
    monkeypatch.setattr(app.s3, "put_object", MagicMock())
    monkeypatch.setattr(app.events, "put_events", MagicMock())
    monkeypatch.setattr(app.cloudwatch, "put_metric_data", MagicMock())
    event = {
        "Records": [
            {"messageId": "good-id", "body": json.dumps({"order_id": "good"})},
            {"messageId": "bad-id", "body": json.dumps({"order_id": "bad", "simulate_failure": True})},
        ]
    }
    result = app.handler(event, None)
    assert result == {"batchItemFailures": [{"itemIdentifier": "bad-id"}]}
    app.s3.put_object.assert_called_once()

