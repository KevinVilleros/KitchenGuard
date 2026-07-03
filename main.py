#!/usr/bin/env python3
"""CocinaP - Sistema de Seguridad en Cocina
Uso:
  python main.py                     Cámara en vivo
  python main.py test [video]        Probar con video (selector si sin ruta)
  python main.py --web [puerto]      Interfaz web en puerto (defecto: 8080)
  python main.py test --web          Test + interfaz web
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def cmd_camera(web_port=None):
    from cocinap.camera.handler import CameraHandler
    from cocinap.engine import CocinaPEngine
    import cv2
    import time

    print("=== SISTEMA DE SEGURIDAD COCINA v2.0 ===")
    print("Inicializando...")

    camera = CameraHandler()
    engine = CocinaPEngine(camera.get_frame, web_port=web_port)

    print("Conectando cámara...")
    camera.start()
    engine.start()
    time.sleep(2)
    print("Listo. Presiona ESC o 'q' para salir.")

    window_name = "CocinaP - Seguridad en Cocina"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(window_name, 960, 600)

    try:
        while True:
            frame = camera.get_frame()
            if frame is None:
                time.sleep(0.005)
                continue

            engine.track_fps()
            dets = engine.get_latest()
            alerts, _, _ = engine.analyze(dets)
            unattended = engine.get_unattended(dets)
            status_text, status_color = engine.get_status(alerts, dets)
            display = engine.draw(frame, dets, alerts, status_text, status_color, engine.fps, unattended)

            cv2.imshow(window_name, display)

            key = cv2.waitKey(1) & 0xFF
            if key in [27, ord('q'), ord('Q')]:
                break

    except KeyboardInterrupt:
        pass
    finally:
        print("Deteniendo sistema...")
        engine.stop()
        camera.stop()
        cv2.destroyAllWindows()
        print("Sistema detenido.")


if __name__ == "__main__":
    # Default to GUI when running as bundled EXE (no console)
    if getattr(sys, 'frozen', False) and len(sys.argv) <= 1:
        from cocinap.app import main
        main()
        sys.exit(0)

    web_port = None
    args = sys.argv[1:]
    if "--web" in args:
        idx = args.index("--web")
        web_port = int(args[idx + 1]) if idx + 1 < len(args) and args[idx + 1].isdigit() else 8080
        args = [a for a in args if a not in ("--web", str(web_port))]

    if args and args[0] == "test":
        from cocinap.test_app import run_test
        video = args[1] if len(args) > 1 else None
        run_test(video, web_port=web_port)
    elif args and args[0] == "gui":
        from cocinap.app import main
        main()
    elif args:
        print(__doc__)
    else:
        cmd_camera(web_port=web_port)
