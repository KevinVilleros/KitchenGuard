import json
import os
import threading
import time
import socket
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

import cv2
import numpy as np

import cocinap.config as cfg


def _build_cfg_keys_js():
    lines = ["const CFG_KEYS = ["]
    for k, l, t, mn, mx, st in cfg.CFG_META:
        lines.append(f"  {{k:'{k}',l:'{l}',min:{mn},max:{mx},step:{st}}},")
    lines.append("];")
    return "\n".join(lines)


_CFG_KEYS_JS = _build_cfg_keys_js()


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


class _Handler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.server_ref = None
        super().__init__(*args, **kwargs)

    def log_message(self, fmt, *args):
        pass

    def _send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _stream_mjpeg(self, webui):
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace;boundary=frame")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        while not webui._stopped:
            frame = webui.get_frame_cb() if webui.get_frame_cb else None
            if frame is not None:
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
            time.sleep(0.066)

    def _stream_sse(self, webui):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", "*")
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

    def do_GET(self):
        path = urlparse(self.path).path.rstrip("/") or "/"
        webui = getattr(self.server, "webui", None)

        if path == "/" or path == "":
            self._send_json({"ok": True, "app": "CocinaP", "docs": "/api/info"})
        elif path == "/api/stream" and webui:
            self._stream_mjpeg(webui)
        elif path == "/api/events" and webui:
            self._stream_sse(webui)
        elif path == "/api/status" and webui:
            self._send_json(webui.get_status())
        elif path == "/api/config" and webui:
            self._send_json(webui.get_config())
        elif path == "/api/alarms" and webui:
            self._send_json(webui.get_alarms())
        elif path == "/api/info" and webui:
            self._send_json({
                "version": "1.0.0",
                "uptime": time.time() - webui._start_time,
                "camera_ok": webui.get_frame_cb is not None,
                "fcm_enabled": cfg.ENABLE_FCM,
                "fcm_tokens": len(cfg.FCM_TOKENS),
                "ips": self._get_local_ips(),
                "port": webui.port,
            })
        else:
            self._send_json({"error": "not found"}, 404)

    def do_POST(self):
        path = self.path.rstrip("/")
        webui = getattr(self.server, "webui", None)

        if path == "/api/config" and webui:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                updates = json.loads(raw)
                ok = webui.update_config(updates)
                self._send_json({"ok": ok})
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, 400)

        elif path == "/api/register_token" and webui:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                data = json.loads(raw)
                token = data.get("token", "")
                if token and token not in cfg.FCM_TOKENS:
                    cfg.FCM_TOKENS.append(token)
                    cfg.save_config()
                self._send_json({"ok": True, "count": len(cfg.FCM_TOKENS)})
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, 400)

        elif path == "/api/unregister_token" and webui:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                data = json.loads(raw)
                token = data.get("token", "")
                if token in cfg.FCM_TOKENS:
                    cfg.FCM_TOKENS.remove(token)
                    cfg.save_config()
                self._send_json({"ok": True, "count": len(cfg.FCM_TOKENS)})
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, 400)

        else:
            self._send_json({"error": "not found"}, 404)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()


class WebUI:
    def __init__(self, host="0.0.0.0", port=8080, get_frame_cb=None):
        self.host = host
        self.port = port
        self.get_frame_cb = get_frame_cb
        self._server = None
        self._thread = None
        self._zc = None
        self._stopped = False
        self._start_time = time.time()
        self._fcm_initialized = False

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
            return dict(self._latest_status)

    def get_config(self):
        sz = cfg.STOVE_ZONE
        result = {k: getattr(cfg, k, None) for k in cfg._CONFIG_KEYS}
        result["STOVE_ZONE_X"] = sz["x"]
        result["STOVE_ZONE_Y"] = sz["y"]
        result["STOVE_ZONE_W"] = sz["w"]
        result["STOVE_ZONE_H"] = sz["h"]
        return result

    def update_config(self, updates):
        try:
            sz_keys = ["STOVE_ZONE_X", "STOVE_ZONE_Y", "STOVE_ZONE_W", "STOVE_ZONE_H"]
            sz_vals = {}
            for k in sz_keys:
                if k in updates:
                    sz_vals[k.split("_")[-1].lower()] = float(updates[k])
                    del updates[k]
            if len(sz_vals) == 4:
                cfg.STOVE_ZONE.update(sz_vals)
            for k, v in updates.items():
                if hasattr(cfg, k):
                    current = getattr(cfg, k)
                    if isinstance(current, bool):
                        setattr(cfg, k, bool(v))
                    elif isinstance(current, int):
                        setattr(cfg, k, int(v))
                    elif isinstance(current, float):
                        setattr(cfg, k, float(v))
                    else:
                        setattr(cfg, k, v)
            cfg.save_config()
            return True
        except Exception as e:
            print(f"[webui] config error: {e}")
            return False

    def get_alarms(self):
        with self._lock:
            return list(self._alarms[-50:])

    def push_status(self, detections, alerts, status_text):
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
            }
            if last_alarm:
                self._alarms.append(last_alarm)

    def send_fcm(self, alerts):
        if not cfg.ENABLE_FCM or not cfg.FCM_TOKENS:
            return
        if not _HAS_FCM:
            return
        if not os.path.exists(cfg.FCM_KEY_FILE):
            print("[fcm] Key file not found:", cfg.FCM_KEY_FILE)
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
                    print(f"[fcm] Error sending to {token[:16]}...: {e}")
                    # Remove invalid token
                    if "UNREGISTERED" in str(e) or "INVALID_ARGUMENT" in str(e):
                        cfg.FCM_TOKENS.remove(token)
                        cfg.save_config()
        except Exception as e:
            print(f"[fcm] Error: {e}")

    def start(self):
        self._stopped = False
        self._start_time = time.time()

        class Handler(_Handler):
            pass

        server = ThreadingHTTPServer((self.host, self.port), Handler)
        server.webui = self
        self._server = server

        self._thread = threading.Thread(target=server.serve_forever, daemon=True)
        self._thread.start()

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
                    properties={"version": "1.0.0"},
                )
                self._zc.register_service(info)
                print(f"[webui] mDNS anunciado como _cocinap._tcp.local.")
            except Exception as e:
                print(f"[webui] mDNS error: {e}")

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
        if self._zc:
            try:
                self._zc.close()
            except Exception:
                pass
        if self._server:
            self._server.shutdown()
            self._server.server_close()
