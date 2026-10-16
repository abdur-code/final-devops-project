import os

os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["ENABLE_LOAD_ENDPOINT"] = "true"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(autouse=True)
def fresh_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def item(client):
    resp = client.post(
        "/api/items",
        json={
            "sku": "bolt-m8",
            "name": "M8 hex bolt",
            "quantity": 120,
            "reorder_level": 50,
            "unit_price": "0.25",
        },
    )
    assert resp.status_code == 201
    return resp.json()
