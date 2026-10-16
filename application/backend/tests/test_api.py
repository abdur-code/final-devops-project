def test_health(client):
    assert client.get("/health").json() == {"status": "UP"}


def test_ready(client):
    resp = client.get("/ready")
    assert resp.status_code == 200
    assert resp.json()["status"] == "READY"


def test_metrics_exposed(client):
    client.get("/api/items")
    body = client.get("/metrics").text
    assert "http_requests_total" in body


def test_create_item_uppercases_sku(item):
    assert item["sku"] == "BOLT-M8"
    assert item["low_stock"] is False


def test_duplicate_sku_rejected(client, item):
    resp = client.post("/api/items", json={"sku": "BOLT-M8", "name": "dup", "quantity": 1})
    assert resp.status_code == 409


def test_validation_rejects_negative_quantity(client):
    resp = client.post("/api/items", json={"sku": "X1", "name": "bad", "quantity": -3})
    assert resp.status_code == 422


def test_get_and_list(client, item):
    assert client.get(f"/api/items/{item['id']}").json()["name"] == "M8 hex bolt"
    assert len(client.get("/api/items").json()) == 1


def test_get_missing_returns_404(client):
    assert client.get("/api/items/9999").status_code == 404


def test_update_marks_low_stock(client, item):
    resp = client.put(f"/api/items/{item['id']}", json={"quantity": 10})
    assert resp.status_code == 200
    assert resp.json()["low_stock"] is True
    low = client.get("/api/items", params={"low_stock": "true"}).json()
    assert [i["sku"] for i in low] == ["BOLT-M8"]


def test_stats(client, item):
    stats = client.get("/api/items/stats").json()
    assert stats["total_skus"] == 1
    assert stats["total_units"] == 120
    assert stats["inventory_value"] == "30.00"


def test_delete(client, item):
    assert client.delete(f"/api/items/{item['id']}").status_code == 204
    assert client.get(f"/api/items/{item['id']}").status_code == 404


def test_load_endpoint(client):
    assert client.get("/api/load", params={"ms": 5}).json()["burned_ms"] == 5
