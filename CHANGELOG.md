# Changelog

Todas las versiones notables de CocinaP son documentadas aqui.

Formato basado en [Keep a Changelog](https://keepachangelog.com/) y [Semantic Versioning](https://semver.org/).

---

## [1.0.2] - Unreleased

### Added
- `qrcode[pil]` dependency for QR code generation in PC GUI
- Unit tests with pytest (config, engine, analyzer, runner, package)
- GitHub Actions CI workflow (lint + test matrix)
- `.editorconfig` for consistent code style across editors
- `pyproject.toml` complete metadata (authors, classifiers, URLs, ruff config)
- Version info in `cocinap/__init__.py`
- Dev dependencies in `pyproject.toml` (`pytest`, `pytest-cov`, `ruff`)

### Changed
- README.md complete rewrite with professional formatting
- CONTRIBUTING.md improved with clearer guidelines
- SECURITY.md improved with structured vulnerability reporting

---

## [1.0.1] - 2026-07-05

### Fixed
- PyInstaller build: incluidos PIL, matplotlib y sympy como dependencias necesarias de ultralytics/torch
- `YOLO_MODEL` path resuelve correctamente en modo frozen (`sys._MEIPASS`)
- WebUI: eliminado HTML dashboard (solo API REST)
- Splash de About actualizado a v1.0.1

### Changed
- `build_app.py`: hidden-imports para zeroconf, firebase_admin, PySide6, PIL
- Version bump a 1.0.1

---

## [1.0.0] - 2026-06-15

### Added
- Sistema completo funcional con deteccion YOLO11n
- GUI nativa Windows (PySide6) con 3 pestanas: Camara, Config, Alarmas
- App movil Flutter (Android) con dashboard MJPEG en vivo
- Servidor web embebido con API REST + SSE + MJPEG
- mDNS (Zeroconf) para auto-descubrimiento en red local
- FCM notificaciones push opcionales
- Alarma sonora asincrona con tres patrones (fuego, humo, desatendida)
- Zona de estufa configurable con widget interactivo
- Analisis de riesgo multinivel (BAJO, MEDIO, ALTO, CRITICO)
- Deteccion de fuego: color HSV, textura, flicker, forma, cobertura
- Deteccion de humo: mascara de color, movimiento, textura, bordes
- Timer de cocina con pausa, resumen y alerta automatica
- PyInstaller build + Inno Setup installer
- Foreground service Android para notificaciones en background
- Inicio automatico con Windows y bandeja de sistema
