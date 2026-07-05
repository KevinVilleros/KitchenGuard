"""Build CocinaP EXE + Installer script."""
import os
import sys
import subprocess
import shutil


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    os.chdir(base)

    print("=" * 60)
    print("CocinaP Build All")
    print("=" * 60)

    # Step 1: Install deps
    print("\n[1/4] Instalando dependencias...")
    subprocess.check_call(
        [sys.executable, "-m", "pip", "install", "-r", "requirements.txt"],
        stdout=subprocess.DEVNULL,
    )
    print("  OK")

    # Step 2: PyInstaller
    print("\n[2/4] Compilando EXE con PyInstaller...")
    rc = subprocess.call([sys.executable, "build_app.py"])
    if rc != 0:
        print("  ERROR en PyInstaller")
        sys.exit(rc)
    print("  OK")

    # Step 3: Check Inno Setup
    print("\n[3/4] Buscando Inno Setup...")
    iscc_paths = [
        r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        r"C:\Program Files\Inno Setup 6\ISCC.exe",
        r"C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
        r"C:\Program Files\Inno Setup 5\ISCC.exe",
    ]
    iscc = None
    for p in iscc_paths:
        if os.path.exists(p):
            iscc = p
            break

    if iscc:
        print(f"  Inno Setup encontrado: {iscc}")
        print("\n[4/4] Generando instalador...")
        subprocess.check_call([iscc, os.path.join(base, "installer", "CocinaP.iss")])
        # List output
        dist_dir = os.path.join(base, "dist")
        setups = [f for f in os.listdir(dist_dir) if f.startswith("CocinaP_Setup")]
        if setups:
            print(f"  Instalador creado: {os.path.join(dist_dir, setups[-1])}")
        else:
            print("  WARNING: No se encontro el instalador en dist/")
    else:
        print("  Inno Setup no instalado. Saltando paso 4.")
        print("  Descargar: https://jrsoftware.org/isdl.php")
        print("  Luego ejecutar manualmente:")
        print(f'    iscc "{os.path.join(base, "installer", "CocinaP.iss")}"')

    print("\n" + "=" * 60)
    print("Build completo!")
    print(f"  EXE: {os.path.join(base, 'dist', 'CocinaP', 'CocinaP.exe')}")
    if iscc:
        setups = [f for f in os.listdir(os.path.join(base, "dist")) if f.startswith("CocinaP_Setup")]
        if setups:
            print(f"  Instalador: {os.path.join(base, 'dist', setups[-1])}")
    else:
        print("  Para crear instalador: instalar Inno Setup y ejecutar:")
        print(f'    iscc "{os.path.join(base, "installer", "CocinaP.iss")}"')
    print("=" * 60)


if __name__ == "__main__":
    main()
