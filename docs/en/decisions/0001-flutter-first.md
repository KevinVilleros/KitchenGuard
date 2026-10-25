# ADR 0001 — Flutter as the main technology

## Status
Accepted

## Context

The project started as a Python desktop system (PySide6 + YOLO) to detect fire,
smoke and unattended cooking on a PC with a camera. However, the end user
(household) needs an alert when they are not in front of the PC, and deploying a
desktop in every kitchen does not scale.

## Decision

Adopt a **Flutter mobile app** (Android and iOS) as the product's main
technology, able to run fully standalone with the phone camera and on-device
detection. The Python desktop becomes an optional complementary backend.

## Consequences

**Positive**
- A single codebase for Android and iOS.
- No PC or Internet required in the main mode.
- Better coverage of household use cases.

**Negative**
- Requires learning/tuning the Flutter and Dart ecosystem.
- Building iOS needs extra infrastructure (see ADR 0006).

**Neutral**
- The Python backend is kept for those who want fire/smoke detection.
