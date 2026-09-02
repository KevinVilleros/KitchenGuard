"""API Key Authentication — Generates and validates API keys for all endpoints."""

import hashlib
import json
import os
import secrets
import time

import cocinap.config as cfg

_API_KEY_FILE = os.path.join(cfg._APP_DATA, "security", "api_key.json")


def generate_api_key() -> str:
    """Generate a cryptographically secure API key (32 bytes hex)."""
    key = secrets.token_hex(32)
    _save_key(key)
    return key


def _save_key(key: str):
    """Persist the API key hash and an encrypted copy for QR display."""
    key_hash = hashlib.sha256(key.encode()).hexdigest()
    from cocinap.security.crypto import encrypt_data
    encrypted = encrypt_data(key)
    key_dir = os.path.dirname(_API_KEY_FILE)
    os.makedirs(key_dir, exist_ok=True)
    with open(_API_KEY_FILE, "w") as f:
        json.dump({"key_hash": key_hash, "key_enc": encrypted, "created": time.time()}, f)
    try:
        os.chmod(_API_KEY_FILE, 0o600)
    except (OSError, AttributeError):
        pass


def load_raw_key() -> str:
    """Return the raw API key (decrypted) so the PC can show it in the QR.

    Returns "" if no key exists or decryption fails.
    """
    if not os.path.exists(_API_KEY_FILE):
        return ""
    try:
        from cocinap.security.crypto import decrypt_data
        with open(_API_KEY_FILE) as f:
            data = json.load(f)
        enc = data.get("key_enc")
        if not enc:
            return ""
        return decrypt_data(enc)
    except Exception:
        return ""


def _load_key_hash() -> str | None:
    """Load the stored API key hash."""
    if not os.path.exists(_API_KEY_FILE):
        return None
    try:
        with open(_API_KEY_FILE) as f:
            data = json.load(f)
        return data.get("key_hash")
    except Exception:
        return None


class ApiKeyAuth:
    """Validates API keys against the stored hash.

    The raw API key is only shown once at generation time.
    All subsequent checks compare SHA-256 hashes.
    """

    def __init__(self):
        self._key_hash = _load_key_hash()
        if self._key_hash is None:
            self._first_run = True
        else:
            self._first_run = False

    def initialize(self) -> str:
        """Generate initial API key on first run. Returns raw key (show to user once)."""
        key = generate_api_key()
        self._key_hash = hashlib.sha256(key.encode()).hexdigest()
        self._first_run = False
        return key

    def get_or_create(self) -> str:
        """Get existing key or create new one. Returns raw key."""
        if self._first_run or self._key_hash is None:
            return self.initialize()
        return ""

    def validate(self, provided_key: str) -> bool:
        """Validate an API key by comparing hashes."""
        if not provided_key or not self._key_hash:
            return False
        provided_hash = hashlib.sha256(provided_key.encode()).hexdigest()
        return secrets.compare_digest(provided_hash, self._key_hash)

    def get_hash(self) -> str | None:
        """Return the stored key hash (for display in UI)."""
        return self._key_hash

    def get_raw_key(self) -> str:
        """Return the raw API key (decrypted), for QR / manual display."""
        return load_raw_key()
