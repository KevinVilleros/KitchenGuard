"""Tests for version and package metadata."""

import pytest


def test_version_exists():
    """Verify package version is defined."""
    import cocinap
    assert hasattr(cocinap, "__version__")
    assert cocinap.__version__ == "1.0.1"


def test_author_info():
    """Verify author metadata is defined."""
    import cocinap
    assert hasattr(cocinap, "__author__")
    assert cocinap.__author__ == "Kevin Villeros"
    assert hasattr(cocinap, "__email__")
    assert "@" in cocinap.__email__


def test_package_importable():
    """Verify main package is importable."""
    import cocinap
    assert cocinap is not None


def test_submodules_importable():
    """Verify all submodules are importable."""
    from cocinap import config
    from cocinap import engine
    from cocinap import webui
    from cocinap.alarm import sound_alarm
    from cocinap.analyzer import risk_analyzer
    from cocinap.camera import handler
    from cocinap.detector import runner
    from cocinap.utils import visuals

    assert config is not None
    assert engine is not None
    assert webui is not None
    assert sound_alarm is not None
    assert risk_analyzer is not None
    assert handler is not None
    assert runner is not None
    assert visuals is not None
