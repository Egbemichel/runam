import json
import logging
import time
from typing import Any, Dict, Iterable

import requests
from requests.exceptions import RequestException

logger = logging.getLogger(__name__)


def send_webhook(url: str, payload: Dict[str, Any], headers: Dict[str, str] | None = None, retries: int = 3, timeout: int = 5) -> bool:
    """Send a JSON webhook POST to the given URL with simple retries.

    Returns True on HTTP 2xx, False otherwise.
    """
    if not url:
        logger.debug("send_webhook: no url provided")
        return False

    headers = headers or {"Content-Type": "application/json"}

    logger.info("send_webhook: sending payload to %s", url)

    for attempt in range(1, retries + 1):
        try:
            logger.debug("send_webhook attempt %s for %s", attempt, url)
            resp = requests.post(url, json=payload, headers=headers, timeout=timeout)
            if 200 <= resp.status_code < 300:
                logger.info("send_webhook: success %s status=%s", url, resp.status_code)
                return True
            logger.warning("Webhook POST to %s returned %s: %s", url, resp.status_code, resp.text)
        except RequestException as e:
            logger.exception("Webhook POST to %s failed on attempt %s: %s", url, attempt, e)

        # backoff
        time.sleep(1 * attempt)

    logger.error("send_webhook: exhausted retries for %s", url)
    return False


def send_to_multiple(urls: Iterable[str], payload: Dict[str, Any]) -> Dict[str, bool]:
    results = {}
    for u in urls:
        results[u] = send_webhook(u, payload)
        logger.info('send_to_multiple: webhook %s result=%s', u, results[u])
    return results
