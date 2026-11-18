# Security — CocinaP

Security model, implemented controls and operational best practices.

---

## 1. Principles

1. **Privacy by design:** images are processed locally on the phone or Windows
   PC; CocinaP does not upload them to a cloud service.
2. **Minimal surface:** the Windows host provides only authenticated camera
   status and MJPEG endpoints.
3. **Trusted network:** remote access is intended to pass through Tailscale
   Serve on a private tailnet; do not expose port 8080 to the public Internet.
4. **Authentication:** the host requires a generated API key for both endpoints.

---

## 2. Threat model (summary)

| Asset | Threat | Mitigation |
|---|---|---|
| Camera stream | Unauthorized access | API key required for every endpoint |
| Credentials | API key exposure | Random 256-bit key stored in secure storage |
| Network | Internet exposure | Tailscale Serve; never publish port 8080 |

Out of scope (documented): physical attacks on the device, theft of an unlocked
phone, an already-compromised WiFi network.

---

## 3. Windows host authentication

- A cryptographically random 32-byte key is generated and stored through
  `flutter_secure_storage`.
- `/api/info` and `/api/stream` require the key in the `X-API-Key` header.
- The comparison is constant-time for keys of the expected length; keys are
  never placed in the URL.
- The server accepts only `GET` requests to those two routes.
- The host does not currently implement per-client rate limiting or an audit
  log.

---

## 4. Mobile app security

- The desktop host API key is stored in platform secure storage.
- A legacy API key from `SharedPreferences` is migrated once and then removed from ordinary preferences.
- The remote Windows client accepts only HTTPS Tailscale `.ts.net` addresses.
- No telemetry and no image upload to the cloud.
- FCM removed: notifications are **local** (Android in background; iOS only with
  the app open).

---

## 5. Operational best practices

- Do **not** publish port 8080 on the router (no port forwarding).
- Use Tailscale Serve on the private tailnet; never use Tailscale Funnel for the
  CocinaP API. Keep the Tailscale account and devices secured, and revoke
  devices that should no longer connect.
- Use a **trusted WiFi** network with WPA2/WPA3.
- Disable remote access immediately if the host key is exposed. Host-key
  rotation is not currently available in the Settings UI.
- Keep the OS, Flutter and dependencies up to date.

---

## 6. Reporting a vulnerability

Do not open a public issue. Email **kevinvilleros77@gmail.com** with:

- Detailed description.
- Reproduction steps.
- Proof of concept (if possible).
- Affected version.

Confirmation within **48 hours**. See also [SECURITY.md](../../SECURITY.md) at the
repository root.

---

## 7. Supported versions

| Version | Supported |
|---|---|
| 1.0.x | Yes |

---

See also: [API reference](API.md), [Architecture](ARCHITECTURE.md).
