# users-app

A small client for the users API.

## Setup

Requires Python 3.9 or later. There are no third-party dependencies.

Settings live in `app/config.py`: the API base URL, the request timeout, and the page size used when listing users.

## Usage

```python
from app.users import UserService

users = UserService()
everyone = users.list_all()
users.rename(42, "Ada")
```

`UserService` uses `ApiClient` under the hood. To talk to a different server, pass your own client:

```python
from app.api_client import ApiClient

users = UserService(ApiClient(base_url="https://staging.example.com"))
```

Requests that fail with an HTTP error raise `app.http.HttpError`, which carries the status code and response body.
