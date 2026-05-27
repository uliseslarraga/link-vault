import httpx

MICROLINK_API = "https://api.microlink.io/"
TIMEOUT_S = 20


async def capture_screenshot(url: str) -> bytes:
    """Return PNG bytes for the given URL using the microlink.io API."""
    async with httpx.AsyncClient(timeout=TIMEOUT_S) as client:
        api_resp = await client.get(MICROLINK_API, params={"url": url, "screenshot": "true"})
        api_resp.raise_for_status()

        data = api_resp.json()
        screenshot_url = data["data"]["screenshot"]["url"]

        img_resp = await client.get(screenshot_url)
        img_resp.raise_for_status()
        return img_resp.content
