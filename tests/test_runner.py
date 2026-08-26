"""Tests for detection runner module."""

import pytest

from cocinap.detector.runner import DetectionRunner, _EMPTY_DETECTIONS


def test_empty_detections_structure():
    """Verify _EMPTY_DETECTIONS has all required keys."""
    required_keys = [
        "persons", "kitchen_objects", "fire", "fire_coverage",
        "fire_has_valid", "smoke", "smoke_coverage", "pots_on_stove",
        "stove_zone", "frame_size",
    ]
    for key in required_keys:
        assert key in _EMPTY_DETECTIONS, f"Missing key: {key}"


def test_runner_initial_state():
    """Verify DetectionRunner initializes correctly."""
    runner = DetectionRunner()
    assert runner._running is False
    assert runner._thread is None

    latest = runner.get_latest()
    assert latest["persons"] == 0
    assert latest["fire"] == []
    assert latest["smoke"] == []
    assert latest["fire_coverage"] == 0.0
    assert latest["smoke_coverage"] == 0.0


def test_runner_start_stop():
    """Verify runner can start and stop cleanly."""
    runner = DetectionRunner()
    runner.start()
    assert runner._running is True
    assert runner._thread is not None
    assert runner._thread.is_alive()

    runner.stop()
    assert runner._running is False


def test_runner_last_frame_none_initially():
    """Verify last_frame is None before any frame is submitted."""
    runner = DetectionRunner()
    assert runner.last_frame is None


def test_runner_submit_frame():
    """Verify submitted frame is stored."""
    import numpy as np

    runner = DetectionRunner()
    frame = np.zeros((100, 100, 3), dtype=np.uint8)
    runner.submit_frame(frame)

    retrieved = runner._get_frame()
    assert retrieved is not None
    assert retrieved.shape == (100, 100, 3)
