"""Build CocinaP as a standalone Windows app using PyInstaller."""
import os
import sys
import shutil
import subprocess


def main():
    model_path = os.path.join(os.path.dirname(__file__), "yolo11n.pt")
    if not os.path.exists(model_path):
        print("Descargando modelo YOLO...")
        subprocess.check_call([sys.executable, "-c", "from ultralytics import YOLO; YOLO('yolo11n.pt')"])

    for d in ["build", "dist"]:
        if os.path.exists(d):
            shutil.rmtree(d)

    pyinstaller = [sys.executable, "-m", "PyInstaller"]

    args = pyinstaller + [
        "main.py",
        "--name=CocinaP",
        "--windowed",
        "--onedir",  # faster build, smaller size
        "--add-data", f"yolo11n.pt{';'}.",
        "--hidden-import", "PySide6.QtCore",
        "--hidden-import", "PySide6.QtGui",
        "--hidden-import", "PySide6.QtWidgets",
        "--hidden-import", "PySide6.QtNetwork",
        "--hidden-import", "cv2",
        "--hidden-import", "numpy",
        "--hidden-import", "cocinap.engine",
        "--hidden-import", "cocinap.detector.detector",
        "--hidden-import", "cocinap.detector.runner",
        "--hidden-import", "cocinap.analyzer.risk_analyzer",
        "--hidden-import", "cocinap.alarm.sound_alarm",
        "--hidden-import", "cocinap.camera.handler",
        "--hidden-import", "cocinap.webui",
        "--hidden-import", "cocinap.config",
        "--noconfirm",
        "--log-level=WARN",
    ]

    print("Ejecutando PyInstaller (esto puede tomar varios minutos)...")
    sys.exit(subprocess.call(args))


if __name__ == "__main__":
    main()
