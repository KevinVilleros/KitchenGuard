# CocinaP — Sistema de Seguridad en Cocina

**Detección inteligente de fuego, humo y cocina desatendida usando YOLO11 + OpenCV**

[![Python](https://img.shields.io/badge/Python-3.14-blue?logo=python)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.29-blue?logo=flutter)](https://flutter.dev)
[![YOLO](https://img.shields.io/badge/YOLO-11-green)](https://ultralytics.com)
[![License](https://img.shields.io/badge/License-Commercial-red)](LICENSE)

---

## Características

- **Detección en tiempo real** de fuego, humo y personas usando YOLO11n (CPU)
- **Análisis de riesgo multinivel** (BAJO, MEDIO, ALTO, CRÍTICO) con cobertura y persistencia
- **Zona de estufa configurable** — el usuario define el área de monitoreo
- **Alarma sonora** asíncrona con parada inmediata
- **App nativa Windows** (PySide6) con 3 pestañas: Cámara, Config, Alarmas
- **App móvil Android** (Flutter) con dashboard en vivo, stream MJPEG y notificaciones SSE
- **Servidor web embebido** con API REST para monitoreo y configuración remota
- **Auto-descubrimiento mDNS** (Zeroconf) — no requiere configurar IP
- **Notificaciones push FCM** opcionales (Firebase Cloud Messaging)
- **Inicio automático con Windows** y bandeja de sistema
- **Distribución comercial** via instalador Inno Setup

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    PC Windows (Python)                       │
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │ Cámara   │──▶│ Engine   │──▶│ Web UI   │──▶ API REST    │
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
│  │  │ Cámara  │ │ Config   │ │ Alarmas  │            │   │
│  │  │ (en vivo)│ │(parámetros)│ │(historial)│            │   │
│  │  └─────────┘ └──────────┘ └──────────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                    WiFi LAN │ mDNS / HTTP
                              │
┌─────────────────────────────────────────────────────────────┐
│                   App Móvil (Flutter/Android)                 │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │Dashboard │  │ Alarmas  │  │ Config   │  │ Settings │  │
│  │MJPEG+Poll│  │SSE Stream│  │Remota    │  │Auto-con. │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │       Background Service (always-on notification)   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Stack Tecnológico

### Backend (PC — Python)
| Componente | Tecnología |
|---|---|
| Lenguaje | Python 3.14+ |
| GUI Nativa | PySide6 (Qt6) |
| Detección | Ultralytics YOLO11n + OpenCV |
| Deep Learning | PyTorch (CPU) |
| Servidor Web | ThreadingHTTPServer (built-in) |
| mDNS | Zeroconf |
| FCM | Firebase Admin SDK |
| Empaquetado | PyInstaller + Inno Setup |

### Frontend Móvil (Android)
| Componente | Tecnología |
|---|---|
| Framework | Flutter 3.29+ |
| Lenguaje | Dart 3.2+ |
| Estado | Provider |
| HTTP | http package |
| mDNS | multicast_dns |
| Notificaciones | Firebase Messaging + flutter_local_notifications |
| Background | flutter_background_service |

---

## Requisitos del Sistema

### PC (Servidor)
- Windows 10/11 (64-bit)
- CPU x64 con soporte AVX2 (Intel Gen 4+ / AMD Ryzen)
- 4 GB RAM mínimo (8 GB recomendado)
- Cámara USB o integrada (opcional para pruebas sin cámara)
- Conexión WiFi (para comunicación con app móvil)

### Móvil (Cliente)
- Android 8.0+ (API 26+)
- Conexión WiFi en la misma subred que la PC

---

## Inicio Rápido

### PC — Ejecutable (usuario final)

1. Descargar el instalador `CocinaP_Setup_v1.0.1.exe`
2. Ejecutar e instalar
3. Iniciar CocinaP desde el acceso directo
4. La GUI nativa se abre con 3 pestañas
5. El servidor web se inicia automáticamente en el puerto 8080

### PC — Desarrollo

```bash
git clone https://github.com/KevinVilleros/KitchenGuard
cd KitchenGuard

# Instalar dependencias
pip install -r requirements.txt

# Descargar modelo YOLO
python -c "from ultralytics import YOLO; YOLO('yolo11n.pt')"
mv yolo11n.pt models/

# Ejecutar con GUI nativa + servidor web
python main.py gui

# O solo servidor web (sin GUI)
python main.py --web 8080
```

### Móvil — Desarrollo

```bash
cd cocinap_mobile
flutter pub get
flutter run
```

---

## Documentación

| Documento | Descripción |
|---|---|
| [API REST](docs/API.md) | Endpoints para integración con app móvil |
| [Arquitectura](docs/ARCHITECTURE.md) | Diagramas y diseño del sistema |
| [Build & Deploy](docs/BUILD.md) | Compilar ejecutable e instalador |
| [Guía de Despliegue](docs/DEPLOY.md) | Instalación en producción |

---

## Licencia

**CocinaP** es un producto comercial. Todos los derechos reservados.

Este software no puede ser copiado, modificado, o distribuido sin autorización expresa del titular. Ver [LICENSE](LICENSE) para términos completos.

---

## Contacto

- **Repositorio:** [github.com/KevinVilleros/KitchenGuard](https://github.com/KevinVilleros/KitchenGuard)
- **Reportar issues:** [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues)
