# Security — CocinaP

Security model, implemented controls and operational best practices.

---

## 1. Principles

1. **Privacy by design:** images are processed **on the device** or on **your own
   PC**. They are not sent to external servers.
2. **Minimal surface:** the backend exposes a small, audited REST API.
3. **Trusted network:** the server targets a **home LAN**. Do not expose it to
   the Internet.
4. **Defense in depth:** authentication, rate limiting, input validation and
   auditing.

---

## 2. Threat model (summary)

| Asset | Threat | Mitigation |
|---|---|---|
| Camera video | Unauthorized access | Mandatory API key |
| PC API | Brute force / abuse | Rate limiting + IP blocking + audit |
| Configuration | Parameter tampering | Key allow-list + validated ranges |
| Credentials | API key theft | SHA-256 hash on disk, constant-time compare |
| Network | Internet exposure | LAN binding; do not publish port 8080 |

Out of scope (documented): physical attacks on the device, theft of an unlocked
phone, an already-compromised WiFi network.

---

## 3. Authentication (backend)

- API key generated on first run.
- Stored **SHA-256 hashed**; never plaintext on disk.
- **Constant-time** comparison (prevents timing attacks).
- Sent via the `X-API-Key` header (or `api_key` on streams).
- Failed authentications are written to the audit log.

Related code: `yolo/cocinap/security/auth.py`,
`yolo/cocinap/security/crypto.py`.

---

## 4. Rate limiting and blocking

- Per-IP **token bucket**, separate for reads and writes.
- When exceeded: `429` + `Retry-After`.
- Abusive IPs can be blocked; buckets are cleaned up periodically.

Code: `yolo/cocinap/security/rate_limiter.py`.

---

## 5. Input validation

- JSON body: must be an object; otherwise `400`.
- Max body size: **1 MB** (`413` if exceeded).
- Config keys: **allow-list** (`_CONFIG_KEYS`) with pattern `^[A-Z_]{3,40}$`.
- `STOVE_ZONE_*` clamped to `[0, 1]`; numeric values validated by type.
- Timer parameters limited to `[1, 240]` minutes.

---

## 6. Headers and CORS

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: no-referrer`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- `Cache-Control: no-store, no-cache, must-revalidate`
- CORS restricted (not a wildcard).

---

## 7. Auditing

Logged (code: `yolo/cocinap/security/audit.py`):

- Server startup and shutdown.
- Successful and failed authentications.
- Rate-limit violations.
- Configuration changes (old and new value).
- Token register/unregister events.

Queryable via `GET /api/security/audit` and `GET /api/security/status`.

---

## 8. Mobile app security

- The API key is stored in platform secure storage (Keystore or Keychain).
- A legacy API key from `SharedPreferences` is migrated once and then removed from ordinary preferences.
- Connections go to the configured or mDNS-discovered URL.
- No telemetry and no image upload to the cloud.
- FCM removed: notifications are **local** (Android in background; iOS only with
  the app open).

---

## 9. Operational best practices

- Do **not** publish port 8080 on the router (no port forwarding).
- Use a **trusted WiFi** network with WPA2/WPA3.
- Rotate the API key if you suspect a leak (remove it from the PC and regenerate).
- Keep the OS, Flutter and dependencies up to date.
- Review the audit log if you notice odd behavior.

---

## 10. Reporting a vulnerability

Do not open a public issue. Email **kevinvilleros77@gmail.com** with:

- Detailed description.
- Reproduction steps.
- Proof of concept (if possible).
- Affected version.

Confirmation within **48 hours**. See also [SECURITY.md](../../SECURITY.md) at the
repository root.

---

## 11. Supported versions

| Version | Supported |
|---|---|
| 1.0.x | Yes |

---

See also: [API reference](API.md), [Architecture](ARCHITECTURE.md).
