# ADR 0005 — Retire the archived Python desktop backend

## Status
Accepted; supersedes the earlier decision to keep the archived backend.

## Context

The prior decision archived the Python/YOLO desktop application under `yolo/`.
The product now needs one Flutter implementation for mobile and Windows, with
MoveNet on Windows and an authenticated Tailscale camera stream.

## Decision

Remove the archived Python/YOLO implementation and use the Flutter Windows
target for desktop monitoring and remote video.

## Consequences

**Positive**
- One Flutter application and detection path for mobile and Windows.
- No separate Python desktop runtime or installer to maintain.

**Negative**
- Windows builds require Flutter desktop tooling and native C++ build tools.

**Neutral**
- Windows uses MoveNet Lightning; it does not provide the previous fire/smoke
  detection features.
