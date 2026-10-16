from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, computed_field


class ItemBase(BaseModel):
    sku: str = Field(min_length=2, max_length=40, pattern=r"^[A-Za-z0-9-]+$")
    name: str = Field(min_length=1, max_length=120)
    quantity: int = Field(ge=0)
    reorder_level: int = Field(default=5, ge=0)
    unit_price: Decimal = Field(default=Decimal("0"), ge=0, max_digits=10, decimal_places=2)


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    quantity: int | None = Field(default=None, ge=0)
    reorder_level: int | None = Field(default=None, ge=0)
    unit_price: Decimal | None = Field(default=None, ge=0, max_digits=10, decimal_places=2)


class ItemOut(ItemBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime

    @computed_field
    @property
    def low_stock(self) -> bool:
        return self.quantity <= self.reorder_level


class StatsOut(BaseModel):
    total_skus: int
    total_units: int
    low_stock: int
    inventory_value: Decimal
