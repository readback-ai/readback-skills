"""In-memory cache where each entry expires after a fixed time-to-live."""
import time


class TTLCache:
    def __init__(self, ttl_seconds, clock=time.monotonic):
        self.ttl = ttl_seconds
        self.clock = clock
        self._entries = {}

    def get(self, key):
        entry = self._entries.get(key)
        if entry is None:
            return None
        value, expires_at = entry
        if self.clock() >= expires_at:
            del self._entries[key]
            return None
        return value

    def set(self, key, value):
        self._entries[key] = (value, self.clock() + self.ttl)

    def invalidate_prefix(self, prefix):
        for key in [k for k in self._entries if k.startswith(prefix)]:
            del self._entries[key]
