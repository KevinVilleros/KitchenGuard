# ADR 0003 — On-device person detection

## Status
Accepted

## Context

Standalone mode must detect whether people are in the kitchen without depending
on a PC or the cloud, for privacy and availability.

## Decision

Run inference locally with platform-supported pose models: Google ML Kit Pose
Detection on Android/iOS and MoveNet Lightning through ONNX Runtime on Windows.
The Windows model is bundled as `assets/models/movenet_lightning.onnx` and
produces a single 17-keypoint pose.

Only **people** are detected. Frames are not sent to a cloud service. Windows
webcam capture is snapshot-based at about one frame per second.

## Consequences

**Positive**
- Full privacy: no frame leaves the device.
- Works without a network.
- Low consumption and acceptable latency on modern phones.

**Negative**
- The COCO model does not cover fire/smoke.
- Windows and mobile use different models and may produce different results.

**Neutral**
- The alert logic (person absence) lives in `StandaloneProvider`.
