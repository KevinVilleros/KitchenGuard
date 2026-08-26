"""Tests for engine module."""

import time
import pytest

from cocinap.engine import CocinaPEngine


@pytest.fixture
def engine():
    """Create a CocinaPEngine without camera or webui."""
    eng = CocinaPEngine(get_frame_cb=None, web_port=None)
    yield eng
    eng.stop()


def test_engine_initial_state(engine):
    """Verify engine initializes correctly."""
    assert engine.fps == 0
    assert engine.timer_running is False
    assert engine.is_active() is False


def test_timer_start_stop(engine):
    """Verify timer start and stop."""
    engine.timer_start(30)
    state = engine.timer_get_state()
    assert state["running"] is True
    assert state["remaining"] > 0
    assert state["duration"] == 30 * 60

    engine.timer_stop()
    state = engine.timer_get_state()
    assert state["running"] is False
    assert state["remaining"] == 0


def test_timer_pause_resume(engine):
    """Verify timer pause and resume."""
    engine.timer_start(30)
    engine.timer_pause()

    state = engine.timer_get_state()
    assert state["paused"] is True

    engine.timer_resume()
    state = engine.timer_get_state()
    assert state["paused"] is False


def test_timer_pause_idempotent(engine):
    """Verify double pause doesn't cause issues."""
    engine.timer_start(30)
    engine.timer_pause()
    engine.timer_pause()

    state = engine.timer_get_state()
    assert state["paused"] is True


def test_timer_resume_when_not_paused(engine):
    """Verify resume when not paused does nothing."""
    engine.timer_start(30)
    engine.timer_resume()

    state = engine.timer_get_state()
    assert state["paused"] is False


def test_is_active_requires_running_timer(engine):
    """Verify is_active is False without timer."""
    assert engine.is_active() is False

    engine.timer_start(30)
    assert engine.is_active() is True


def test_analyze_inactive_system(engine):
    """Verify analyze returns empty when system inactive."""
    dets = {
        "persons": 0, "fire": [], "fire_coverage": 0.0, "fire_has_valid": False,
        "smoke": [], "smoke_coverage": 0.0, "pots_on_stove": [],
    }
    alerts, trigger, alarm_type = engine.analyze(dets)
    assert alerts == []
    assert trigger is False


def test_track_fps(engine):
    """Verify FPS tracking works."""
    for _ in range(10):
        engine.track_fps()
    assert engine.fps >= 0


def test_get_latest_empty(engine):
    """Verify get_latest returns empty detections."""
    dets = engine.get_latest()
    assert dets["persons"] == 0
    assert dets["fire"] == []


def test_get_unattended_no_pots(engine):
    """Verify get_unattended returns 0 when no pots."""
    dets = {"persons": 0, "pots_on_stove": []}
    assert engine.get_unattended(dets) == 0


def test_get_unattended_with_pots(engine):
    """Verify get_unattended returns minutes when pots present and no person."""
    engine.analyzer.last_person_time = time.time() - 120
    dets = {"persons": 0, "pots_on_stove": [{"a": 1}]}
    unattended = engine.get_unattended(dets)
    assert unattended > 0


def test_engine_stop_no_error(engine):
    """Verify engine stops cleanly without errors."""
    engine.start()
    engine.stop()
