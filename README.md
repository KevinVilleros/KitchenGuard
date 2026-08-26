<div align="center">

# CocinaP

### Sistema de Seguridad Inteligente para Cocina

**Detección en tiempo real de fuego, humo y cocina desatendida
mediante visión por computadora y deep learning.**

[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.29-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![YOLO](https://img.shields.io/badge/YOLO-11-00D4AA?style=flat-square&logo=ultralytics&logoColor=white)](https://ultralytics.com)
[![License](https://img.shields.io/badge/License-Comercial-red?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.1-orange?style=flat-square)](CHANGELOG.md)

<img src="docs/CocinaP_Report_v1.0.1.pdf" width="0" height="0" alt=""/>

</div>

---

## Caracteristicas

| Capacidad | Detalle |
|---|---|
| **Deteccion en tiempo real** | Fuego, humo y personas con YOLO11n + OpenCV en CPU |
| **Analisis multinivel** | Niveles BAJO, MEDIO, ALTO, CRITICO con cobertura y persistencia |
| **Zona de estufa configurable** | El usuario define el area de monitoreo porporcional al frame |
| **Alarma sonora asincrona** | Tres patrones distintos (fuego, humo, desatendida) con parada inmediata |
| **Timer de cocina** | Plazo configurable con pausa, resumen y alerta automatica |
| **GUI nativa Windows** | PySide6 (Qt6) con 3 pestanas: Camara, Config, Alarmas |
| **App movil Android** | Flutter con dashboard en vivo, stream MJPEG y notificaciones SSE |
| **Servidor web embebido** | API REST para monitoreo y configuracion remota |
| **Auto-descubrimiento mDNS** | Zeroconf — no requiere configurar IP manualmente |
| **Notificaciones push FCM** | Firebase Cloud Messaging opcionales |
| **Inicio automatico** | Con Windows y bandeja de sistema |
| **Distribucion comercial** | Instalador Inno Setup para usuario final |

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    PC Windows (Python)                       │
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │ Camara   │──▶│ Engine   │──▶│ Web UI   │──▶ API REST    │
│  │ (OpenCV) │   │ (Fachada)│   │ (HTTP    │   MJPEG/SSE    │
│  └──────────┘   └──────────┘   │  Server) │   mDNS         │
│       │              │         └──────────┘               │
│       │              ▼                                    │
│       │      ┌──────────────┐                             │
│       └──────│ Detector     │                             │
│              │ YOLO11 + CV   │                             │
│              │ Fuego/Humo    │                             │
│              └──────────────┘                             │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           GUI Nativa (PySide6)                      │   │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐            │   │
│  │  │ Camara  │ │ Config   │ │ Alarmas  │            │   │
│  │  │(en vivo)│ │(parametros)│ │(historial)│            │   │
│  │  └─────────┘ └──────────┘ └──────────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                    WiFi LAN │ mDNS / HTTP
                              │
┌─────────────────────────────────────────────────────────────┐
│                   App Movil (Flutter/Android)                 │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │Dashboard │  │ Alarmas  │  │ Config   │  │ Settings │  │
│  │MJPEG+Poll│  │SSE Stream│  │Remota    │  │Auto-con. │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Stack Tecnologico

<details>
<summary><b>Backend — PC (Python)</b></summary>

| Componente | Tecnologia | Version |
|---|---|---|
| Lenguaje | Python | 3.10+ |
| GUI Nativa | PySide6 (Qt6) | 6.7+ |
| Deteccion | Ultralytics YOLO11n | 8.3+ |
| Deep Learning | PyTorch (CPU) | 2.5+ |
| Computer Vision | OpenCV | 4.10+ |
| Servidor Web | ThreadingHTTPServer | built-in |
| mDNS | Zeroconf | 0.131+ |
| Push Notifications | Firebase Admin SDK | 6.5+ |
| QR Codes | qrcode + Pillow | 7.4+ |
| Empaquetado | PyInstaller + Inno Setup | — |

</details>

<details>
<summary><b>Frontend Movil (Android/iOS)</b></summary>

| Componente | Tecnologia | Version |
|---|---|---|
| Framework | Flutter | 3.29+ |
| Lenguaje | Dart | 3.2+ |
| Estado | Provider | 6.1+ |
| HTTP | http package | 1.2+ |
| mDNS | multicast_dns | 0.3+ |
| QR Scanner | mobile_scanner | 6.0+ |
| Notificaciones | Firebase Messaging | 15.0+ |
| Background | flutter_background_service | 5.0+ |

</details>

---

## Requisitos del Sistema

### PC (Servidor)
- **SO:** Windows 10/11 (64-bit)
- **CPU:** x64 con AVX2 (Intel Gen 4+ / AMD Ryzen)
- **RAM:** 4 GB minimo, 8 GB recomendado
- **Camara:** USB o integrada (opcional para pruebas sin camara)
- **Red:** WiFi (para comunicacion con app movil)

### Movil (Cliente)
- **Android:** 8.0+ (API 26+)
- **Red:** WiFi en la misma subred que la PC

---

## Inicio Rapido

### PC — Ejecutable (usuario final)

1. Descargar `CocinaP_Setup_v1.0.1.exe`
2. Ejecutar e instalar
3. Iniciar CocinaP desde el acceso directo
4. La GUI nativa se abre con 3 pestanas
5. El servidor web se inicia automaticamente en el puerto 8080

### PC — Desarrollo

```bash
# Clonar repositorio
git clone https://github.com/KevinVilleros/KitchenGuard.git
cd KitchenGuard

# Crear entorno virtual
python -m venv venv
venv\Scripts\activate      # Windows
# source venv/bin/activate  # Linux/Mac

# Instalar dependencias
pip install -r requirements.txt

# Descargar modelo YOLO
python -c "from ultralytics import YOLO; YOLO('yolo11n.pt')"
mv yolo11n.pt models/

# Ejecutar con GUI nativa + servidor web
python main.py gui

# Solo servidor web (sin GUI)
python main.py --web 8080

# Probar con un video
python main.py test video.mp4
```

### App Movil — Desarrollo

```bash
cd cocinap_mobile
flutter pub get
flutter run
```

### App Movil — Compilar APK

```bash
cd cocinap_mobile
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Estructura del Proyecto

```
KitchenGuard/
├── cocinap/                    # Backend Python
│   ├── alarm/                  #   Sistema de alarma sonora
│   ├── analyzer/               #   Analizador de riesgo multinivel
│   ├── camera/                 #   Handler de camara (OpenCV)
│   ├── detector/               #   Deteccion YOLO + CV (fuego/humo)
│   ├── resources/              #   Iconos y recursos
│   ├── utils/                  #   Utilidades de visualizacion
│   ├── app.py                  #   GUI nativa PySide6
│   ├── config.py               #   Configuracion centralizada
│   ├── engine.py               #   Fachada del sistema
│   ├── test_app.py             #   Modo prueba con video
│   └── webui.py                #   Servidor web + mDNS + FCM
├── cocinap_mobile/             # App movil Flutter
│   ├── lib/
│   │   ├── pages/              #   UI: Dashboard, Alarmas, Config
│   │   ├── providers/          #   Estado: Server, Alarmas, Config
│   │   ├── services/           #   API, MJPEG, mDNS, FCM
│   │   └── widgets/            #   Componentes reutilizables
│   ├── android/                #   Config Android
│   └── ios/                    #   Config iOS
├── docs/                       #   Documentacion tecnica
├── installer/                  #   Inno Setup
├── models/                     #   Modelo YOLO11n
├── scripts/                    #   Scripts de utilidad
├── main.py                     #   Entry point
├── build_app.py                #   Build PyInstaller
├── build_all.py                #   Build completo
├── pyproject.toml              #   Metadata del proyecto
└── requirements.txt            #   Dependencias Python
```

---

## API REST

El servidor web expone una API REST completa para integracion con la app movil y sistemas externos.

| Metodo | Endpoint | Descripcion |
|---|---|---|
| `GET` | `/api/info` | Info del servidor, uptime, IPs |
| `GET` | `/api/status` | Estado de deteccion en tiempo real |
| `GET` | `/api/stream` | Stream MJPEG de la camara |
| `GET` | `/api/events` | Stream SSE de alarmas |
| `GET` | `/api/config` | Configuracion actual |
| `POST` | `/api/config` | Actualizar configuracion |
| `GET` | `/api/alarms` | Historial de alarmas |
| `POST` | `/api/timer/start` | Iniciar timer de cocina |
| `POST` | `/api/timer/stop` | Detener timer |
| `POST` | `/api/timer/pause` | Pausar timer |
| `POST` | `/api/timer/resume` | Reanudar timer |
| `POST` | `/api/register_token` | Registrar token FCM |
| `POST` | `/api/unregister_token` | Desregistrar token FCM |

Documentacion completa: [docs/API.md](docs/API.md)

---

## Documentacion

| Documento | Descripcion |
|---|---|
| [API REST](docs/API.md) | Endpoints para integracion con app movil |
| [Arquitectura](docs/ARCHITECTURE.md) | Diagramas y diseno del sistema |
| [Build & Deploy](docs/BUILD.md) | Compilar ejecutable e instalador |
| [Guia de Despliegue](docs/DEPLOY.md) | Instalacion en produccion |
| [Changelog](CHANGELOG.md) | Historial de versiones |
| [Contribuir](CONTRIBUTING.md) | Guia para contributors |
| [Seguridad](SECURITY.md) | Politica de reporte de vulnerabilidades |

---

## Testing

```bash
# Ejecutar todos los tests
pytest

# Ejecutar con cobertura
pytest --cov=cocinap --cov-report=html

# Ejecutar tests especificos
pytest tests/test_config.py -v
```

---

## Build & Distribucion

```powershell
# Build completo (PyInstaller + Inno Setup)
python build_all.py

# Output:
# dist/CocinaP_Setup_v1.0.1.exe   ← Instalador (92 MB)
```

Ver guia completa: [docs/BUILD.md](docs/BUILD.md)

---

## Licencia

**CocinaP** es un producto comercial. Todos los derechos reservados.

Este software no puede ser copiado, modificado, o distribuido sin autorizacion
expresa del titular. Ver [LICENSE](LICENSE) para terminos completos.

---

## Contacto

- **Repositorio:** [github.com/KevinVilleros/KitchenGuard](https://github.com/KevinVilleros/KitchenGuard)
- **Issues:** [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues)
- **Desarrollador:** Kevin Villeros
