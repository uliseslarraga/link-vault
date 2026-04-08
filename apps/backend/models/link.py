from sqlalchemy import Column, String, Text, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase
import uuid


class Base(DeclarativeBase):
    pass


class Link(Base):
    __tablename__ = "links"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    url = Column(String(2048), nullable=False)
    title = Column(String(512), nullable=True)
    note = Column(Text, nullable=True)
    screenshot_key = Column(String(512), nullable=True)  # S3 object key
    screenshot_url = Column(Text, nullable=True)          # presigned URL (ephemeral)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
