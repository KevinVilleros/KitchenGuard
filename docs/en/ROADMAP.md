# Roadmap — CocinaP

Current status and planned features. This is a living document.

---

## Current status (v1.0.12-pre)

### Done

- Flutter app for Android, iOS and Windows.
- Standalone mode: phone camera or IP camera.
- Local ONVIF discovery; RTSP and HTTP/MJPEG playback.
- **On-device** person detection with ML Kit on mobile and MoveNet on Windows.
- Monitoring timer with pause/resume/stop.
- Local alerts (sound + vibration) for unattended cooking.
- Local background notifications (Android).
- Remote Windows camera source over Tailscale Serve.
- Authenticated Windows MJPEG stream over Tailscale Serve.
- Bilingual UI (ES/EN).
- Onboarding, camera guide and guided UI tour.
- CI: Android and iOS mobile builds.

---

## Upcoming versions

### Release blockers before publishing v1.0.12

- [ ] Test ONVIF, RTSP and MJPEG against a documented matrix of camera models
  and routers; V380 Pro / AIT36106 has not yet been validated.
- [ ] Run installation, upgrade, permission, alarm, reconnection and background
  QA on physical Android and iPhone devices.
- [ ] Build and validate the Windows app, camera capture, MoveNet inference and
  Tailscale streaming on Windows hardware.
- [ ] Configure production signing and verify signed APK/AAB and IPA artifacts;
  the debug key must not be used for store distribution.
- [ ] Review the licenses for libmpv, FFmpeg/codecs and other native
  dependencies; include required notices and fulfill applicable redistribution
  obligations.
- [ ] Replace the debug key currently configured for release builds with a
  production signing key stored outside the repository.
- [ ] Complete publisher details and outstanding legal-policy fields; verify
  app-store privacy and security declarations.
- [ ] Complete legal/commercial review and publish accurate terms, privacy
  policy, support details and capability descriptions.

ONVIF discovery is implemented, but only finds cameras that advertise ONVIF on
the local network. Compatibility is not guaranteed based on the camera
companion-app brand; an IP address visible in the router does not mean the
camera exposes a compatible video stream. The phone and camera must be able to
communicate directly on the same network.

### v1.1 — Experience and stability

- [ ] Persistent local alert history on the phone.
- [x] IP camera picker with ONVIF discovery and manual fallback.
- [ ] Keep-screen-on mode during monitoring.
- [ ] More widget tests (monitoring, settings, tour).
- [ ] Accessibility: text sizes and contrast.

### v1.2 — Intelligence

- [ ] On-device fire/smoke detection (light model) without a PC.
- [ ] Cooking zone configurable from the phone (on-screen ROI).
- [ ] Multiple simultaneous cameras.

### v1.3 — Integrations

- [ ] Export alarm history (CSV/JSON).
- [ ] Home-screen widgets (monitoring status).
- [ ] Publish a signed Windows desktop package.

### Backlog

- Additional localization (more languages).
- Multi-user / multi-device mode.
- Secure pairing with API key rotation from the app.

---

## How to propose a feature

Open an issue on
[GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues) with:

- Problem or need.
- Proposed solution.
- Alternatives considered.
