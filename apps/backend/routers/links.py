from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from typing import List
from uuid import UUID
import uuid

from db.session import get_db
from models.link import Link
from models.schemas import LinkCreate, LinkUpdate, LinkResponse
from services.s3 import get_presigned_url, delete_screenshot

router = APIRouter()


def _enrich_with_presigned(link: Link) -> LinkResponse:
    """Attach a fresh presigned URL before returning to client."""
    data = LinkResponse.model_validate(link)
    if link.screenshot_key:
        data.screenshot_url = get_presigned_url(link.screenshot_key)
    return data


@router.get("/", response_model=List[LinkResponse])
async def list_links(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Link).order_by(Link.created_at.desc()))
    links = result.scalars().all()
    return [_enrich_with_presigned(l) for l in links]


@router.post("/", response_model=LinkResponse, status_code=status.HTTP_201_CREATED)
async def create_link(
    payload: LinkCreate,
    db: AsyncSession = Depends(get_db),
):
    link = Link(
        id=uuid.uuid4(),
        url=str(payload.url),
        title=payload.title,
        note=payload.note,
    )
    db.add(link)
    await db.commit()
    await db.refresh(link)
    return _enrich_with_presigned(link)


@router.get("/{link_id}", response_model=LinkResponse)
async def get_link(link_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Link).where(Link.id == link_id))
    link = result.scalar_one_or_none()
    if not link:
        raise HTTPException(status_code=404, detail="Link not found")
    return _enrich_with_presigned(link)


@router.patch("/{link_id}", response_model=LinkResponse)
async def update_link(
    link_id: UUID,
    payload: LinkUpdate,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Link).where(Link.id == link_id))
    link = result.scalar_one_or_none()
    if not link:
        raise HTTPException(status_code=404, detail="Link not found")

    if payload.title is not None:
        link.title = payload.title
    if payload.note is not None:
        link.note = payload.note

    await db.commit()
    await db.refresh(link)
    return _enrich_with_presigned(link)


@router.delete("/{link_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_link(
    link_id: UUID,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Link).where(Link.id == link_id))
    link = result.scalar_one_or_none()
    if not link:
        raise HTTPException(status_code=404, detail="Link not found")

    screenshot_key = link.screenshot_key
    await db.execute(delete(Link).where(Link.id == link_id))
    await db.commit()

    # Clean up S3 in background — don't block the response
    if screenshot_key:
        background_tasks.add_task(delete_screenshot, screenshot_key)
