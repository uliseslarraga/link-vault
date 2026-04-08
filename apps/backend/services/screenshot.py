import logging
from playwright.async_api import async_playwright

logger = logging.getLogger(__name__)

VIEWPORT = {"width": 1280, "height": 800}
TIMEOUT_MS = 15_000


async def capture_screenshot(url: str) -> bytes:
    """Return PNG bytes for the given URL using a headless Chromium browser."""
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--no-sandbox"])
        try:
            page = await browser.new_page(viewport=VIEWPORT)
            await page.goto(url, wait_until="networkidle", timeout=TIMEOUT_MS)
            return await page.screenshot(full_page=False, type="png")
        finally:
            await browser.close()
