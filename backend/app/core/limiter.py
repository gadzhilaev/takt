import os

from slowapi import Limiter
from slowapi.util import get_remote_address

# Disable in automated tests (shared 127.0.0.1 key exhausts login quota across cases).
_enabled = os.environ.get("ENV", "").lower() not in {"test", "testing"}
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)
