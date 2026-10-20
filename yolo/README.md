# CocinaP — Backend YOLO (archivado)

Este directorio contiene el backend original de escritorio (PC / Windows) de
CocinaP: detección de fuego, humo y cocina desatendida con YOLO11n + OpenCV,
servidor web embebido (API REST, MJPEG, SSE), auto-descubrimiento mDNS y GUI
nativa con PySide6.

> **Nota:** La tecnología principal del proyecto es ahora la **app Flutter**
> (`cocinap_mobile/`, ver el [README raíz](../README.md)). Este backend se
> conserva como referencia y para futuras implementaciones (por ejemplo,
> detección con modelos YOLO más avanzados). No se empaqueta con la app móvil.

## Contenido

```
yolo/
├── cocinap/                # Paquete Python del backend
│   ├── alarm/              #   Sistema de alarma sonora
│   ├── analyzer/           #   Analizador de riesgo multinivel
│   ├── camera/             #   Handler de cámara (OpenCV)
│   ├── detector/           #   Detección YOLO + CV (fuego/humo)
│   ├── resources/          #   Iconos y recursos
│   ├── security/           #   Auth, auditoría y rate limiting
│   ├── utils/              #   Utilidades de visualización
│   ├── app.py              #   GUI nativa PySide6
│   ├── config.py           #   Configuración centralizada
│   ├── engine.py           #   Fachada del sistema
│   ├── test_app.py         #   Modo prueba con video
│   └── webui.py            #   Servidor web + mDNS + FCM
├── docs/                   #   API, arquitectura, build y deploy
├── installer/              #   Inno Setup
├── models/                 #   Modelo YOLO11n (yolo11n.pt, no versionado)
├── scripts/                #   Scripts de utilidad
├── tests/                  #   Tests de pytest
├── main.py                 #   Entry point
├── build_app.py            #   Build PyInstaller
├── build_all.py            #   Build completo
├── pyproject.toml          #   Metadata del proyecto
└── requirements.txt        #   Dependencias Python
```

## Requisitos

- Python 3.10+
- Windows 10/11 (64-bit) para la GUI nativa y el empaquetado
- CPU x64 con AVX2; 4 GB de RAM (8 GB recomendado)

## Inicio rápido

```bash
cd yolo

python -m venv venv
venv\Scripts\activate      # Windows
# source venv/bin/activate  # Linux/Mac

pip install -r requirements.txt

# Descargar el modelo YOLO
python -c "from ultralytics import YOLO; YOLO('yolo11n.pt')"
mv yolo11n.pt models/

# GUI nativa + servidor web
python main.py gui

# Solo servidor web (sin GUI)
python main.py --web 8080

# Probar con un video
python main.py test video.mp4
```

## Tests

```bash
cd yolo
pytest --tb=short -q
pytest --cov=cocinap --cov-report=html
```

El flujo de CI (`Python CI`) vive en `.github/workflows/python-ci.yml`, corre
con `working-directory: yolo` y solo se dispara con cambios en `yolo/**`.

## Documentación

| Documento | Descripción |
|---|---|
| [API REST](docs/API.md) | Endpoints para integración con la app móvil |
| [Arquitectura](docs/ARCHITECTURE.md) | Diagramas y diseño del sistema |
| [Build & Deploy](docs/BUILD.md) | Compilar ejecutable e instalador |
| [Guía de despliegue](docs/DEPLOY.md) | Instalación en producción |

Ver también el [CHANGELOG](../CHANGELOG.md) y la licencia en [LICENSE](../LICENSE).
