"""Client for the users API. GET is safe to repeat; POST, PUT and DELETE change data."""
from app import config, http


class ApiClient:
    def __init__(self, base_url=config.API_BASE_URL):
        self.base_url = base_url.rstrip("/")

    def _url(self, path):
        return f"{self.base_url}/{path.lstrip('/')}"

    def get(self, path):
        return http.request("GET", self._url(path))

    def post(self, path, body):
        return http.request("POST", self._url(path), body)

    def put(self, path, body):
        return http.request("PUT", self._url(path), body)

    def delete(self, path):
        return http.request("DELETE", self._url(path))
