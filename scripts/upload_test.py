#!/usr/bin/env python3
import sys
import os
import tempfile
import time
import cv2
import gradio as gr

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cocinap.detector.detector import Detector
from cocinap.analyzer.risk_analyzer import RiskAnalyzer
from cocinap.utils.visuals import draw_detections
from cocinap.config import DETECTION_INTERVAL


def process_video(video_path, progress=gr.Progress()):
    if video_path is None:
        return None, "Selecciona un video primero"

    progress(0, desc="Abriendo video...")
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return None, "ERROR: No se pudo abrir el video"

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    duration = total_frames / fps if fps > 0 else 0

    step = max(1, int(fps * 0.5))
    out_w, out_h = 960, 600

    tmp_out = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
    out_path = tmp_out.name
    tmp_out.close()

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(out_path, fourcc, fps / step, (out_w, out_h))

    detector = Detector()
    analyzer = RiskAnalyzer()

    last_detection_time = 0
    last_detections = {
        "persons": 0, "kitchen_objects": [],
        "fire": [], "fire_coverage": 0.0, "fire_movement_valid": True,
        "smoke": [], "smoke_coverage": 0.0,
        "pots_on_stove": [],
        "stove_zone": (0, 0, 0, 0),
        "frame_size": (0, 0),
    }
    last_alerts = []

    stats = {
        "frames_procesados": 0,
        "fuego_frames": 0,
        "fuego_max": 0.0,
        "humo_frames": 0,
        "persona_frames": 0,
        "alertas": [],
        "ollas_detectadas": 0,
    }

    frame_idx = 0
    frames_proc = 0
    proc_fps = fps / step if step > 0 else fps
    total_to_process = max(1, total_frames // step)

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % step != 0:
            frame_idx += 1
            continue

        frame_idx += 1
        frames_proc += 1

        current_time = time.time()
        if current_time - last_detection_time >= DETECTION_INTERVAL:
            result = detector.detect(frame)
            last_detections = detector.get_detection_summary(result, frame)
            last_detection_time = current_time

        last_alerts = analyzer.analyze(last_detections)

        stats["frames_procesados"] = frames_proc
        if len(last_detections["fire"]) > 0:
            stats["fuego_frames"] += 1
            stats["fuego_max"] = max(stats["fuego_max"], last_detections["fire_coverage"])
        if len(last_detections["smoke"]) > 0:
            stats["humo_frames"] += 1
        if last_detections["persons"] > 0:
            stats["persona_frames"] += 1

        n_pots = len(last_detections["pots_on_stove"])
        stats["ollas_detectadas"] = max(stats["ollas_detectadas"], n_pots)

        if analyzer.should_trigger_alarm(last_alerts)[0]:
            for a in last_alerts:
                if a["message"] not in [x["message"] for x in stats["alertas"]]:
                    stats["alertas"].append(a)

        unattended_minutes = 0
        if not last_detections.get("persons", 0) > 0 and len(last_detections.get("pots_on_stove", [])) > 0:
            unattended_minutes = (time.time() - analyzer.last_person_time) / 60.0

        status_text = analyzer.get_status_text(last_alerts, last_detections)
        status_color = analyzer.get_status_color(last_alerts)

        display = draw_detections(
            frame, last_detections, last_alerts,
            status_text, status_color, proc_fps,
            unattended_minutes=unattended_minutes,
        )
        display_resized = cv2.resize(display, (out_w, out_h))
        writer.write(display_resized)

        progress(frames_proc / total_to_process, desc=f"Procesando frame {frames_proc}/{total_to_process}")

    cap.release()
    writer.release()

    lines = []
    lines.append("=" * 50)
    lines.append("RESULTADOS DEL ANÁLISIS")
    lines.append("=" * 50)
    lines.append(f"Video: {os.path.basename(video_path)}")
    lines.append(f"Duración: {duration:.1f}s | FPS: {fps:.1f}")
    lines.append(f"Resolución original: {orig_w}x{orig_h}")
    lines.append(f"Frames totales: {total_frames}")
    lines.append(f"Frames procesados: {stats['frames_procesados']} (1 cada {step})")
    lines.append("")
    lines.append(f"🔥 Fuego detectado en: {stats['fuego_frames']} frames")
    lines.append(f"   Cobertura máxima: {stats['fuego_max']:.1%} del frame")
    lines.append(f"💨 Humo detectado en: {stats['humo_frames']} frames")
    lines.append(f"👤 Persona detectada en: {stats['persona_frames']} frames")
    lines.append(f"🍲 Ollas en estufa: {stats['ollas_detectadas']}")
    lines.append("")
    lines.append(f"🚨 Alertas generadas: {len(stats['alertas'])}")
    for a in stats["alertas"]:
        lines.append(f"   [{a['severity']}] {a['message']}")
    lines.append("")
    lines.append("📁 Log guardado en: eventos.log")
    lines.append("=" * 50)

    return out_path, "\n".join(lines)


css = """
#stats { font-family: monospace; white-space: pre; font-size: 14px; }
footer { display: none !important; }
"""

with gr.Blocks(title="CocinaP - Test de Video") as app:
    gr.HTML("""
    <div style="text-align:center; margin-bottom:20px">
        <h1>🍳 CocinaP - Sistema de Seguridad en Cocina</h1>
        <p style="color:#666">Subí un video de cocina para analizar riesgos (fuego, humo, cocina desatendida)</p>
    </div>
    """)

    with gr.Row():
        with gr.Column(scale=1):
            video_input = gr.Video(label="Seleccioná o arrastrá un video", height=300)
            btn = gr.Button("▶️ Analizar Video", variant="primary", size="lg")

        with gr.Column(scale=1):
            video_output = gr.Video(label="Resultado con detecciones", height=300)

    with gr.Row():
        stats_output = gr.Textbox(label="Estadísticas", lines=18, elem_id="stats")

    btn.click(
        fn=process_video,
        inputs=video_input,
        outputs=[video_output, stats_output],
    )

    gr.HTML("""
    <div style="text-align:center;margin-top:15px;font-size:0.9em;color:#999">
        Creado con YOLO11 + OpenCV
    </div>
    """)


def launch_web():
    app.launch(server_name="127.0.0.1", share=False, css=css, theme=gr.themes.Soft())


if __name__ == "__main__":
    launch_web()
