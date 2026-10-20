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
        root_model = os.path.join(base, "yolo11n.pt")
        if os.path.exists(root_model):
            shutil.move(root_model, model_src)

    for d in ["build", "dist"]:
        dpath = os.path.join(base, d)
        if os.path.exists(dpath):
            shutil.rmtree(dpath)

    icon_path = os.path.join(base, "cocinap", "resources", "app.ico")
    version_path = os.path.join(base, "cocinap", "resources", "version.txt")

    args = [
        sys.executable, "-m", "PyInstaller",
        os.path.join(base, "main.py"),
        "--name=CocinaP",
        "--onedir",
        "--windowed",
        "--clean",
        "--add-data", f"{model_src}{os.pathsep}models",
        "--collect-submodules", "cocinap",
        "--hidden-import", "zeroconf",
        "--hidden-import", "firebase_admin",
        "--hidden-import", "PySide6",
        "--hidden-import", "PIL",
        "--exclude-module", "scipy",
        "--exclude-module", "pandas",
        "--exclude-module", "tkinter",
        "--exclude-module", "tensorflow",
        "--exclude-module", "tensorboard",
        "--exclude-module", "notebook",
        "--exclude-module", "jupyter",
        "--exclude-module", "PyQt5",
        "--exclude-module", "PyQt6",
        "--noconfirm",
    ]

    if os.path.exists(icon_path):
        args.extend(["--icon", icon_path])
    if os.path.exists(version_path):
        args.extend(["--version-file", version_path])

    print("Compilando con PyInstaller (5-15 min)...")
    print(f"  Icono: {icon_path if os.path.exists(icon_path) else 'default'}")
    print(f"  Version: {version_path if os.path.exists(version_path) else 'none'}")
    print(f"  Excludes: scipy, pandas, tkinter")

    rc = subprocess.call(args)
    if rc == 0:
        exe_path = os.path.join(base, "dist", "CocinaP", "CocinaP.exe")
        print(f"Compilacion exitosa: {exe_path}")
    else:
        print(f"Error en compilacion (codigo {rc})")
    sys.exit(rc)


if __name__ == "__main__":
    main()
