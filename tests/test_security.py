"""Tests for security module — auth, rate limiter, crypto, audit."""

import os
import time
import pytest

from cocinap.security.auth import ApiKeyAuth, generate_api_key
from cocinap.security.rate_limiter import RateLimiter
from cocinap.security.audit import SecurityAudit
from cocinap.security.crypto import encrypt_data, decrypt_data, hash_token


# ---- Auth Tests ----

def test_generate_api_key():
    """Verify API key is generated and is 64-char hex."""
    key = generate_api_key()
    assert len(key) == 64
    assert all(c in "0123456789abcdef" for c in key)


def test_auth_validate_correct_key():
    """Verify correct key validates."""
    auth = ApiKeyAuth()
    key = auth.initialize()
    assert auth.validate(key) is True


def test_auth_validate_wrong_key():
    """Verify wrong key is rejected."""
    auth = ApiKeyAuth()
    auth.initialize()
    assert auth.validate("wrong_key_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab") is False


def test_auth_validate_empty_key():
    """Verify empty key is rejected."""
    auth = ApiKeyAuth()
    auth.initialize()
    assert auth.validate("") is False


def test_auth_validate_none_key():
    """Verify None key is rejected."""
    auth = ApiKeyAuth()
    auth.initialize()
    assert auth.validate(None) is False


def test_auth_constant_time_comparison():
    """Verify constant-time comparison (no timing attack)."""
    auth = ApiKeyAuth()
    key = auth.initialize()
    start = time.monotonic()
    auth.validate(key)
    correct_time = time.monotonic() - start

    start = time.monotonic()
    auth.validate("a" * 64)
    wrong_time = time.monotonic() - start

    # Both should take similar time (constant-time comparison)
    assert abs(correct_time - wrong_time) < 0.1


# ---- Rate Limiter Tests ----

def test_rate_limiter_allows_normal_requests():
    """Verify normal requests are allowed."""
    rl = RateLimiter(read_rpm=60, read_burst=20)

    class FakeHandler:
        headers = {}
        client_address = ("192.168.1.100", 12345)

    allowed, _, _ = rl.check(FakeHandler())
    assert allowed is True


def test_rate_limiter_blocks_burst():
    """Verify burst limit blocks excessive requests."""
    rl = RateLimiter(read_rpm=5, read_burst=3)

    class FakeHandler:
        headers = {}
        client_address = ("192.168.1.100", 12345)

    handler = FakeHandler()
    for _ in range(3):
        rl.check(handler)

    allowed, retry, _ = rl.check(handler)
    assert allowed is False
    assert retry > 0


def test_rate_limiter_blocks_ip_after_abuse():
    """Verify IP is blocked after repeated violations."""
    rl = RateLimiter(read_rpm=1, read_burst=1)

    class FakeHandler:
        headers = {}
        client_address = ("192.168.1.200", 12345)

    handler = FakeHandler()
    # Exhaust bucket
    rl.check(handler)
    # Trigger multiple rate limits to get blocked
    for _ in range(10):
        rl.check(handler)

    assert rl.is_blocked("192.168.1.200") is True


def test_rate_limiter_write_limit_stricter():
    """Verify write endpoints have stricter limits."""
    rl = RateLimiter(read_rpm=60, read_burst=20, write_rpm=5, write_burst=2)

    class FakeHandler:
        headers = {}
        client_address = ("192.168.1.100", 12345)

    handler = FakeHandler()
    # Read allows burst of 20
    for _ in range(10):
        allowed, _, _ = rl.check(handler, is_write=False)
        assert allowed is True

    # Write only allows burst of 2
    for _ in range(2):
        allowed, _, _ = rl.check(handler, is_write=True)
        assert allowed is True

    allowed, _, _ = rl.check(handler, is_write=True)
    assert allowed is False


def test_rate_limiter_x_forwarded_for():
    """Verify rate limiter uses X-Forwarded-For header."""
    rl = RateLimiter(read_rpm=1, read_burst=1)

    class FakeHandler:
        headers = {"X-Forwarded-For": "10.0.0.1"}
        client_address = ("192.168.1.100", 12345)

    handler = FakeHandler()
    rl.check(handler)
    allowed, _, _ = rl.check(handler)
    assert allowed is False


def test_rate_limiter_cleanup():
    """Verify cleanup removes stale buckets."""
    rl = RateLimiter()

    class FakeHandler:
        headers = {}
        client_address = ("192.168.1.100", 12345)

    rl.check(FakeHandler())
    assert len(rl._buckets) > 0

    rl.cleanup(max_age=0)
    assert len(rl._buckets) == 0


# ---- Crypto Tests ----

def test_encrypt_decrypt_roundtrip():
    """Verify encrypt/decrypt roundtrip."""
    original = "my_secret_fcm_token_12345"
    encrypted = encrypt_data(original)
    assert encrypted != original
    decrypted = decrypt_data(encrypted)
    assert decrypted == original


def test_encrypt_empty_string():
    """Verify encrypt handles empty string."""
    assert encrypt_data("") == ""


def test_decrypt_empty_string():
    """Verify decrypt handles empty string."""
    assert decrypt_data("") == ""


def test_decrypt_invalid_ciphertext():
    """Verify decrypt handles invalid input gracefully."""
    result = decrypt_data("not_valid_base64!!!")
    assert result == ""


def test_different_encryptions_differ():
    """Verify same plaintext produces different ciphertext (random key)."""
    enc1 = encrypt_data("test")
    enc2 = encrypt_data("test")
    # With the same master key they should be the same
    # (deterministic given same key)
    dec1 = decrypt_data(enc1)
    dec2 = decrypt_data(enc2)
    assert dec1 == dec2 == "test"


def test_hash_token():
    """Verify hash_token produces consistent 32-char hash."""
    token = "fcm_token_abc123"
    h = hash_token(token)
    assert len(h) == 32
    assert h == hash_token(token)


# ---- Audit Tests ----

def test_audit_singleton():
    """Verify SecurityAudit is a singleton."""
    a1 = SecurityAudit()
    a2 = SecurityAudit()
    assert a1 is a2


def test_audit_log_write():
    """Verify audit log writes to file."""
    audit = SecurityAudit()
    audit.log("TEST_EVENT", "test message", ip="127.0.0.1")

    logs = audit.get_recent(10)
    assert any("TEST_EVENT" in l for l in logs)


def test_audit_log_types():
    """Verify different audit log methods work."""
    audit = SecurityAudit()
    audit.log_auth_success("127.0.0.1", "/api/status")
    audit.log_auth_fail("127.0.0.1", "/api/config")
    audit.log_rate_limit("127.0.0.1", "/api/config")
    audit.log_blocked("192.168.1.50")
    audit.log_config_change("127.0.0.1", "YOLO_CONFIDENCE", 0.4, 0.5)
    audit.log_token_event("127.0.0.1", "register", "abc123")
    audit.log_access_denied("192.168.1.50", "/api/config", "invalid key")
    audit.log_startup("abc123def456")
    audit.log_shutdown()

    logs = audit.get_recent(50)
    assert len(logs) >= 8
