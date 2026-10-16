import logging
import time
from decimal import Decimal

from fastapi import Depends, FastAPI, HTTPException, Query, Request, status
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .logging_config import configure_logging
from .models import Item
from .schemas import ItemCreate, ItemOut, ItemUpdate, StatsOut

configure_logging(settings.log_level)
log = logging.getLogger("stockpilot")

app = FastAPI(title=settings.app_name, version=settings.app_version)

# default buckets start at 100 ms, too coarse for millisecond requests
LATENCY_BUCKETS = (0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5)
Instrumentator(excluded_handlers=["/metrics", "/health", "/ready"]).instrument(
    app, latency_lowr_buckets=LATENCY_BUCKETS
).expose(app, endpoint="/metrics", include_in_schema=False)

INVENTORY_OPS = Counter(
    "stockpilot_inventory_operations_total",
    "Inventory write operations",
    ["operation"],
)
QUIET_PATHS = ("/health", "/ready", "/metrics")


@app.middleware("http")
async def request_log(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    if request.url.path not in QUIET_PATHS:
        log.info(
            "request",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "duration_ms": round((time.perf_counter() - start) * 1000, 2),
            },
        )
    return response


@app.get("/")
def root():
    return {"service": settings.app_name, "version": settings.app_version, "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "UP"}


@app.get("/ready")
def ready(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001
        log.error("readiness check failed: %s", exc)
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return {"status": "READY"}


@app.get("/api/info")
def info():
    return {"version": settings.app_version, "environment": settings.app_env}


def _get_or_404(db: Session, item_id: int) -> Item:
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@app.get("/api/items", response_model=list[ItemOut])
def list_items(low_stock: bool = False, db: Session = Depends(get_db)):
    stmt = select(Item).order_by(Item.name)
    if low_stock:
        stmt = stmt.where(Item.quantity <= Item.reorder_level)
    return list(db.scalars(stmt))


@app.get("/api/items/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)):
    total_skus, total_units, value = db.execute(
        select(
            func.count(Item.id),
            func.coalesce(func.sum(Item.quantity), 0),
            func.coalesce(func.sum(Item.quantity * Item.unit_price), 0),
        )
    ).one()
    low = db.scalar(select(func.count(Item.id)).where(Item.quantity <= Item.reorder_level))
    return StatsOut(
        total_skus=total_skus,
        total_units=int(total_units),
        low_stock=low or 0,
        inventory_value=Decimal(str(value)).quantize(Decimal("0.01")),
    )


@app.get("/api/items/{item_id}", response_model=ItemOut)
def get_item(item_id: int, db: Session = Depends(get_db)):
    return _get_or_404(db, item_id)


@app.post("/api/items", response_model=ItemOut, status_code=status.HTTP_201_CREATED)
def create_item(payload: ItemCreate, db: Session = Depends(get_db)):
    item = Item(**payload.model_dump())
    item.sku = item.sku.upper()
    db.add(item)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="SKU already exists") from exc
    db.refresh(item)
    INVENTORY_OPS.labels("create").inc()
    log.info("item created", extra={"sku": item.sku, "item_id": item.id})
    return item


@app.put("/api/items/{item_id}", response_model=ItemOut)
def update_item(item_id: int, payload: ItemUpdate, db: Session = Depends(get_db)):
    item = _get_or_404(db, item_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    db.commit()
    db.refresh(item)
    INVENTORY_OPS.labels("update").inc()
    return item


@app.delete("/api/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int, db: Session = Depends(get_db)):
    item = _get_or_404(db, item_id)
    db.delete(item)
    db.commit()
    INVENTORY_OPS.labels("delete").inc()
    log.info("item deleted", extra={"item_id": item_id})


@app.get("/api/load", include_in_schema=False)
def burn_cpu(ms: int = Query(default=200, ge=1, le=1000)):
    if not settings.enable_load_endpoint:
        raise HTTPException(status_code=404, detail="Not found")
    end = time.perf_counter() + ms / 1000
    n = 0
    while time.perf_counter() < end:
        n += 1
    return {"burned_ms": ms, "iterations": n}
