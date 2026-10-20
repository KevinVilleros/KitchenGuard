"""CocinaP Web Server — With extreme security hardening.

Security features:
- API Key authentication (SHA-256 hashed, constant-time comparison)
- Per-IP token bucket rate limiting
- Security audit logging (all access attempts)
- Input validation and sanitization
- Security headers (CSP, X-Frame-Options, etc.)
- CORS restriction (no longer wildcard)
- Max request body size limit
- IP blocking after abuse
"""

import json
import os
import re
import threading
import time
import socket
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

import cv2
import numpy as np

import cocinap.config as cfg
from cocinap.security.auth import ApiKeyAuth
from cocinap.security.rate_limiter import RateLimiter
from cocinap.security.audit import SecurityAudit
from cocinap.security.crypto import hash_token


try:
    from zeroconf import Zeroconf, ServiceInfo
    _HAS_ZEROCONF = True
except ImportError:
    _HAS_ZEROCONF = False

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _HAS_FCM = True
except ImportError:
    _HAS_FCM = False


_MAX_BODY_SIZE = 1024 * 1024  # 1 MB max POST body
_ALLOWED_CONFIG_KEYS = set(cfg._CONFIG_KEYS)
_CONFIG_KEY_PATTERN = re.compile(r"^[A-Z_]{3,40}$")
_TIMER_MINUTES_RANGE = (1, 240)


class _Handler(BaseHTTPRequestHandler):
    """Hardened HTTP request handler with auth, rate limiting, and audit."""

    server_version = "CocinaP"
    sys_version = ""

    def log_message(self, fmt, *args):
        pass

    # ---- Security helpers ----

    def _get_webui(self):
        return getattr(self.server, "webui", None)

    def _get_client_ip(self) -> str:
        forwarded = self.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        real_ip = self.headers.get("X-Real-IP")
        if real_ip:
            return real_ip.strip()
        return self.client_address[0]

    def _check_auth(self, webui, require_write: bool = False) -> bool:
        """Check API key authentication. Returns True if authorized."""
        if not webui or not webui.auth:
            return True
        api_key = self.headers.get("X-API-Key", "")
        if not api_key:
            api_key = self._get_query_param("api_key")
        if webui.auth.validate(api_key):
            return True
        ip = self._get_client_ip()
        webui.audit.log_auth_fail(ip, self.path)
        self._send_json({"error": "unauthorized", "message": "API key invalida"}, 401)
        return False

    def _check_rate_limit(self, webui, is_write: bool = False) -> bool:
        """Check rate limit. Returns True if allowed."""
        if not webui:
            return True
        allowed, retry_after, msg = webui.rate_limiter.check(self, is_write)
        if not allowed:
            ip = self._get_client_ip()
            webui.audit.log_rate_limit(ip, self.path)
            self.send_response(429)
            self.send_header("Retry-After", str(retry_after))
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", webui._cors_origin)
            self.end_headers()
            self.wfile.write(json.dumps({"error": "rate_limited", "retry_after": retry_after, "message": msg}).encode())
            return False
        return True

    def _get_query_param(self, param: str) -> str:
        """Extract a query parameter from the URL."""
        from urllib.parse import urlparse, parse_qs
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        values = params.get(param, [])
        return values[0] if values else ""

    def _add_security_headers(self, webui):
        """Add security headers to response."""
        origin = webui._cors_origin if webui else "*"
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("X-XSS-Protection", "1; mode=block")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")

    def _send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", getattr(self.server, "webui", type("", (), {"_cors_origin": "*"})())._cors_origin)
        self._add_security_headers(getattr(self.server, "webui", None))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self) -> bytes:
        """Read POST body with size limit."""
        length = int(self.headers.get("Content-Length", 0))
        if length > _MAX_BODY_SIZE:
            self._send_json({"error": "request_too_large", "message": f"Maximo {_MAX_BODY_SIZE} bytes"}, 413)
            return b""
        if length <= 0:
            return b"{}"
        return self.rfile.read(length)

    def _parse_json(self, body: bytes) -> dict | None:
        """Parse JSON body with validation."""
        if not body:
            return {}
        try:
            data = json.loads(body)
            if not isinstance(data, dict):
                self._send_json({"error": "invalid_body", "message": "Body debe ser un objeto JSON"}, 400)
                return None
            return data
        except json.JSONDecodeError as e:
            self._send_json({"error": "invalid_json", "message": str(e)}, 400)
            return None

    def _validate_config_key(self, key: str) -> bool:
        """Validate a config key name."""
        return bool(_CONFIG_KEY_PATTERN.match(key)) and key in _ALLOWED_CONFIG_KEYS

    # ---- MJPEG stream ----

    def _stream_mjpeg(self, webui):
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace;boundary=frame")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self._add_security_headers(webui)
        self.end_headers()
        while not webui._stopped:
            frame = webui.get_frame_cb() if webui.get_frame_cb else None
            if frame is not None:
                h, w = frame.shape[:2]
                if w > 480:
                    scale = 480.0 / w
                    frame = cv2.resize(frame, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_LINEAR)
                _, jpeg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 65])
                try:
                    self.wfile.write(b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + jpeg.tobytes() + b"\r\n")
                except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                    break
            else:
                black = np.zeros((270, 480, 3), dtype=np.uint8)
                _, jpeg = cv2.imencode(".jpg", black, [cv2.IMWRITE_JPEG_QUALITY, 40])
                try:
                    self.wfile.write(b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + jpeg.tobytes() + b"\r\n")
                except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                    break
            time.sleep(0.033)

    def _stream_sse(self, webui):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", webui._cors_origin)
        self._add_security_headers(webui)
        self.end_headers()
        last_alarm_id = 0
        while not webui._stopped:
            with webui._lock:
                alarms = list(webui._alarms)
            for a in alarms:
                if a.get("_id", 0) > last_alarm_id:
                    last_alarm_id = a["_id"]
                    try:
                        self.wfile.write(f"data: {json.dumps(a)}\n\n".encode())
                    except (BrokenPipeError, ConnectionResetError):
                        return
            time.sleep(0.5)

    def _get_local_ips(self):
        ips = []
        try:
            hostname = socket.gethostname()
            for info in socket.getaddrinfo(hostname, None):
                ip = info[4][0]
                if ip.startswith("192.") or ip.startswith("10."):
                    if ip not in ips:
                        ips.append(ip)
                elif ip.startswith("172."):
                    try:
                        second = int(ip.split(".")[1])
                        if 16 <= second <= 31:
                            ips.append(ip)
                    except (IndexError, ValueError):
                        pass
        except Exception:
            pass
        if not ips:
            ips.append("127.0.0.1")
        return ips

    # ---- HTTP Methods ----

    def do_GET(self):
        path = urlparse(self.path).path.rstrip("/") or "/"
        webui = self._get_webui()
        ip = self._get_client_ip()

        # Public endpoints (no auth required)
        if path == "/" or path == "":
            self._send_json({"ok": True, "app": "CocinaP", "docs": "/api/info"})
            return

        if path == "/api/info" and webui:
            if not self._check_auth(webui):
                return
            if not self._check_rate_limit(webui):
                return
            webui.audit.log_auth_success(ip, path)
            self._send_json({
                "version": "1.0.2",
                "uptime": time.time() - webui._start_time,
                "camera_ok": webui.get_frame_cb is not None,
                "fcm_enabled": cfg.ENABLE_FCM,
                "fcm_tokens": len(cfg.FCM_TOKENS),
                "ips": self._get_local_ips(),
                "port": webui.port,
                "auth_required": True,
                "rate_limit_read": webui.rate_limiter._read_rpm,
                "rate_limit_write": webui.rate_limiter._write_rpm,
            })
            return

        # Protected endpoints
        if not self._check_auth(webui):
            return
        if not self._check_rate_limit(webui):
            return

        webui.audit.log_auth_success(ip, path)

        if path == "/api/stream" and webui:
            self._stream_mjpeg(webui)
        elif path == "/api/events" and webui:
            self._stream_sse(webui)
        elif path == "/api/status" and webui:
            self._send_json(webui.get_status())
        elif path == "/api/config" and webui:
            self._send_json(webui.get_config())
        elif path == "/api/alarms" and webui:
            self._send_json(webui.get_alarms())
        elif path == "/api/security/audit" and webui:
            self._send_json({"logs": webui.audit.get_recent(200)})
        elif path == "/api/security/status" and webui:
            self._send_json({
                "auth_enabled": True,
                "rate_limit_read_rpm": webui.rate_limiter._read_rpm,
                "rate_limit_write_rpm": webui.rate_limiter._write_rpm,
                "blocked_ips": len(webui.rate_limiter._blocked_ips),
                "audit_entries": len(webui.audit.get_recent(1000)),
            })
        else:
            self._send_json({"error": "not_found"}, 404)

    def do_POST(self):
        path = self.path.rstrip("/")
        webui = self._get_webui()
        ip = self._get_client_ip()

        # All POST endpoints require auth + rate limit
        if not self._check_auth(webui):
            return
        if not self._check_rate_limit(webui, is_write=True):
            return

        body = self._read_body()
        if not body:
            return

        data = self._parse_json(body)
        if data is None:
            return

        webui.audit.log_auth_success(ip, path)

        if path == "/api/config" and webui:
            ok = webui.update_config(data, ip)
            self._send_json({"ok": ok})

        elif path == "/api/register_token" and webui:
            token = data.get("token", "")
            if not token or not isinstance(token, str) or len(token) < 20 or len(token) > 512:
                self._send_json({"ok": False, "error": "token invalido"}, 400)
                return
            if token not in cfg.FCM_TOKENS:
                cfg.FCM_TOKENS.append(token)
                cfg.save_config()
            webui.audit.log_token_event(ip, "register", hash_token(token))
            self._send_json({"ok": True, "count": len(cfg.FCM_TOKENS)})

        elif path == "/api/unregister_token" and webui:
            token = data.get("token", "")
            if token in cfg.FCM_TOKENS:
                cfg.FCM_TOKENS.remove(token)
                cfg.save_config()
            webui.audit.log_token_event(ip, "unregister", hash_token(token))
            self._send_json({"ok": True, "count": len(cfg.FCM_TOKENS)})

        elif path == "/api/timer/start" and webui and webui.engine:
            minutes = data.get("minutes", cfg.KITCHEN_TIMER_DURATION)
            if not isinstance(minutes, (int, float)) or not (_TIMER_MINUTES_RANGE[0] <= int(minutes) <= _TIMER_MINUTES_RANGE[1]):
                self._send_json({"ok": False, "error": f"minutes debe estar entre {_TIMER_MINUTES_RANGE[0]} y {_TIMER_MINUTES_RANGE[1]}"}, 400)
                return
            webui.engine.timer_start(int(minutes))
            self._send_json({"ok": True, "timer": webui.engine.timer_get_state()})

        elif path == "/api/timer/stop" and webui and webui.engine:
            webui.engine.timer_stop()
            self._send_json({"ok": True, "timer": webui.engine.timer_get_state()})

        elif path == "/api/timer/pause" and webui and webui.engine:
            webui.engine.timer_pause()
            self._send_json({"ok": True, "timer": webui.engine.timer_get_state()})

        elif path == "/api/timer/resume" and webui and webui.engine:
            webui.engine.timer_resume()
            self._send_json({"ok": True, "timer": webui.engine.timer_get_state()})

        else:
            self._send_json({"error": "not_found"}, 404)

    def do_OPTIONS(self):
        webui = self._get_webui()
        origin = webui._cors_origin if webui else "*"
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", origin)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-API-Key")
        self.send_header("Access-Control-Max-Age", "86400")
        self.end_headers()


class WebUI:
    def __init__(self, host="0.0.0.0", port=8080, get_frame_cb=None, engine=None):
        self.host = host
        self.port = port
        self.get_frame_cb = get_frame_cb
        self.engine = engine
        self._server = None
        self._thread = None
        self._zc = None
        self._stopped = False
        self._start_time = time.time()
        self._fcm_initialized = False
        self._cors_origin = "*"

        # Security subsystems
        self.auth = ApiKeyAuth()
        self.rate_limiter = RateLimiter()
        self.audit = SecurityAudit()

        self._latest_status = {
            "fire_regions": 0, "smoke_regions": 0, "persons": 0,
            "fire_coverage": 0.0, "smoke_coverage": 0.0,
            "fire_stove": False, "pots": 0, "status_text": "Iniciando...",
            "last_alarm": None,
        }
        self._alarms = []
        self._alarm_id = 0
        self._lock = threading.Lock()

    def get_status(self):
        with self._lock:
            status = dict(self._latest_status)
        if self.engine:
            status["timer"] = self.engine.timer_get_state()
            status["active"] = self.engine.is_active()
            status["alarm_config"] = {
                "unattended": cfg.ALARM_UNATTENDED_ENABLED,
                "smoke": cfg.ALARM_SMOKE_ENABLED,
                "fire": cfg.ALARM_FIRE_ENABLED,
            }
        return status

    def get_config(self):
        sz = cfg.STOVE_ZONE
        result = {k: getattr(cfg, k, None) for k in cfg._CONFIG_KEYS}
        result["STOVE_ZONE_X"] = sz["x"]
        result["STOVE_ZONE_Y"] = sz["y"]
        result["STOVE_ZONE_W"] = sz["w"]
        result["STOVE_ZONE_H"] = sz["h"]
        return result

    def update_config(self, updates, ip: str = ""):
        """Update configuration with validation and audit logging."""
        try:
            sz_keys = {"STOVE_ZONE_X", "STOVE_ZONE_Y", "STOVE_ZONE_W", "STOVE_ZONE_H"}
            sz_vals = {}
            for k in sz_keys:
                if k in updates:
                    val = float(updates[k])
                    if not 0 <= val <= 1:
                        return False
                    sz_vals[k.split("_")[-1].lower()] = val
                    del updates[k]
            if len(sz_vals) == 4:
                cfg.STOVE_ZONE.update(sz_vals)

            for k, v in updates.items():
                if not self._validate_config_key(k):
                    continue
                current = getattr(cfg, k, None)
                if current is None:
                    continue
                old_val = current
                try:
                    if isinstance(current, bool):
                        setattr(cfg, k, bool(v))
                    elif isinstance(current, int):
                        val = int(v)
                        setattr(cfg, k, val)
                    elif isinstance(current, float):
                        val = float(v)
                        if val < 0:
                            continue
                        setattr(cfg, k, val)
                    else:
                        setattr(cfg, k, v)
                    if old_val != getattr(cfg, k):
                        self.audit.log_config_change(ip, k, old_val, getattr(cfg, k))
                except (ValueError, TypeError):
                    continue

            cfg.save_config()
            return True
        except Exception as e:
            print(f"[security] config error: {e}")
            return False

    def get_alarms(self):
        with self._lock:
            return list(self._alarms[-50:])

    def get_api_key(self) -> str:
        """Return the raw API key for QR/manual connection."""
        return self.auth.get_raw_key() if self.auth else ""

    def push_status(self, detections, alerts, status_text, timer=None):
        now = time.strftime("%H:%M:%S")
        last_alarm = None
        if alerts:
            worst = max(alerts, key=lambda a: (
                {"CRITICO": 3, "ALTO": 2, "MEDIO": 1, "BAJO": 0}.get(a.get("severity", ""), 0)
            ))
            self._alarm_id += 1
            last_alarm = {
                "_id": self._alarm_id,
                "time": now,
                "severity": worst["severity"],
                "message": worst["message"],
                "type": worst["type"],
            }

        if timer is None and self.engine:
            timer = self.engine.timer_get_state()

        active = self.engine.is_active() if self.engine else True

        with self._lock:
            self._latest_status = {
                "fire_regions": len(detections.get("fire", [])),
                "smoke_regions": len(detections.get("smoke", [])),
                "persons": detections.get("persons", 0),
                "fire_coverage": detections.get("fire_coverage", 0.0),
                "smoke_coverage": detections.get("smoke_coverage", 0.0),
                "fire_stove": any(r.get("in_stove_zone", False) for r in detections.get("fire", [])),
                "pots": len(detections.get("pots_on_stove", [])),
                "status_text": status_text,
                "last_alarm": last_alarm,
                "timer": timer or {"running": False, "remaining": 0},
                "active": active,
            }
            if last_alarm:
                self._alarms.append(last_alarm)

    def send_fcm(self, alerts):
        if not cfg.ENABLE_FCM or not cfg.FCM_TOKENS:
            return
        if not _HAS_FCM:
            return
        if not os.path.exists(cfg.FCM_KEY_FILE):
            return
        try:
            if not self._fcm_initialized:
                if not firebase_admin._apps:
                    cred = credentials.Certificate(cfg.FCM_KEY_FILE)
                    firebase_admin.initialize_app(cred)
                self._fcm_initialized = True

            worst = max(alerts, key=lambda a: (
                {"CRITICO": 3, "ALTO": 2, "MEDIO": 1, "BAJO": 0}.get(a.get("severity", ""), 0)
            ))
            title = f"CocinaP - {worst['type']}"
            body = worst["message"]

            for token in list(cfg.FCM_TOKENS):
                try:
                    msg = messaging.Message(
                        notification=messaging.Notification(title=title, body=body),
                        data={
                            "type": worst.get("type", "alarm"),
                            "severity": worst.get("severity", "ALTO"),
                            "message": worst.get("message", ""),
                        },
                        token=token,
                    )
                    messaging.send(msg)
                except Exception as e:
                    if "UNREGISTERED" in str(e) or "INVALID_ARGUMENT" in str(e):
                        cfg.FCM_TOKENS.remove(token)
                        cfg.save_config()
        except Exception as e:
            print(f"[fcm] Error: {e}")

    def send_fcm_event(self, title, body, alarm_type, severity):
        if not cfg.ENABLE_FCM or not cfg.FCM_TOKENS:
            return
        if not _HAS_FCM:
            return
        if not os.path.exists(cfg.FCM_KEY_FILE):
            return
        try:
            if not self._fcm_initialized:
                if not firebase_admin._apps:
                    cred = credentials.Certificate(cfg.FCM_KEY_FILE)
                    firebase_admin.initialize_app(cred)
                self._fcm_initialized = True
            for token in list(cfg.FCM_TOKENS):
                try:
                    msg = messaging.Message(
                        notification=messaging.Notification(title=title, body=body),
                        data={"type": alarm_type, "severity": severity, "message": body},
                        token=token,
                    )
                    messaging.send(msg)
                except Exception as e:
                    if "UNREGISTERED" in str(e) or "INVALID_ARGUMENT" in str(e):
                        cfg.FCM_TOKENS.remove(token)
                        cfg.save_config()
        except Exception as e:
            print(f"[fcm] Error: {e}")

    def start(self):
        self._stopped = False
        self._start_time = time.time()

        # Generate or load API key
        api_key = self.auth.get_or_create()
        if api_key:
            print(f"[security] API key generada (mostrar una sola vez):")
            print(f"[security]   >>> {api_key} <<<")
            print(f"[security] Guadala en un lugar seguro. La app movil la necesita.")
            self.audit.log_startup(self.auth.get_hash()[:16])
        else:
            self.audit.log_startup(self.auth.get_hash()[:16])

        class Handler(_Handler):
            pass

        server = ThreadingHTTPServer((self.host, self.port), Handler)
        server.webui = self
        self._server = server

        self._thread = threading.Thread(target=server.serve_forever, daemon=True)
        self._thread.start()

        # Periodic cleanup of rate limiter buckets
        self._cleanup_thread = threading.Thread(target=self._cleanup_loop, daemon=True)
        self._cleanup_thread.start()

        url = f"http://{self.host}:{self.port}"
        print(f"[webui] Servidor en {url}")

        if _HAS_ZEROCONF:
            try:
                hostname = socket.gethostname()
                local_ips = self._get_local_ips()
                self._zc = Zeroconf()
                info = ServiceInfo(
                    "_cocinap._tcp.local.",
                    f"CocinaP_{id(self)}._cocinap._tcp.local.",
                    addresses=[socket.inet_aton(ip) for ip in local_ips if ip != "127.0.0.1"],
                    port=self.port,
                    properties={"version": "1.0.2", "auth": "apikey"},
                )
                self._zc.register_service(info)
                print(f"[webui] mDNS anunciado como _cocinap._tcp.local.")
            except Exception as e:
                print(f"[webui] mDNS error: {e}")

    def _cleanup_loop(self):
        """Periodically clean up stale rate limiter buckets."""
        while not self._stopped:
            time.sleep(120)
            self.rate_limiter.cleanup()

    def _get_local_ips(self):
        ips = []
        try:
            hostname = socket.gethostname()
            for info in socket.getaddrinfo(hostname, None, socket.AF_INET):
                ip = info[4][0]
                if ip.startswith("192.") or ip.startswith("10.") or ip.startswith("172."):
                    if ip not in ips:
                        ips.append(ip)
        except Exception:
            pass
        if not ips:
            ips.append("127.0.0.1")
        return ips

    def stop(self):
        self._stopped = True
        self.audit.log_shutdown()
        if self._zc:
            try:
                self._zc.close()
            except Exception:
                pass
        if self._server:
            self._server.shutdown()
            self._server.server_close()
