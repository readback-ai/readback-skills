"""Client for the users API. GET is safe to repeat; POST, PUT and DELETE change data."""
from app import config
from app.transport import Transport


class ApiClient:
    def __init__(self, base_url=config.API_BASE_URL, transport=None):
        self.transport = transport or Transport(base_url)

    def get(self, path):
        return self.transport.send("GET", path)

    def post(self, path, body):
        return self.transport.send("POST", path, body)

    def put(self, path, body):
        return self.transport.send("PUT", path, body)

    def delete(self, path):
        return self.transport.send("DELETE", path)
