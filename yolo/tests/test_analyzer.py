"""Tests for risk analyzer module."""

import time
import pytest

from cocinap.analyzer.risk_analyzer import RiskAnalyzer


@pytest.fixture
def analyzer():
    """Create a fresh RiskAnalyzer for each test."""
    return RiskAnalyzer()


def test_initial_state(analyzer):
    """Verify analyzer initializes with correct defaults."""
    assert analyzer.last_person_time is not None
    assert analyzer.consecutive_no_person == 0
    assert analyzer.consecutive_yes_person == 0
    assert analyzer.fire_history == []
    assert analyzer.smoke_history == []
    assert analyzer.last_alert_time == 0


def test_analyze_empty_detections(analyzer):
    """Verify analyze returns empty alerts for empty detections."""
    dets = {
        "persons": 0, "fire": [], "fire_coverage": 0.0, "fire_has_valid": False,
        "smoke": [], "smoke_coverage": 0.0, "pots_on_stove": [],
    }
    alerts = analyzer.analyze(dets)
    assert isinstance(alerts, list)


def test_person_tracking(analyzer):
    """Verify person presence updates last_person_time."""
    dets_with_person = {
        "persons": 1, "fire": [], "fire_coverage": 0.0, "fire_has_valid": False,
        "smoke": [], "smoke_coverage": 0.0, "pots_on_stove": [],
    }

    before = analyzer.last_person_time
    time.sleep(0.05)

    analyzer.analyze(dets_with_person)
    analyzer.analyze(dets_with_person)

    assert analyzer.last_person_time > before


def test_no_person_tracking(analyzer):
    """Verify absence of person increments consecutive counter."""
    dets_no_person = {
        "persons": 0, "fire": [], "fire_coverage": 0.0, "fire_has_valid": False,
        "smoke": [], "smoke_coverage": 0.0, "pots_on_stove": [],
    }

    analyzer.analyze(dets_no_person)
    assert analyzer.consecutive_no_person >= 1


def test_reset_session(analyzer):
    """Verify reset_session clears person tracking."""
    dets_with_person = {
        "persons": 1, "fire": [], "fire_coverage": 0.0, "fire_has_valid": False,
        "smoke": [], "smoke_coverage": 0.0, "pots_on_stove": [],
    }

    analyzer.analyze(dets_with_person)
    analyzer.reset_session()

    assert analyzer.consecutive_no_person == 0
    assert analyzer.consecutive_yes_person == 0


def test_severity_level(analyzer):
    """Verify severity level mapping."""
    assert analyzer._severity_level("CRÍTICO") == 3
    assert analyzer._severity_level("ALTO") == 2
    assert analyzer._severity_level("MEDIO") == 1
    assert analyzer._severity_level("BAJO") == 0
    assert analyzer._severity_level("UNKNOWN") == 0


def test_get_status_text_no_alerts(analyzer):
    """Verify status text when no alerts and no persons."""
    dets = {
        "persons": 0, "pots_on_stove": [], "fire": [], "smoke": [],
    }
    text = analyzer.get_status_text([], dets)
    assert "segura" in text.lower() or "cocina" in text.lower()


def test_get_status_color_no_alerts(analyzer):
    """Verify green color when no alerts."""
    color = analyzer.get_status_color([])
    assert color == (0, 255, 0)


def test_fire_level(analyzer):
    """Verify fire level classification."""
    import cocinap.config as cfg

    assert analyzer._get_fire_level(0.0) is None
    assert analyzer._get_fire_level(cfg.FIRE_COVERAGE_LOW) == "BAJO"
    assert analyzer._get_fire_level(cfg.FIRE_COVERAGE_MEDIUM) == "MEDIO"
    assert analyzer._get_fire_level(cfg.FIRE_COVERAGE_HIGH) == "ALTO"
    assert analyzer._get_fire_level(cfg.FIRE_COVERAGE_CRITICAL) == "CRÍTICO"


def test_should_trigger_no_alerts(analyzer):
    """Verify no alarm triggered when no alerts."""
    trigger, alarm_type = analyzer.should_trigger_alarm([])
    assert trigger is False
    assert alarm_type is None


def test_should_trigger_cooldown(analyzer):
    """Verify cooldown prevents rapid re-triggering."""
    analyzer.last_alert_time = time.time()
    alerts = [{"type": "FUEGO", "severity": "ALTO", "message": "test"}]
    trigger, _ = analyzer.should_trigger_alarm(alerts)
    assert trigger is False
