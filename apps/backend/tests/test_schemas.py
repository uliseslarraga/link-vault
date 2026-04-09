import pytest
from pydantic import ValidationError

from models.schemas import LinkCreate, LinkUpdate, LinkResponse


class TestLinkCreate:
    def test_valid_url(self):
        link = LinkCreate(url="https://example.com")
        assert str(link.url) == "https://example.com/"

    def test_optional_fields_default_to_none(self):
        link = LinkCreate(url="https://example.com")
        assert link.title is None
        assert link.note is None

    def test_with_title_and_note(self):
        link = LinkCreate(url="https://example.com", title="My link", note="a note")
        assert link.title == "My link"
        assert link.note == "a note"

    def test_invalid_url_raises(self):
        with pytest.raises(ValidationError):
            LinkCreate(url="not-a-url")

    def test_empty_url_raises(self):
        with pytest.raises(ValidationError):
            LinkCreate(url="")


class TestLinkUpdate:
    def test_all_fields_optional(self):
        update = LinkUpdate()
        assert update.title is None
        assert update.note is None

    def test_partial_update(self):
        update = LinkUpdate(title="New title")
        assert update.title == "New title"
        assert update.note is None


class TestLinkResponse:
    def test_screenshot_url_optional(self):
        from uuid import uuid4
        from datetime import datetime, timezone

        data = {
            "id": uuid4(),
            "url": "https://example.com/",
            "title": None,
            "note": None,
            "screenshot_url": None,
            "created_at": datetime.now(timezone.utc),
            "updated_at": None,
        }
        response = LinkResponse(**data)
        assert response.screenshot_url is None
