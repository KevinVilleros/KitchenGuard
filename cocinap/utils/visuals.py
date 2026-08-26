import cv2


def draw_detections(frame, detections, alerts, status_text, status_color, fps, unattended_minutes=0):
    sz_x, sz_y, sz_w, sz_h = detections.get("stove_zone", (0, 0, 0, 0))
    fw, fh = detections.get("frame_size", (frame.shape[1], frame.shape[0]))

    cv2.rectangle(frame, (sz_x, sz_y), (sz_x + sz_w, sz_y + sz_h), (100, 100, 100), 1)
    cv2.putText(frame, "Zona estufa", (sz_x, sz_y - 5),
                cv2.FONT_HERSHEY_SIMPLEX, 0.4, (100, 100, 100), 1)

    for fire in detections["fire"]:
        x, y, w, h = fire["bbox"]
        conf = fire.get("confidence", 1.0)
        in_stove = fire.get("in_stove_zone", False)
        has_core = fire.get("has_core", False)
        irregularity = fire.get("irregularity", 0)

        color = (0, 0, 255) if conf >= 0.5 else (0, 165, 255)
        cv2.rectangle(frame, (x, y), (x + w, y + h), color, 2)

        label = f"FUEGO {conf:.0%}"
        if has_core:
            label += " *"
        cv2.putText(frame, label, (x, y - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, color, 2)

        detail = f"irr:{irregularity:.1f}"
        if in_stove:
            detail += " estufa"
        cv2.putText(frame, detail, (x, y + h + 12),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, (200, 200, 200), 1)

    for smoke in detections["smoke"]:
        x, y, w, h = smoke["bbox"]
        edge = smoke.get("edge_density", 0)
        cv2.rectangle(frame, (x, y), (x + w, y + h), (128, 128, 128), 2)
        cv2.putText(frame, f"HUMO e:{edge:.2f}", (x, y - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, (128, 128, 128), 1)

    for obj in detections["kitchen_objects"]:
        x1, y1, x2, y2 = obj["bbox"]
        is_pot = any(obj == po for po in detections.get("pots_on_stove", []))
        color = (0, 255, 0) if obj["class_id"] == 0 else (0, 200, 255) if is_pot else (255, 255, 0)
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
        label = f"{obj['display_name']} {obj['confidence']:.0%}"
        cv2.putText(frame, label, (x1, y1 - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, color, 2)

    bar_y = fh - 40
    cv2.rectangle(frame, (0, bar_y), (fw, fh), (0, 0, 0), -1)
    cv2.putText(frame, status_text, (10, bar_y + 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.65, status_color, 2)

    cv2.putText(frame, f"FPS: {fps:.1f}", (fw - 130, bar_y + 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 200, 200), 1)

    persons = detections["persons"]
    cv2.putText(frame, f"Personas: {persons}", (fw - 250, 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 1)

    fire_cov = detections.get("fire_coverage", 0)
    smoke_cov = detections.get("smoke_coverage", 0)
    n_fire = len(detections.get("fire", []))
    n_smoke = len(detections.get("smoke", []))
    info = f"Fuego: {fire_cov:.1%} ({n_fire}reg) | Humo: {smoke_cov:.1%} ({n_smoke}reg)"
    cv2.putText(frame, info, (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 200, 200), 1)

    n_pots = len(detections.get("pots_on_stove", []))
    if n_pots > 0 and persons == 0:
        mins_text = f"{unattended_minutes:.0f} min" if unattended_minutes >= 1 else f"{int(unattended_minutes*60)}s"
        cv2.putText(frame, f"Ollas: {n_pots} | Solo: {mins_text}", (10, 70),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)

    if alerts:
        alert = alerts[0]
        cv2.putText(frame, alert["message"], (10, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.75, (0, 0, 255), 2)

    return frame
