# ADR 0003 — On-device detection with TFLite

## Status
Accepted

## Context

Standalone mode must detect whether people are in the kitchen without depending
on a PC or the cloud, for privacy and availability.

## Decision

Run inference **on the device** with **TensorFlow Lite** (`tflite_flutter`) using
the **SSD MobileNet V2 (COCO)** model bundled in
`assets/models/ssd_mobilenet_v2_coco.tflite`. Input `1x300x300x3` (uint8), up to
20 detections; only the "person" class is used.

Only **people** are detected on the phone. Fire and smoke require the PC backend.

## Consequences

**Positive**
- Full privacy: no frame leaves the device.
- Works without a network.
- Low consumption and acceptable latency on modern phones.

**Negative**
- The COCO model does not cover fire/smoke.
- Lower accuracy than heavier models.

**Neutral**
- The alert logic (person absence) lives in `StandaloneProvider`.
