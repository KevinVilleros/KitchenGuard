#!/usr/bin/env python3
import cv2
import os
import sys
import time
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import tkinter as tk
    from tkinter import filedialog
    _has_tk = True
except ImportError:
    _has_tk = False

from cocinap.engine import CocinaPEngine


def _pick_file():
    if _has_tk:
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        path = filedialog.askopenfilename(
            title="Seleccioná un video",
            filetypes=[("Videos", "*.mp4 *.avi *.mov *.mkv *.webm"), ("Todos", "*.*")],
        )
        root.destroy()
        return path
    path = input("Ruta del video: ").strip()
    return path if os.path.exists(path) else None


def run_test(video_path=None, headless=False):
    if video_path is None:
        video_path = _pick_file()
    if not video_path or not os.path.exists(video_path):
        print("No se seleccionó ningún video.")
        return

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"ERROR: No se pudo abrir el video: {video_path}")
        return

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps_video = cap.get(cv2.CAP_PROP_FPS)
    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    duration = total_frames / fps_video if fps_video > 0 else 0
    frame_ms = max(1, int(1000 / fps_video)) if fps_video > 0 else 33

    print(f"\nVideo: {os.path.basename(video_path)}")
    print(f"Resolucion: {orig_w}x{orig_h} | Duracion: {duration:.1f}s | {fps_video:.1f} FPS")
    if not headless:
        print("Controles: [Q] salir  [Espacio] pausa")
    print("Procesando...\n")

    engine = CocinaPEngine()
    engine.start()
    time.sleep(1)

    if not headless:
        window_name = "CocinaP - Prueba de Video"
        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(window_name, 960, 600)

    stats = {
        "frames": 0, "fire_frames": 0, "smoke_frames": 0,
        "person_frames": 0, "alerts": [], "fire_levels": [],
    }
    paused = False
    frame_count = 0
    t_start = time.time()
    t_frame = time.time()

    while True:
        if not paused:
            ret, frame = cap.read()
            if not ret:
                break
            frame_count += 1

            engine.submit_frame(frame)
            dets = engine.get_latest()
            alerts, trigger, alarm_type = engine.analyze(dets)

            stats["frames"] = frame_count
            if len(dets["fire"]) > 0:
                stats["fire_frames"] += 1
                stats["fire_levels"].append(dets["fire_coverage"])
            if len(dets["smoke"]) > 0:
                stats["smoke_frames"] += 1
            if dets["persons"] > 0:
                stats["person_frames"] += 1

            if trigger:
                for a in alerts:
                    if a["message"] not in [x["message"] for x in stats["alerts"]]:
                        stats["alerts"].append(a)
                        print(f"  ALARMA [{a['severity']}]: {a['message']}")

            unattended = engine.get_unattended(dets)
            status_text, status_color = engine.get_status(alerts, dets)
            display = engine.draw(frame, dets, alerts, status_text, status_color, fps_video, unattended)

            prog = f"Frame {frame_count}/{total_frames} ({frame_count/total_frames*100:.0f}%)"
            cv2.putText(display, prog, (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)

            if paused:
                cv2.putText(display, "PAUSA", (display.shape[1] // 2 - 40, 40),
                            cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2)

            if not headless:
                cv2.imshow(window_name, display)

            elapsed = time.time() - t_frame
            delay = max(1, frame_ms - int(elapsed * 1000))
            if not headless:
                key = cv2.waitKey(delay) & 0xFF
                if key in [27, ord('q'), ord('Q')]:
                    break
                if key == ord(' '):
                    paused = not paused
            else:
                time.sleep(max(0.001, delay / 1000))
            t_frame = time.time()

        else:
            cv2.waitKey(200)

    elapsed = time.time() - t_start
    cap.release()
    engine.stop()
    if not headless:
        cv2.destroyAllWindows()

    print("\n" + "=" * 55)
    print("RESULTADOS DE LA PRUEBA")
    print("=" * 55)
    print(f"Video:               {os.path.basename(video_path)}")
    print(f"Tiempo real:         {elapsed:.1f}s")
    print(f"Frames procesados:   {stats['frames']}")
    print(f"Frames con fuego:    {stats['fire_frames']}")
    if stats["fire_levels"]:
        print(f"Cobertura fuego prom: {sum(stats['fire_levels'])/len(stats['fire_levels']):.1%}")
    print(f"Frames con humo:     {stats['smoke_frames']}")
    print(f"Frames con persona:  {stats['person_frames']}")
    print(f"Alertas generadas:   {len(stats['alerts'])}")
    for a in stats["alerts"]:
        print(f"  [{a['severity']:8s}] {a['message']}")
    print("=" * 55)

    if not headless:
        try:
            resp = input("\nGuardar video anotado? (s/N): ").strip().lower()
        except (EOFError, OSError):
            resp = ""
        if resp == "s":
            _save_video(video_path, stats, fps_video, orig_w, orig_h)

    return stats


def _save_video(original_path, stats, fps, orig_w, orig_h):
    cap = cv2.VideoCapture(original_path)
    if not cap.isOpened():
        print("  No se pudo reabrir el video original.")
        return

    out_path = tempfile.mktemp(suffix=".mp4")
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(out_path, fourcc, fps, (orig_w, orig_h))
    if not writer.isOpened():
        print("  No se pudo crear el archivo de salida.")
        cap.release()
        return

    engine = CocinaPEngine()
    engine.start()
    time.sleep(0.5)

    total = stats["frames"]
    frame_count = 0
    while True:
        ret, frame = cap.read()
        if not ret or frame_count >= total:
            break
        frame_count += 1

        engine.submit_frame(frame)
        dets = engine.get_latest()
        alerts, trigger, alarm_type = engine.analyze(dets)
        unattended = engine.get_unattended(dets)
        status_text, status_color = engine.get_status(alerts, dets)
        display = engine.draw(frame, dets, alerts, status_text, status_color, fps, unattended)

        display_resized = cv2.resize(display, (orig_w, orig_h))
        writer.write(display_resized)

        if frame_count % 30 == 0:
            pct = frame_count / total * 100 if total > 0 else 0
            print(f"  Guardando: {frame_count}/{total} ({pct:.0f}%)")

    cap.release()
    writer.release()
    engine.stop()

    dst = input(f"  Guardar como (Enter para {os.path.basename(out_path)}): ").strip()
    if dst:
        try:
            os.replace(out_path, dst)
            print(f"  Guardado en: {dst}")
        except Exception:
            print(f"  Guardado en: {out_path}")
    else:
        print(f"  Guardado en: {out_path}")


if __name__ == "__main__":
    headless = "--headless" in sys.argv
    args = [a for a in sys.argv[1:] if a not in ("--headless",)]
    run_test(args[0] if args else None, headless=headless)
