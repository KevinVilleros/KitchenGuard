import cv2


def draw_detections(frame, detections, alerts, status_text, status_color, fps, unattended_minutes=0):
    sz_x, sz_y, sz_w, sz_h = detections.get("stove_zone", (0, 0, 0, 0))
    fw, fh = detections.get("frame_size", (frame.shape[1], frame.shape[0]))

    cv2.rectangle(frame, (sz_x, sz_y), (sz_x + sz_w, sz_y + sz_h), (100, 100, 100), 1)
    cv2.putText(frame, "Zona estufa", (sz_x, sz_y - 5),
                cv2.FONT_HERSHEY_SIMPLEX, 0.4, (100, 100, 100), 1)

    for fire in detections["fire"]:
        x, y, w, h = fire["bbox"]
        cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 0, 255), 2)
        cv2.putText(frame, f"FUEGO", (x, y - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)

    for smoke in detections["smoke"]:
        x, y, w, h = smoke["bbox"]
        cv2.rectangle(frame, (x, y), (x + w, y + h), (128, 128, 128), 2)
        cv2.putText(frame, "HUMO", (x, y - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (128, 128, 128), 2)

    for obj in detections["kitchen_objects"]:
        x1, y1, x2, y2 = obj["bbox"]
        is_pot = any(obj == po for po in detections.get("pots_on_stove", []))
        color = (0, 255, 0) if obj["class_id"] == 0 else (0, 200, 255) if is_pot else (255, 255, 0)
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
        label = f"{obj['display_name']} {obj['confidence']:.0%}"
        cv2.putText(frame, label, (x1, y1 - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

    bar_y = fh - 40
    cv2.rectangle(frame, (0, bar_y), (fw, fh), (0, 0, 0), -1)
    cv2.putText(frame, status_text, (10, bar_y + 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, status_color, 2)

    info_x = fw - 200
    cv2.putText(frame, f"FPS: {fps:.1f}", (info_x, bar_y + 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)

    persons = detections["persons"]
    cv2.putText(frame, f"Personas: {persons}", (fw - 250, 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 1)

    fire_cov = detections.get("fire_coverage", 0)
    smoke_cov = detections.get("smoke_coverage", 0)
    cv2.putText(frame, f"Fuego: {fire_cov:.1%} | Humo: {smoke_cov:.1%}", (10, 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

    n_pots = len(detections.get("pots_on_stove", []))
    if n_pots > 0 and persons == 0:
        mins_text = f"{unattended_minutes:.0f} min" if unattended_minutes >= 1 else f"{int(unattended_minutes*60)}s"
        cv2.putText(frame, f"Ollas: {n_pots} | Solo: {mins_text}", (10, 70),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)

    if alerts:
        alert = alerts[0]
        cv2.putText(frame, alert["message"], (10, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)

    return frame
