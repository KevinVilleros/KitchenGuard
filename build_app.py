"""Build CocinaP as a standalone Windows EXE using PyInstaller."""
import os
import sys
import shutil
import subprocess


def main():
    # Ensure yolo11n.pt exists locally
    model_path = os.path.join(os.path.dirname(__file__), "yolo11n.pt")
    if not os.path.exists(model_path):
        print("Descargando modelo YOLO...")
        # Trigger download via ultralytics
        subprocess.check_call([sys.executable, "-c", "from ultralytics import YOLO; YOLO('yolo11n.pt')"])

    # Clean previous builds
    for d in ["build", "dist"]:
        if os.path.exists(d):
            shutil.rmtree(d)

    # PyInstaller command
    pyinstaller = [sys.executable, "-m", "PyInstaller"]

    args = pyinstaller + [
        "main.py",
        "--name=CocinaP",
        "--windowed",  # no console
        "--onefile",   # single .exe
        "--add-data", f"yolo11n.pt{';'}.",
        "--icon=NONE",
        # Hidden imports for PySide6
        "--hidden-import", "PySide6.QtCore",
        "--hidden-import", "PySide6.QtGui",
        "--hidden-import", "PySide6.QtWidgets",
        "--hidden-import", "PySide6.QtNetwork",
        # Hidden imports for OpenCV
        "--hidden-import", "cv2",
        "--hidden-import", "numpy",
        # Hidden imports for ultralytics
        "--hidden-import", "ultralytics",
        "--hidden-import", "ultralytics.nn.tasks",
        "--hidden-import", "ultralytics.engine.model",
        "--hidden-import", "ultralytics.engine.predictor",
        "--hidden-import", "torch",
        # Hidden imports for the app
        "--hidden-import", "cocinap.engine",
        "--hidden-import", "cocinap.detector.detector",
        "--hidden-import", "cocinap.detector.runner",
        "--hidden-import", "cocinap.analyzer.risk_analyzer",
        "--hidden-import", "cocinap.alarm.sound_alarm",
        "--hidden-import", "cocinap.camera.handler",
        "--hidden-import", "cocinap.webui",
        "--hidden-import", "cocinap.config",
        "--collect-all", "ultralytics",
        "--collect-all", "cocinap",
        "--noconfirm",
    ]

    print("Ejecutando PyInstaller...")
    sys.exit(subprocess.call(args))


if __name__ == "__main__":
    main()
