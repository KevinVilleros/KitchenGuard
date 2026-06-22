#!/usr/bin/env python3
import argparse
import cv2
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cocinap.detector.detector import Detector
from cocinap.analyzer.risk_analyzer import RiskAnalyzer
from cocinap.alarm.sound_alarm import SoundAlarm
from cocinap.utils.visuals import draw_detections
from cocinap.config import DETECTION_INTERVAL


def run_test(video_path, loop=False, headless=False):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"ERROR: No se pudo abrir el video: {video_path}")
        sys.exit(1)

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps_video = cap.get(cv2.CAP_PROP_FPS)
    duration = total_frames / fps_video if fps_video > 0 else 0

    print(f"Video: {os.path.basename(video_path)}")
    print(f"Frames: {total_frames} | Duración: {duration:.1f}s | FPS: {fps_video:.1f}")

    detector = Detector()
    analyzer = RiskAnalyzer()
    alarm = SoundAlarm()

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

    window_name = "CocinaP - Prueba con Video"
    if not headless:
        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(window_name, 960, 600)

    stats = {"frames": 0, "fire_frames": 0, "smoke_frames": 0, "person_frames": 0, "alerts": [], "fire_levels": []}
    frame_count = 0
    running = True

    while running:
        ret, frame = cap.read()
        if not ret:
            if loop:
                cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                continue
            break

        frame_count += 1
        current_time = time.time()

        if current_time - last_detection_time >= DETECTION_INTERVAL:
            result = detector.detect(frame)
            last_detections = detector.get_detection_summary(result, frame)
            last_detection_time = current_time

        last_alerts = analyzer.analyze(last_detections)

        stats["frames"] = frame_count
        if len(last_detections["fire"]) > 0:
            stats["fire_frames"] += 1
            stats["fire_levels"].append(last_detections["fire_coverage"])
        if len(last_detections["smoke"]) > 0:
            stats["smoke_frames"] += 1
        if last_detections["persons"] > 0:
            stats["person_frames"] += 1

        trigger, alarm_type = analyzer.should_trigger_alarm(last_alerts)
        if trigger:
            if alarm_type == "fire":
                alarm.start_fire()
            elif alarm_type == "unattended":
                alarm.start_unattended()
            for a in last_alerts:
                if a["message"] not in [x["message"] for x in stats["alerts"]]:
                    stats["alerts"].append(a)
                    print(f"🚨 ALARMA [{a['severity']}]: {a['message']}")
        elif not last_alerts:
            alarm.stop()

        fps_display = fps_video

        unattended_minutes = 0
        if not last_detections.get("persons", 0) > 0 and len(last_detections.get("pots_on_stove", [])) > 0:
            unattended_minutes = (time.time() - analyzer.last_person_time) / 60.0

        status_text = analyzer.get_status_text(last_alerts, last_detections)
        status_color = analyzer.get_status_color(last_alerts)

        if headless:
            if frame_count % 30 == 0:
                progress = frame_count / total_frames * 100
                n_persons = last_detections["persons"]
                n_fire = len(last_detections["fire"])
                n_smoke = len(last_detections["smoke"])
                fire_cov = last_detections["fire_coverage"]
                n_pots = len(last_detections["pots_on_stove"])
                print(f"  [{progress:5.1f}%] Frame {frame_count}/{total_frames} | P:{n_persons} 🔥{n_fire}({fire_cov:.1%}) 💨{n_smoke} | Ollas:{n_pots} | {status_text}")
        else:
            display = draw_detections(
                frame, last_detections, last_alerts,
                status_text, status_color, fps_display,
                unattended_minutes=unattended_minutes,
            )
            prog_text = f"Frame {frame_count}/{total_frames} ({frame_count/total_frames*100:.0f}%)"
            cv2.putText(display, prog_text, (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)
            cv2.imshow(window_name, display)

            key = cv2.waitKey(1) & 0xFF
            if key in [27, ord('q'), ord('Q')]:
                running = False

    cap.release()
    alarm.stop()
    if not headless:
        cv2.destroyAllWindows()

    print("\n" + "=" * 55)
    print("RESULTADOS DE LA PRUEBA")
    print("=" * 55)
    print(f"Frames procesados:     {stats['frames']}")
    print(f"Frames con fuego:      {stats['fire_frames']}")
    if stats["fire_levels"]:
        print(f"Cobertura fuego promedio: {sum(stats['fire_levels'])/len(stats['fire_levels']):.1%}")
    print(f"Frames con humo:       {stats['smoke_frames']}")
    print(f"Frames con persona:    {stats['person_frames']}")
    print(f"Alertas generadas:     {len(stats['alerts'])}")
    for a in stats['alerts']:
        print(f"  [{a['severity']:8s}] {a['message']}")
    print("=" * 55)

    return stats


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CocinaP - Prueba con video")
    parser.add_argument("--video", "-v", required=True, help="Ruta al archivo de video")
    parser.add_argument("--loop", "-l", action="store_true", help="Repetir video al terminar")
    parser.add_argument("--headless", "-H", action="store_true", help="Modo solo consola, sin ventana")
    args = parser.parse_args()

    if not os.path.exists(args.video):
        print(f"ERROR: No existe el archivo: {args.video}")
        sys.exit(1)

    run_test(args.video, loop=args.loop, headless=args.headless)
