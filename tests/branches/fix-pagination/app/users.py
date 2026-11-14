"""User operations built on the API client."""
from app import config
from app.api_client import ApiClient


class UserService:
    def __init__(self, client=None):
        self.client = client or ApiClient()

    def get_user(self, user_id):
        return self.client.get(f"/users/{user_id}")

    def list_all(self):
        """Return every user by walking the paginated /users endpoint."""
        users = []
        page = 1
        while True:
            batch = self.client.get(f"/users?page={page}&size={config.PAGE_SIZE}")
            users.extend(batch["items"])
            if page >= batch["total_pages"]:
                break
            page += 1
        return users

    def rename(self, user_id, name):
        return self.client.put(f"/users/{user_id}", {"name": name})
