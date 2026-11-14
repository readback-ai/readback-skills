# Expected answers: add-response-cache

**Branch type:** feature. **Size:** large: a new module (`app/cache.py`) plus changes to `app/api_client.py` and `app/config.py`. Expect the full set of questions, all design-level.

## What

Adds an in-memory response cache to `ApiClient`.

- GET responses are stored in a `TTLCache` (new `app/cache.py`), keyed by request path, for `config.CACHE_TTL` (60 seconds). A repeat GET within that time is served from memory with no HTTP call.
- POST, PUT and DELETE still go to the server, then drop every cached entry under the same top-level resource. For example, any write to `/users/...` clears all `/users` entries, including list pages like `/users?page=2`.
- Callers such as `UserService` get caching without any change, because it lives inside `ApiClient`.

## Why

- Cuts repeated network calls for reads of the same data.
- Putting the cache inside `ApiClient` makes it apply to every caller in one place.
- Invalidating by resource prefix instead of exact key is simple and also covers list endpoints that include the changed item, at the cost of clearing more than strictly needed.
- Reasonable alternatives: no cache; a shared external cache (e.g. Redis) that works across processes; HTTP caching headers; exact-key invalidation.

## Failure

- **Stale reads (main failure mode):** invalidation only sees writes made through the same `ApiClient` instance. A write from another process, another client instance, or made directly on the server (out-of-band) isn't seen, so reads return old data for up to `CACHE_TTL` seconds.
- A GET that returns `None` (empty body) is cached but looks like a miss, because `TTLCache.get` returns `None` for both. It's refetched every time.
- If a write raises (e.g. a timeout) after the server applied it, the cache isn't invalidated and stays stale.
- Paths without a leading slash (`users/42`) are cached under a different key and don't match the `/users` prefix, so writes don't clear them.
- Memory grows with the number of distinct paths. Expired entries are only removed when read again.

## Upstream Dependency

- GET must be idempotent and free of side effects, so serving it from memory is equivalent to calling the server.
- All writes to a resource must go through this client for invalidation to work.
- Paths follow the `/<resource>/...` shape, so `_resource` matches cache keys.
- `time.monotonic` for expiry; `config.CACHE_TTL` for the lifetime.

## Side effects

- **`config.HTTP_TIMEOUT` changed from 10 to 30 seconds.** This is unrelated to caching and affects every request through `app/http.py`. Slow or hung requests now take three times longer to fail. A good quiz should surface this.
- `ApiClient.__init__` gained a `cache` argument.
