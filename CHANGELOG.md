# Changelog

Todas las versiones notables de CocinaP son documentadas aquí.

Formato basado en [Keep a Changelog](https://keepachangelog.com/) y [Semantic Versioning](https://semver.org/).

---

## [1.0.1] — 2026-07-05

### Corregido
- PyInstaller build: incluidos PIL, matplotlib y sympy como dependencias necesarias de ultralytics/torch
- YOLO_MODEL path resuelve correctamente en modo frozen (sys._MEIPASS)
- WebUI: eliminado HTML dashboard (solo API REST)
- splash de About actualizado a v1.0.1

### Cambiado
- build_app.py: hidden-imports para zeroconf, firebase_admin, PySide6, PIL
- Version bump a 1.0.1

---

## [1.0.0] — 2026-06-?? (Previo)

### Añadido
- Sistema completo funcional con detección YOLO11n
- GUI nativa Windows (PySide6) con 3 pestañas
- App móvil Flutter (Android) con dashboard MJPEG en vivo
- Servidor web embebido con API REST + SSE + MJPEG
- mDNS (Zeroconf) para auto-descubrimiento
- FCM notificaciones push opcionales
- Alarma sonora asíncrona
- Zona de estufa configurable
- Análisis de riesgo multinivel (fuego, humo, cocina desatendida)
- PyInstaller build + Inno Setup installer
- Foreground service Android para notificaciones en background
