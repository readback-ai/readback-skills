"""Client for the users API. GET is safe to repeat; POST, PUT and DELETE change data.

GET responses are cached for config.CACHE_TTL seconds. A write through this
client drops every cached entry for the resource it touched.
"""
from app import config, http
from app.cache import TTLCache


class ApiClient:
    def __init__(self, base_url=config.API_BASE_URL, cache=None):
        self.base_url = base_url.rstrip("/")
        self.cache = cache or TTLCache(config.CACHE_TTL)

    def _url(self, path):
        return f"{self.base_url}/{path.lstrip('/')}"

    def _resource(self, path):
        # "/users/42" and "/users?page=2" both belong to "/users"
        return "/" + path.lstrip("/").split("/")[0].split("?")[0]

    def get(self, path):
        cached = self.cache.get(path)
        if cached is not None:
            return cached
        result = http.request("GET", self._url(path))
        self.cache.set(path, result)
        return result

    def post(self, path, body):
        result = http.request("POST", self._url(path), body)
        self.cache.invalidate_prefix(self._resource(path))
        return result

    def put(self, path, body):
        result = http.request("PUT", self._url(path), body)
        self.cache.invalidate_prefix(self._resource(path))
        return result

    def delete(self, path):
        result = http.request("DELETE", self._url(path))
        self.cache.invalidate_prefix(self._resource(path))
        return result
