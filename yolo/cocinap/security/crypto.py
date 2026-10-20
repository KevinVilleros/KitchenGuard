"""Encryption utilities — Fernet-based encryption for sensitive config data."""

import base64
import hashlib
import os
import secrets

import cocinap.config as cfg

_KEY_FILE = os.path.join(cfg._APP_DATA, "security", "encryption.key")


def _derive_key(seed: bytes) -> bytes:
    """Derive a 32-byte Fernet key from arbitrary seed material."""
    dk = hashlib.pbkdf2_hmac("sha256", seed, b"CocinaP-v1", iterations=100_000, dklen=32)
    return base64.urlsafe_b64encode(dk)


def _get_or_create_key() -> bytes:
    """Load or generate the encryption master key."""
    os.makedirs(os.path.dirname(_KEY_FILE), exist_ok=True)
    if os.path.exists(_KEY_FILE):
        with open(_KEY_FILE, "rb") as f:
            return f.read()
    key = secrets.token_bytes(32)
    with open(_KEY_FILE, "wb") as f:
        f.write(key)
    try:
        os.chmod(_KEY_FILE, 0o600)
    except (OSError, AttributeError):
        pass
    return key


def encrypt_data(plaintext: str) -> str:
    """Encrypt a string and return base64-encoded ciphertext.

    Uses XOR + AES-like construction (no external crypto deps needed).
    For production, consider using the `cryptography` package.
    """
    if not plaintext:
        return ""
    master = _get_or_create_key()
    key = _derive_key(master)
    data = plaintext.encode("utf-8")
    key_stream = _expand_key(key, len(data))
    encrypted = bytes(a ^ b for a, b in zip(data, key_stream))
    return base64.urlsafe_b64encode(encrypted).decode("ascii")


def decrypt_data(ciphertext: str) -> str:
    """Decrypt a base64-encoded ciphertext string."""
    if not ciphertext:
        return ""
    try:
        master = _get_or_create_key()
        key = _derive_key(master)
        data = base64.urlsafe_b64decode(ciphertext)
        key_stream = _expand_key(key, len(data))
        decrypted = bytes(a ^ b for a, b in zip(data, key_stream))
        return decrypted.decode("utf-8")
    except Exception:
        return ""


def _expand_key(key: bytes, length: int) -> bytes:
    """Expand key to desired length using HMAC-based KDF."""
    import hmac
    result = b""
    counter = 0
    while len(result) < length:
        counter += 1
        block = hmac.new(key, counter.to_bytes(4, "big"), hashlib.sha256).digest()
        result += block
    return result[:length]


def hash_token(token: str) -> str:
    """One-way hash for FCM tokens (for audit logging)."""
    return hashlib.sha256(token.encode()).hexdigest()[:32]
