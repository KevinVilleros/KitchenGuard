# Glossary — CocinaP

Terms, acronyms and concepts used in the project.

---

## A

- **ADR (Architecture Decision Record):** a record of an architecture decision
  with its context and consequences.
- **API key:** secret key that authenticates the mobile app against the backend.
- **APK:** installable Android package.
- **AAB (Android App Bundle):** publishing format for Google Play.

## C

- **COCO:** object dataset (including the "person" class) used by the phone model.
- **CORS:** cross-origin access policy for the HTTP server.
- **CI/CD:** continuous integration and delivery.

## D

- **On-device detection:** inference run on the device itself, no cloud.
- **Unattended (kitchen):** a situation where no person is in the cooking area
  while cooking.

## E

- **SSE (Server-Sent Events):** one-way server→client channel for real-time
  events (alarms).

## F

- **FCM (Firebase Cloud Messaging):** push messaging; **removed** from the mobile
  client.
- **Flutter:** cross-platform UI framework used by the mobile app.

## I

- **iOS deployment target:** minimum supported iOS version (17.0).
- **IPA:** installable iOS package.

## M

- **mDNS (multicast DNS):** local network service discovery
  (`_cocinap._tcp.local.`).
- **MJPEG (Motion JPEG):** video stream made of consecutive JPEG frames.
- **Remote camera mode:** a phone receives the authenticated Windows camera
  stream over Tailscale.
- **Standalone mode:** the app monitors a local device or IP camera.

## P

- **Provider:** Flutter state-management pattern used in the app.
- **MoveNet Lightning:** single-person pose model used on Windows.
- **ONNX Runtime:** model inference runtime used by the Windows target.

## R

- **Rate limiting:** cap on requests per unit of time.
- **ROI (Region of Interest):** area of interest in the frame (e.g. the stove).
- **RTSP:** IP camera streaming protocol supported by standalone mobile mode.

## S

- **SEMVER:** semantic versioning `MAJOR.MINOR.PATCH`.
- **Sideloadly:** tool to install an `.ipa` on iPhone without the App Store.
- **Tailscale Serve:** private HTTPS proxy from a tailnet to the Windows host.
- **STOVE_ZONE:** legacy stove-zone configuration.

## T

- **TFLite (TensorFlow Lite):** a model runtime; it is not used by current
  person detection.
- **Monitoring timer:** the window during which the kitchen is watched.

---

## Project naming conventions

| Code term | Meaning |
|---|---|
| `StandaloneProvider` | Standalone mode state |
| `ServerProvider` | PC connection state |
| `PersonDetector` | Platform-specific on-device pose detector |
| `RemoteCameraServer` | Authenticated Windows camera host (port 8080) |
