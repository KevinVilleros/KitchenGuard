# CocinaP — Backend YOLO (archivado)

Este directorio contiene el backend original de escritorio para Windows: detección
de fuego, humo y cocina desatendida con YOLO11n/OpenCV, API REST, MJPEG, SSE,
mDNS y GUI PySide6.

> La tecnología principal es la app Flutter en `cocinap_mobile/`. Este backend se
> conserva como referencia y queda fuera del empaquetado móvil.

## Requisitos

- Python 3.10+
- Windows 10/11 de 64 bits para la GUI y el empaquetado
- CPU x64 con AVX2; 4 GB de RAM recomendado, 8 GB ideal

## Inicio rápido

```bash
cd yolo
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python main.py gui
```

## Pruebas

```bash
pytest --tb=short -q
pytest --cov=cocinap --cov-report=html
```

## Documentación

- [Versión principal en inglés](README.md)
- [API](docs/API.md)
- [Arquitectura](docs/ARCHITECTURE.md)
- [Build](docs/BUILD.md)
- [Despliegue](docs/DEPLOY.md)
