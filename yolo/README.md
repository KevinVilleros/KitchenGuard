# CocinaP — Archived YOLO Backend

English | [Español](README.es.md)

This directory contains the original PC/Windows backend for CocinaP: fire, smoke
and unattended-kitchen detection with YOLO11n/OpenCV, REST API, MJPEG, SSE,
mDNS discovery and a PySide6 desktop interface.

> **Note:** The Flutter application under `cocinap_mobile/` is now the primary
> implementation. This backend is retained for reference, development and
> optional connected-mode research.

## Requirements

- Python 3.10+
- Windows 10/11 x64 for native GUI and packaging
- x64 CPU with AVX2; 4 GB RAM minimum, 8 GB recommended

## Quick start

```bash
cd yolo
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python main.py gui
```

## Tests

```bash
cd yolo
pytest --tb=short -q
pytest --cov=cocinap --cov-report=html
```

## Documentation

| Document | Description |
|---|---|
| [REST API](docs/API.md) | Backend endpoints |
| [Architecture](docs/ARCHITECTURE.md) | Components and system design |
| [Build](docs/BUILD.md) | Executable and installer packaging |
| [Deployment](docs/DEPLOY.md) | Production operations |

See [CHANGELOG.md](../CHANGELOG.md) and [LICENSE](../LICENSE).
