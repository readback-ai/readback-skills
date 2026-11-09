# Expected answers: docs-usage

**Branch type:** low-logic (docs only). **Size:** small. Expect exactly one question: "What does this change, and does anything else depend on it?"

## Answer

- Adds Setup and Usage sections to `README.md`: the Python version, where settings live (`app/config.py`), examples of `UserService` and of passing a custom `ApiClient`, and that HTTP failures raise `app.http.HttpError`.
- No code changes. Nothing depends on the README.
