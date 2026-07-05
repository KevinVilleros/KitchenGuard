import os
import json
import sys as _sys

if getattr(_sys, 'frozen', False):
    _BASE_DIR = _sys._MEIPASS
else:
    _MODULE_DIR = os.path.dirname(os.path.abspath(__file__))
    _BASE_DIR = os.path.dirname(_MODULE_DIR)

_APP_DATA = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "CocinaP")
os.makedirs(_APP_DATA, exist_ok=True)
os.makedirs(os.path.join(_APP_DATA, "logs"), exist_ok=True)

CONFIG_FILE = os.path.join(_APP_DATA, "config.json")

CAMERA_ID = 0
CAMERA_WIDTH = 1280
CAMERA_HEIGHT = 720
CAMERA_FPS = 30

YOLO_MODEL = os.path.join(_BASE_DIR, "models", "yolo11n.pt")
YOLO_CONFIDENCE = 0.4
YOLO_DEVICE = "cpu"
YOLO_IMGSZ = 320

DETECTION_INTERVAL = 0.15
DETECT_SCALE = 0.25
RISK_COOLDOWN = 5.0

FIRE_AREA_MIN = 250
FIRE_CONFIDENCE_THRESHOLD = 0.40
FIRE_STOVE_ZONE_ONLY = True
FIRE_COVERAGE_LOW = 0.03
FIRE_COVERAGE_MEDIUM = 0.08
FIRE_COVERAGE_HIGH = 0.15
FIRE_COVERAGE_CRITICAL = 0.30
FIRE_AREA_LARGE = 5000
FIRE_SUSTAINED_SECONDS = 7
FIRE_HISTORY_FRAMES = 6
FIRE_SHAPE_MIN = 1.8
FIRE_FLICKER_FRAMES = 10

SMOKE_AREA_MIN = 250
SMOKE_HISTORY_FRAMES = 3
SMOKE_COVERAGE_MIN = 0.001
SMOKE_COVERAGE_HIGH = 0.08
SMOKE_EDGE_MAX = 0.35
SMOKE_FLICKER_FRAMES = 6
SMOKE_TEXTURE_MIN = 1.0
SMOKE_TEXTURE_MAX = 30.0
SMOKE_CONFIDENCE_THRESHOLD = 0.40
SMOKE_STOVE_ZONE_ONLY = True

PERSON_HYSTERESIS_SECONDS = 5
UNATTENDED_WARN_MINUTES = 1
UNATTENDED_WARN_HIGH_MINUTES = 30
UNATTENDED_ALARM_MINUTES = 40

STOVE_ZONE = {"x": 0.25, "y": 0.35, "w": 0.50, "h": 0.45}

EVENT_LOG_FILE = os.path.join(_APP_DATA, "logs", "eventos.log")

AUTO_START = False

WEB_PORT = 8080
ENABLE_FCM = False
FCM_KEY_FILE = os.path.join(_APP_DATA, "firebase-key.json")
FCM_TOKENS = []

CFG_META = [
    ("YOLO_CONFIDENCE", "Confianza YOLO", "float", 0.1, 0.9, 0.05),
    ("DETECTION_INTERVAL", "Intervalo detección (s)", "float", 0.05, 1.0, 0.05),
    ("DETECT_SCALE", "Escala detección", "float", 0.1, 0.5, 0.05),
    ("FIRE_COVERAGE_LOW", "Cobertura fuego BAJA", "float", 0.01, 0.5, 0.01),
    ("FIRE_COVERAGE_MEDIUM", "Cobertura fuego MEDIA", "float", 0.02, 0.6, 0.01),
    ("FIRE_COVERAGE_HIGH", "Cobertura fuego ALTA", "float", 0.05, 0.8, 0.01),
    ("FIRE_COVERAGE_CRITICAL", "Cobertura fuego CRÍTICA", "float", 0.1, 0.9, 0.01),
    ("FIRE_AREA_LARGE", "Área fuego grande (px)", "int", 1000, 50000, 500),
    ("FIRE_SUSTAINED_SECONDS", "Segundos fuego sostenido", "int", 2, 30, 1),
    ("FIRE_CONFIDENCE_THRESHOLD", "Umbral confianza fuego", "float", 0.2, 0.9, 0.05),
    ("SMOKE_COVERAGE_MIN", "Cobertura humo mínima", "float", 0.0001, 0.05, 0.0005),
    ("SMOKE_COVERAGE_HIGH", "Cobertura humo ALTA", "float", 0.02, 0.5, 0.01),
    ("SMOKE_CONFIDENCE_THRESHOLD", "Umbral confianza humo", "float", 0.2, 0.9, 0.05),
    ("SMOKE_EDGE_MAX", "Máx bordes humo", "float", 0.1, 0.6, 0.05),
    ("SMOKE_TEXTURE_MIN", "Textura humo mín", "float", 0.5, 5.0, 0.5),
    ("SMOKE_TEXTURE_MAX", "Textura humo máx", "float", 10, 50, 5),
    ("PERSON_HYSTERESIS_SECONDS", "Histéresis persona (s)", "int", 1, 30, 1),
    ("RISK_COOLDOWN", "Cooldown alertas (s)", "int", 1, 30, 1),
]

_CONFIG_KEYS = [m[0] for m in CFG_META] + [
    "CAMERA_ID", "CAMERA_WIDTH", "CAMERA_HEIGHT", "CAMERA_FPS",
    "YOLO_IMGSZ", "FIRE_AREA_MIN", "SMOKE_AREA_MIN",
    "FIRE_STOVE_ZONE_ONLY", "SMOKE_STOVE_ZONE_ONLY",
    "AUTO_START", "WEB_PORT", "ENABLE_FCM",
]


def save_config():
    data = {}
    for k in _CONFIG_KEYS:
        data[k] = globals()[k]
    data["STOVE_ZONE"] = dict(STOVE_ZONE)
    data["FCM_TOKENS"] = list(FCM_TOKENS)
    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print(f"[config] Error guardando config: {e}")


def load_config():
    if not os.path.exists(CONFIG_FILE):
        return
    try:
        with open(CONFIG_FILE) as f:
            data = json.load(f)
        for k, v in data.items():
            if k == "STOVE_ZONE" and isinstance(v, dict):
                STOVE_ZONE.update(v)
            elif k == "FCM_TOKENS" and isinstance(v, list):
                FCM_TOKENS.clear()
                FCM_TOKENS.extend(v)
            elif k in globals() and isinstance(globals()[k], type(v)):
                globals()[k] = v
    except Exception as e:
        print(f"[config] Error cargando config: {e}")


load_config()
