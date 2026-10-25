# REST API reference — CocinaP (PC backend)

Documentation of the HTTP API exposed by the CocinaP backend. The mobile app
consumes it in **connected mode**.

- **Base URL:** `http://<PC-IP>:8080`
- **Default port:** `8080` (`WEB_PORT`)
- **Scheme:** HTTP/1.1
- **Auth:** `X-API-Key` header (or `api_key` query param on streams)

---

## 1. Authentication

All endpoints except `/` require an **API key**. The backend generates it on the
first run and stores it SHA-256 hashed; the plain value is shown only once (and
in the PC connection dialog).

```http
X-API-Key: <your-api-key>
```

For streams (MJPEG/SSE), which cannot easily set headers from raw sockets, the
key is passed as a query param:

```
GET /api/stream?api_key=<your-api-key>
```

If the key is invalid the response is:

```json
{ "error": "unauthorized", "message": "API key invalida" }
```

with status `401`.

---

## 2. Rate limiting

The server enforces per-IP limits (token bucket):

- **Reads:** ~`rate_limit_read` requests per minute.
- **Writes (POST):** ~`rate_limit_write` requests per minute.

When exceeded it returns `429` with a `Retry-After` header:

```json
{ "error": "rate_limited", "retry_after": 12, "message": "..." }
```

---

## 3. Security headers

Every response includes:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: no-referrer
Permissions-Policy: camera=(), microphone=(), geolocation=()
Cache-Control: no-store, no-cache, must-revalidate
```

CORS: `Access-Control-Allow-Origin` is restricted (not a wildcard).

---

## 4. Endpoints

### 4.1 `GET /`

Public welcome endpoint (no auth).

```json
{ "ok": true, "app": "CocinaP", "docs": "/api/info" }
```

---

### 4.2 `GET /api/info`

Server information and connection status. Used by the app to validate the
connection.

**Response `200`:**

```json
{
  "version": "1.0.2",
  "uptime": 123.45,
  "camera_ok": true,
  "fcm_enabled": false,
  "fcm_tokens": 0,
  "ips": ["192.168.1.20"],
  "port": 8080,
  "auth_required": true,
  "rate_limit_read": 120,
  "rate_limit_write": 30
}
```

---

### 4.3 `GET /api/status`

Detection and timer status.

**Response `200`:**

```json
{
  "fire_regions": 0,
  "smoke_regions": 0,
  "persons": 1,
  "fire_coverage": 0.0,
  "smoke_coverage": 0.0,
  "fire_stove": false,
  "pots": 0,
  "status_text": "Kitchen attended",
  "last_alarm": null,
  "timer": { "running": false, "remaining": 0 },
  "active": true,
  "alarm_config": { "unattended": true, "smoke": true, "fire": true }
}
```

| Field | Type | Description |
|---|---|---|
| `fire_regions` | int | Fire regions detected |
| `smoke_regions` | int | Smoke regions detected |
| `persons` | int | People detected |
| `fire_coverage` | float | Frame ratio covered by fire |
| `smoke_coverage` | float | Frame ratio covered by smoke |
| `fire_stove` | bool | Fire inside the stove zone |
| `pots` | int | Pots detected on the stove |
| `status_text` | string | Human-readable status |
| `last_alarm` | object\|null | Last alarm |
| `timer` | object | Timer state (`running`, `remaining`, `paused`) |
| `active` | bool | System active |
| `alarm_config` | object | Alarm toggles |

---

### 4.4 `GET /api/stream`

**MJPEG** video stream (`multipart/x-mixed-replace; boundary=frame`).

- JPEG frames at ~30 fps, quality 65, max width 480 px.
- Requires `api_key` (query param or header).
- Emits black frames when there is no camera.

**Note:** long-lived connection; the client must read the stream continuously.

---

### 4.5 `GET /api/events`

**Server-Sent Events** stream with new alarms, one per event:

```
data: {"_id": 12, "time": "14:32:05", "severity": "ALTO", "message": "Kitchen unattended", "type": "unattended"}
```

- Heartbeat every 0.5 s.
- Requires `api_key`.

---

### 4.6 `GET /api/config`

Returns the current configuration (keys from `cocinap/config.py`).

**Response `200` (excerpt):**

```json
{
  "YOLO_CONFIDENCE": 0.4,
  "DETECTION_INTERVAL": 0.15,
  "KITCHEN_TIMER_DURATION": 30,
  "ALARM_UNATTENDED_ENABLED": true,
  "ALARM_SMOKE_ENABLED": true,
  "ALARM_FIRE_ENABLED": true,
  "STOVE_ZONE_X": 0.25,
  "STOVE_ZONE_Y": 0.35,
  "STOVE_ZONE_W": 0.50,
  "STOVE_ZONE_H": 0.45
}
```

---

### 4.7 `POST /api/config`

Updates configuration. Only allowed keys (`_CONFIG_KEYS`) are accepted, and
`STOVE_ZONE_*` must be between 0 and 1.

**Body:**

```json
{ "KITCHEN_TIMER_DURATION": 45, "ALARM_SMOKE_ENABLED": false }
```

**Response `200`:**

```json
{ "ok": true }
```

---

### 4.8 `GET /api/alarms`

Latest alarms (up to 50).

**Response `200`:**

```json
[
  { "_id": 12, "time": "14:32:05", "severity": "ALTO", "message": "Kitchen unattended", "type": "unattended" }
]
```

---

### 4.9 `POST /api/timer/start`

Starts the monitoring timer.

**Body:** `{ "minutes": 30 }` (between 1 and 240; defaults to `KITCHEN_TIMER_DURATION`).

**Response `200`:** `{ "ok": true, "timer": { "running": true, "remaining": 1800 } }`

---

### 4.10 `POST /api/timer/pause` · `POST /api/timer/resume` · `POST /api/timer/stop`

Control the timer. Response `{ "ok": true, "timer": {...} }`.

---

### 4.11 `GET /api/security/status`

Security subsystem status.

```json
{
  "auth_enabled": true,
  "rate_limit_read_rpm": 120,
  "rate_limit_write_rpm": 30,
  "blocked_ips": 0,
  "audit_entries": 42
}
```

---

### 4.12 `GET /api/security/audit`

Last 200 audit entries.

```json
{ "logs": [ { "ts": 1729000000.0, "event": "auth_ok", "ip": "192.168.1.5", "path": "/api/status" } ] }
```

---

## 5. Status codes

| Code | Meaning |
|---|---|
| `200` | OK |
| `400` | Invalid JSON body or out-of-range parameters |
| `401` | Invalid or missing API key |
| `404` | Unknown endpoint |
| `413` | Body too large (max 1 MB) |
| `429` | Rate limit exceeded (`Retry-After`) |

---

## 6. mDNS discovery

The backend advertises the service:

- **Type:** `_cocinap._tcp.local.`
- **Properties:** `version`, `auth=apikey`
- **Port:** `8080`

The mobile app resolves PTR → SRV → A record to obtain `http://IP:port`.

---

## 7. curl examples

```bash
# Server info
curl -H "X-API-Key: YOUR_KEY" http://192.168.1.20:8080/api/info

# Status
curl -H "X-API-Key: YOUR_KEY" http://192.168.1.20:8080/api/status

# Start a 30-min timer
curl -X POST -H "X-API-Key: YOUR_KEY" -H "Content-Type: application/json" \
     -d '{"minutes":30}' http://192.168.1.20:8080/api/timer/start

# Fetch MJPEG stream to a file
curl "http://192.168.1.20:8080/api/stream?api_key=YOUR_KEY" --output frame.mjpeg
```

```powershell
# Windows PowerShell (use the system curl.exe)
& C:\Windows\System32\curl.exe -H "X-API-Key: YOUR_KEY" http://192.168.1.20:8080/api/status
```

---

## 8. Alarm data model

```json
{
  "_id": 12,
  "time": "14:32:05",
  "severity": "ALTO",
  "message": "Kitchen unattended",
  "type": "unattended"
}
```

| Field | Values |
|---|---|
| `severity` | `CRITICO`, `ALTO`, `MEDIO`, `BAJO` |
| `type` | `unattended`, `fire`, `smoke` |

---

## 9. Related

- [Architecture](ARCHITECTURE.md) — client-server flow.
- [Security](SECURITY.md) — auth, rate limiting and auditing in detail.
