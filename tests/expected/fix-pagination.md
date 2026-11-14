# Expected answers: fix-pagination

**Branch type:** bug fix. **Size:** small: one condition in one function (`UserService.list_all` in `app/users.py`). Expect a short quiz. Why may be skipped, and one concrete edge-case question is fine.

## What

- **The bug:** `list_all` stopped one page early. It broke out of the loop when `page >= total_pages - 1`, so whenever there was more than one page, the last page of users was never fetched. Single-page results were already correct.
- **The fix:** the loop now stops when `page >= total_pages`, so every page is fetched.

## Why

No real design choice. It's a one-condition fix. If asked: the loop keeps the existing approach (fetch pages until the server's `total_pages` is reached) rather than, say, stopping on an empty page.

## Failure

- If `total_pages` is 0 (no users), the loop still fetches page 1 once and stops. That's fine as long as the API returns an empty `items` list.
- If users are added or removed while paging, `total_pages` can change between calls and results can still miss or repeat users.
- A response missing `items` or `total_pages` raises `KeyError`.

## Upstream Dependency

- The API's pages are 1-based, and `total_pages` is the number of pages.
- `config.PAGE_SIZE` sets the page size.

## Side effects

None. Only the loop condition changed.
