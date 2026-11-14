"""Sends requests to the API. Owns the base URL, timeout and JSON encoding."""
import json
import urllib.error
import urllib.request

from app import config


class HttpError(Exception):
    def __init__(self, status, body):
        super().__init__(f"HTTP {status}: {body}")
        self.status = status
        self.body = body


class Transport:
    def __init__(self, base_url=config.API_BASE_URL, timeout=config.HTTP_TIMEOUT):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def send(self, method, path, body=None):
        url = f"{self.base_url}/{path.lstrip('/')}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            url, data=data, method=method, headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as e:
            raise HttpError(e.code, e.read().decode()) from e
        return json.loads(raw) if raw else None
