"""Build CocinaP as a standalone Windows app using PyInstaller."""
import os
import sys
import shutil
import subprocess


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    model_rel = os.path.join("models", "yolo11n.pt")
    model_src = os.path.join(base, model_rel)

    if not os.path.exists(model_src):
        print("Descargando modelo YOLO...")
        subprocess.check_call(
            [sys.executable, "-c", "from ultralytics import YOLO; YOLO('yolo11n.pt')"],
            cwd=base,
        )
        os.makedirs(os.path.dirname(model_src), exist_ok=True)
        shutil.copy(os.path.join(base, "yolo11n.pt"), model_src)

    for d in ["build", "dist"]:
        dpath = os.path.join(base, d)
        if os.path.exists(dpath):
            shutil.rmtree(dpath)

    args = [
        sys.executable, "-m", "PyInstaller",
        os.path.join(base, "main.py"),
        "--name=CocinaP",
        "--onedir",
        "--add-data", f"{model_src}{os.pathsep}models",
        "--collect-submodules", "cocinap",
        "--noconfirm",
    ]

    print("Compilando con PyInstaller (5-15 min)...")
    rc = subprocess.call(args)
    if rc == 0:
        exe_path = os.path.join(base, "dist", "CocinaP", "CocinaP.exe")
        print(f"Compilacion exitosa: {exe_path}")
    sys.exit(rc)


if __name__ == "__main__":
    main()
