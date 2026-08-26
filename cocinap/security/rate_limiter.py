"""Token Bucket Rate Limiter — Per-IP request throttling."""

import threading
import time


class _Bucket:
    """Token bucket for a single client."""

    __slots__ = ("tokens", "last_refill", "max_tokens", "refill_rate")

    def __init__(self, max_tokens: float, refill_rate: float):
        self.tokens = max_tokens
        self.last_refill = time.monotonic()
        self.max_tokens = max_tokens
        self.refill_rate = refill_rate

    def consume(self, cost: float = 1.0) -> bool:
        """Try to consume tokens. Returns True if allowed."""
        now = time.monotonic()
        elapsed = now - self.last_refill
        self.tokens = min(self.max_tokens, self.tokens + elapsed * self.refill_rate)
        self.last_refill = now

        if self.tokens >= cost:
            self.tokens -= cost
            return True
        return False


class RateLimiter:
    """Per-IP token bucket rate limiter.

    Default: 60 requests/minute, burst of 20.
    Write endpoints: 10 requests/minute, burst of 5.
    """

    def __init__(
        self,
        read_rpm: float = 60,
        read_burst: float = 20,
        write_rpm: float = 10,
        write_burst: float = 5,
    ):
        self._lock = threading.Lock()
        self._buckets: dict[str, _Bucket] = {}
        self._violations: dict[str, int] = {}
        self._read_rpm = read_rpm
        self._read_burst = read_burst
        self._write_rpm = write_rpm
        self._write_burst = write_burst
        self._blocked_ips: dict[str, float] = {}
        self._blocked_duration = 300  # 5 minutes block after abuse
        self._violation_threshold = 5  # block after 5 consecutive rate limits

    def _get_client_ip(self, handler) -> str:
        """Extract client IP from request headers or socket."""
        forwarded = handler.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        real_ip = handler.headers.get("X-Real-IP")
        if real_ip:
            return real_ip.strip()
        return handler.client_address[0]

    def _get_bucket(self, ip: str, is_write: bool) -> _Bucket:
        """Get or create rate limit bucket for IP."""
        key = f"{ip}:{'w' if is_write else 'r'}"
        if key not in self._buckets:
            if is_write:
                self._buckets[key] = _Bucket(self._write_burst, self._write_rpm / 60.0)
            else:
                self._buckets[key] = _Bucket(self._read_burst, self._read_rpm / 60.0)
        return self._buckets[key]

    def is_blocked(self, ip: str) -> bool:
        """Check if IP is temporarily blocked. Thread-safe."""
        with self._lock:
            return self._is_blocked_locked(ip)

    def _is_blocked_locked(self, ip: str) -> bool:
        """Check if IP is blocked. Caller must hold _lock."""
        block_time = self._blocked_ips.get(ip)
        if block_time and (time.time() - block_time) < self._blocked_duration:
            return True
        if block_time:
            del self._blocked_ips[ip]
        return False

    def _block_ip(self, ip: str):
        """Temporarily block an IP after repeated violations. Caller must hold _lock."""
        self._blocked_ips[ip] = time.time()

    def check(self, handler, is_write: bool = False) -> tuple[bool, int, str]:
        """Check rate limit. Returns (allowed, retry_after_seconds, message)."""
        ip = self._get_client_ip(handler)

        with self._lock:
            if self._is_blocked_locked(ip):
                return False, self._blocked_duration, f"IP {ip} bloqueada temporalmente"
            bucket = self._get_bucket(ip, is_write)
            if bucket.consume():
                self._violations[ip] = 0
                return True, 0, ""
            else:
                retry = int(1.0 / bucket.refill_rate) + 1
                self._violations[ip] = self._violations.get(ip, 0) + 1
                if self._violations[ip] >= self._violation_threshold:
                    self._block_ip(ip)
                    self._violations.pop(ip, None)
                    return False, self._blocked_duration, f"IP {ip} bloqueada por exceso de peticiones"
                return False, retry, f"Rate limit excedido. Reintenta en {retry}s"

    def cleanup(self, max_age: float = 600):
        """Remove stale buckets older than max_age seconds."""
        with self._lock:
            now = time.monotonic()
            stale = [
                k for k, v in self._buckets.items()
                if (now - v.last_refill) > max_age
            ]
            for k in stale:
                del self._buckets[k]
