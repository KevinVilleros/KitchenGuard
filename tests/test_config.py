"""Tests for configuration module."""

import os
import json
import tempfile

import pytest


def test_config_defaults():
    """Verify that config module loads default values."""
    import cocinap.config as cfg

    assert cfg.CAMERA_ID == 0
    assert cfg.CAMERA_WIDTH == 1280
    assert cfg.CAMERA_HEIGHT == 720
    assert cfg.YOLO_CONFIDENCE == 0.4
    assert cfg.YOLO_IMGSZ == 320
    assert cfg.DETECTION_INTERVAL == 0.15
    assert cfg.WEB_PORT == 8080


def test_stove_zone_defaults():
    """Verify stove zone has correct default values."""
    import cocinap.config as cfg

    assert "x" in cfg.STOVE_ZONE
    assert "y" in cfg.STOVE_ZONE
    assert "w" in cfg.STOVE_ZONE
    assert "h" in cfg.STOVE_ZONE
    assert 0 <= cfg.STOVE_ZONE["x"] <= 1
    assert 0 <= cfg.STOVE_ZONE["y"] <= 1
    assert 0 < cfg.STOVE_ZONE["w"] <= 1
    assert 0 < cfg.STOVE_ZONE["h"] <= 1


def test_alarm_toggles():
    """Verify alarm toggles are enabled by default."""
    import cocinap.config as cfg

    assert cfg.ALARM_UNATTENDED_ENABLED is True
    assert cfg.ALARM_SMOKE_ENABLED is True
    assert cfg.ALARM_FIRE_ENABLED is True


def test_cfg_meta_complete():
    """Verify CFG_META has entries for all critical parameters."""
    import cocinap.config as cfg

    keys = [m[0] for m in cfg.CFG_META]
    assert "YOLO_CONFIDENCE" in keys
    assert "DETECTION_INTERVAL" in keys
    assert "FIRE_COVERAGE_LOW" in keys
    assert "FIRE_COVERAGE_CRITICAL" in keys
    assert "SMOKE_COVERAGE_MIN" in keys
    assert "KITCHEN_TIMER_DURATION" in keys


def test_save_and_load_config(tmp_path, monkeypatch):
    """Verify config save/load roundtrip."""
    import cocinap.config as cfg

    config_file = tmp_path / "test_config.json"
    monkeypatch.setattr(cfg, "CONFIG_FILE", str(config_file))

    original_confidence = cfg.YOLO_CONFIDENCE
    cfg.YOLO_CONFIDENCE = 0.55
    cfg.save_config()
    cfg.YOLO_CONFIDENCE = original_confidence

    assert config_file.exists()

    cfg.load_config()
    assert cfg.YOLO_CONFIDENCE == 0.55

    cfg.YOLO_CONFIDENCE = original_confidence


def test_config_keys_list():
    """Verify _CONFIG_KEYS contains expected entries."""
    import cocinap.config as cfg

    assert "CAMERA_ID" in cfg._CONFIG_KEYS
    assert "WEB_PORT" in cfg._CONFIG_KEYS
    assert "ENABLE_FCM" in cfg._CONFIG_KEYS
    assert "AUTO_START" in cfg._CONFIG_KEYS


def test_fire_coverage_thresholds_ordered():
    """Verify fire coverage thresholds are in ascending order."""
    import cocinap.config as cfg

    assert cfg.FIRE_COVERAGE_LOW < cfg.FIRE_COVERAGE_MEDIUM
    assert cfg.FIRE_COVERAGE_MEDIUM < cfg.FIRE_COVERAGE_HIGH
    assert cfg.FIRE_COVERAGE_HIGH < cfg.FIRE_COVERAGE_CRITICAL


def test_unattended_minutes_ordered():
    """Verify unattended timing thresholds are in ascending order."""
    import cocinap.config as cfg

    assert cfg.UNATTENDED_WARN_MINUTES < cfg.UNATTENDED_WARN_HIGH_MINUTES
    assert cfg.UNATTENDED_WARN_HIGH_MINUTES < cfg.UNATTENDED_ALARM_MINUTES
