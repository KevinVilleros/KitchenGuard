# Remote camera API — CocinaP Windows

The Windows app provides a small authenticated HTTP API for the mobile app's
remote-camera mode. Use Tailscale Serve to make it available over a private
HTTPS address; do not expose port 8080 to the public Internet.

- **Local base URL:** `http://127.0.0.1:8080`
- **Remote URL:** HTTPS Tailscale Serve address ending in `.ts.net`
- **Authentication:** `X-API-Key` header

The Windows app generates a 32-byte random key and stores it in secure storage.
Copy it from Windows **Settings** and enter it in the mobile app. The key must
not be placed in a URL or shared outside the trusted tailnet.

## `GET /api/info`

Returns the host application and camera status.

```http
GET /api/info HTTP/1.1
Host: cocina-pc.example.ts.net
X-API-Key: <64 hexadecimal characters>
```

Successful response (`200`):

```json
{
  "app": "CocinaP",
  "auth_required": true,
  "camera_ok": true
}
```

`camera_ok` is true only when the selected camera has produced a recent frame.
An invalid or missing key returns `401 Unauthorized`.

## `GET /api/stream`

Returns an MJPEG stream with content type
`multipart/x-mixed-replace; boundary=frame`. Each part contains a JPEG frame.
The stream ends if the camera stops producing recent frames or the client
disconnects.

An invalid or missing key returns `401 Unauthorized`. If no recent camera frame
is available when the request starts, the server returns `503 Service
Unavailable`.

The Windows webcam implementation currently captures snapshots at about one
frame per second. IP camera stream rate depends on that camera and its URL.

## Supported requests and headers

Only `GET` is supported. Unknown routes return `404`; other HTTP methods return
`405`. Responses include `Cache-Control: no-store` and
`X-Content-Type-Options: nosniff`.

Remote access is designed for Tailscale Serve. Keep both devices in the same
private tailnet and do not use Tailscale Funnel or router port forwarding.
