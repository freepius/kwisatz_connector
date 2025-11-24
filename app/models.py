"""
Database models
"""
from datetime import date, datetime
from pydantic import BaseModel

class Producer(BaseModel):
    """Producer model"""

    code: int
    name: str
    email: str | None = None
    phone: str | None = None
    address: str | None = None
    created_at: date | None = None
    updated_at: datetime | None = None
    is_active: bool = True