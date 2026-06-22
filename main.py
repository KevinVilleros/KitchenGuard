#!/usr/bin/env python3
"""CocinaP - Sistema de Seguridad en Cocina
Uso:
  python main.py             →  Cámara en vivo
  python main.py test --video ruta  →  Prueba con video
  python main.py web         →  App web con subida de video
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def cmd_camera():
    from cocinap.camera.handler import CameraHandler
    from cocinap.detector.detector import Detector
    from cocinap.analyzer.risk_analyzer import RiskAnalyzer
    from cocinap.alarm.sound_alarm import SoundAlarm
    from cocinap.utils.visuals import draw_detections
    from cocinap.config import DETECTION_INTERVAL

    import cv2
    import time

    print("=== SISTEMA DE SEGURIDAD COCINA v2.0 ===")
    print("Inicializando...")

    camera = CameraHandler()
    detector = Detector()
    analyzer = RiskAnalyzer()
    alarm = SoundAlarm()

    print("Conectando cámara...")
    camera.start()
    time.sleep(1)
    print("Listo. Presiona ESC o 'q' para salir.")

    last_detection_time = 0
    last_detections = {
        "persons": 0,
        "kitchen_objects": [],
        "fire": [], "fire_coverage": 0.0, "fire_movement_valid": True,
        "smoke": [], "smoke_coverage": 0.0,
        "pots_on_stove": [],
        "stove_zone": (0, 0, 0, 0),
        "frame_size": (0, 0),
    }
    last_alerts = []
    fps_display = 0
    frame_count = 0
    fps_timer = time.time()

    window_name = "CocinaP - Seguridad en Cocina"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(window_name, 960, 600)

    try:
        while True:
            frame = camera.get_frame()
            if frame is None:
                time.sleep(0.01)
                continue

            frame_count += 1
            if time.time() - fps_timer >= 0.5:
                fps_display = frame_count / (time.time() - fps_timer + 0.001)
                frame_count = 0
                fps_timer = time.time()

            current_time = time.time()
            if current_time - last_detection_time >= DETECTION_INTERVAL:
                result = detector.detect(frame)
                last_detections = detector.get_detection_summary(result, frame)
                last_detection_time = current_time

            last_alerts = analyzer.analyze(last_detections)

            trigger, alarm_type = analyzer.should_trigger_alarm(last_alerts)
            if trigger:
                if alarm_type == "fire":
                    alarm.start_fire()
                elif alarm_type == "unattended":
                    alarm.start_unattended()
            elif not last_alerts:
                alarm.stop()

            unattended_minutes = 0
            if not last_detections.get("persons", 0) > 0 and len(last_detections.get("pots_on_stove", [])) > 0:
                unattended_minutes = (time.time() - analyzer.last_person_time) / 60.0

            status_text = analyzer.get_status_text(last_alerts, last_detections)
            status_color = analyzer.get_status_color(last_alerts)

            display = draw_detections(
                frame, last_detections, last_alerts,
                status_text, status_color, fps_display,
                unattended_minutes=unattended_minutes,
            )

            cv2.imshow(window_name, display)

            key = cv2.waitKey(1) & 0xFF
            if key in [27, ord('q'), ord('Q')]:
                break

    except KeyboardInterrupt:
        pass
    finally:
        print("Deteniendo sistema...")
        alarm.stop()
        camera.stop()
        cv2.destroyAllWindows()
        print("Sistema detenido.")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "test" and "--video" in sys.argv:
            idx = sys.argv.index("--video") + 1
            if idx < len(sys.argv):
                from scripts.test_video import run_test
                run_test(sys.argv[idx])
        elif sys.argv[1] == "web":
            from scripts.upload_test import launch_web
            launch_web()
        else:
            print(__doc__)
    else:
        cmd_camera()
