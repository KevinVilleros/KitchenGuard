# Roadmap — CocinaP

Current status and planned features. This is a living document.

---

## Current status (v1.0.x)

### Done

- Flutter mobile app (Android + iOS) with 5 tabs.
- Standalone mode: phone camera or IP camera.
- **On-device** people detection with TFLite (SSD MobileNet V2 / COCO).
- Monitoring timer with pause/resume/stop.
- Local alerts (sound + vibration) for unattended cooking.
- Local background notifications (Android).
- PC connection: mDNS, QR and manual.
- MJPEG stream from the PC and SSE alarms.
- Python/YOLO backend with fire/smoke detection (archived under `yolo/`).
- Backend security: API key, rate limiting, auditing.
- Bilingual UI (ES/EN).
- Onboarding, camera guide and guided UI tour.
- CI: cloud iOS build and Python CI.

---

## Upcoming versions

### v1.1 — Experience and stability

- [ ] Persistent local alert history on the phone.
- [ ] IP camera picker with local network discovery.
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
- [ ] Support for more backend desktop platforms.

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
