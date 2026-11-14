# Expected answers: refactor-transport

**Branch type:** refactor. **Size:** mid-sized: two modules (`app/http.py` replaced by `app/transport.py`, and `app/api_client.py`). Expect 4–5 questions. For What, ask what was refactored; for Failure, ask what it could break.

## What

- Replaces the module-level `request()` function in `app/http.py` with a `Transport` class in the new `app/transport.py`. `app/http.py` is deleted.
- `Transport` now owns URL building (moved from `ApiClient._url`), the timeout and JSON encoding.
- `ApiClient` holds a `Transport` and passes every call to `transport.send`.

## Why

- One object owns everything about talking to the server, so `ApiClient` only maps operations to methods and paths.
- `ApiClient` can be given a fake `Transport`, which makes it easier to test without a network.
- Base URL and timeout become per-instance settings instead of being read from global config on every call.

## Failure (what it could break)

- **Timeout is now fixed at import time.** `Transport`'s `timeout` default is `config.HTTP_TIMEOUT`, evaluated once when the module is imported. Before, `http.request` read `config.HTTP_TIMEOUT` on every request. Code or tests that change the timeout at runtime no longer have any effect.
- Anything importing `app.http` breaks. Nothing in this repo does, but outside callers or docs might.
- `HttpError` moved to `app.transport`, so code catching `app.http.HttpError` must change its import.
- `ApiClient._url` and `ApiClient.base_url` no longer exist.

## Upstream Dependency

- `config.API_BASE_URL` and `config.HTTP_TIMEOUT` values at import time.
- `urllib` for the actual request, as before.

## Side effects

- The timeout timing change above. Behavior is meant to be identical, but this isn't.
- The public location of `HttpError` changed.
