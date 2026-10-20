"""Security Audit Logger — Logs all access attempts and security events."""

import os
import threading
import time

import cocinap.config as cfg

_AUDIT_DIR = os.path.join(cfg._APP_DATA, "logs")
_AUDIT_FILE = os.path.join(_AUDIT_DIR, "security_audit.log")
_MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB max


class SecurityAudit:
    """Thread-safe security event logger with file rotation."""

    _instance = None
    _lock_class = threading.Lock()

    def __new__(cls):
        with cls._lock_class:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
                cls._instance._initialized = False
            return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        self._lock = threading.Lock()
        os.makedirs(_AUDIT_DIR, exist_ok=True)

    def log(self, event_type: str, message: str, ip: str = "", details: str = ""):
        """Log a security event.

        Event types: AUTH_SUCCESS, AUTH_FAIL, RATE_LIMIT, BLOCKED_IP,
                     CONFIG_CHANGE, TOKEN_REGISTER, TOKEN_UNREGISTER,
                     ACCESS_DENIED, STARTUP, SHUTDOWN
        """
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{ts}] [{event_type}] ip={ip} {message}"
        if details:
            line += f" | {details}"

        with self._lock:
            try:
                self._rotate_if_needed()
                with open(_AUDIT_FILE, "a", encoding="utf-8") as f:
                    f.write(line + "\n")
            except Exception:
                pass

    def log_auth_success(self, ip: str, endpoint: str):
        self.log("AUTH_SUCCESS", f"acceso autorizado a {endpoint}", ip)

    def log_auth_fail(self, ip: str, endpoint: str):
        self.log("AUTH_FAIL", f"acceso denegado a {endpoint}", ip)

    def log_rate_limit(self, ip: str, endpoint: str):
        self.log("RATE_LIMIT", f"rate limit excedido en {endpoint}", ip)

    def log_blocked(self, ip: str):
        self.log("BLOCKED_IP", f"IP bloqueada por abuso", ip)

    def log_config_change(self, ip: str, key: str, old_val, new_val):
        self.log("CONFIG_CHANGE", f"{key}: {old_val} -> {new_val}", ip)

    def log_token_event(self, ip: str, event: str, token_hash: str):
        self.log("TOKEN_REGISTER" if "register" in event else "TOKEN_UNREGISTER",
                 f"token={token_hash[:16]}...", ip)

    def log_access_denied(self, ip: str, endpoint: str, reason: str):
        self.log("ACCESS_DENIED", f"{endpoint} — {reason}", ip)

    def log_startup(self, api_key_hash: str):
        self.log("STARTUP", f"CocinaP iniciado. API key hash: {api_key_hash[:16]}...")

    def log_shutdown(self):
        self.log("SHUTDOWN", "CocinaP detenido")

    def _rotate_if_needed(self):
        """Rotate audit log if it exceeds max size."""
        try:
            if os.path.exists(_AUDIT_FILE):
                size = os.path.getsize(_AUDIT_FILE)
                if size > _MAX_FILE_SIZE:
                    rotated = _AUDIT_FILE + f".{int(time.time())}"
                    os.rename(_AUDIT_FILE, rotated)
        except Exception:
            pass

    def get_recent(self, lines: int = 100) -> list[str]:
        """Get the last N lines of the audit log."""
        try:
            if not os.path.exists(_AUDIT_FILE):
                return []
            with open(_AUDIT_FILE, "r", encoding="utf-8") as f:
                all_lines = f.readlines()
            return [l.rstrip() for l in all_lines[-lines:]]
        except Exception:
            return []
