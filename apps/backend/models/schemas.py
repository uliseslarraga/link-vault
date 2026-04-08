from pydantic import BaseModel, HttpUrl
from typing import Optional
from datetime import datetime
from uuid import UUID


class LinkCreate(BaseModel):
    url: HttpUrl
    title: Optional[str] = None
    note: Optional[str] = None


class LinkUpdate(BaseModel):
    title: Optional[str] = None
    note: Optional[str] = None


class LinkResponse(BaseModel):
    id: UUID
    url: str
    title: Optional[str]
    note: Optional[str]
    screenshot_url: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime]

    model_config = {"from_attributes": True}
