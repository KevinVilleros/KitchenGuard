import cv2
import numpy as np
from ultralytics import YOLO
from cocinap.config import (
    YOLO_MODEL, YOLO_CONFIDENCE, YOLO_DEVICE,
    FIRE_AREA_MIN, FIRE_MOVEMENT_MIN,
    SMOKE_AREA_MIN, STOVE_ZONE,
)


COCO_KITCHEN_CLASSES = {
    0: "persona",
    41: "taza",
    43: "botella",
    44: "cuchara",
    45: "bol",
    46: "banana",
    47: "tenedor",
    48: "cuchillo",
    49: "cuchara",
    56: "silla",
    57: "sofá",
    61: "maceta",
    62: "cama",
    63: "mesa",
    67: "horno/microondas",
    72: "tv",
    73: "laptop",
    74: "mouse",
    75: "control remoto",
    76: "teclado",
    77: "celular",
}

POT_CLASSES = {45, 41, 43, 47, 48, 49}


class Detector:
    def __init__(self):
        self.model = YOLO(YOLO_MODEL)
        self.names = self.model.names
        self._prev_fire_mask = None

    def detect(self, frame):
        results = self.model(
            frame,
            conf=YOLO_CONFIDENCE,
            device=YOLO_DEVICE,
            verbose=False,
        )
        return results[0]

    def get_stove_zone(self, frame_h, frame_w):
        return (
            int(STOVE_ZONE["x"] * frame_w),
            int(STOVE_ZONE["y"] * frame_h),
            int(STOVE_ZONE["w"] * frame_w),
            int(STOVE_ZONE["h"] * frame_h),
        )

    def detect_fire(self, frame):
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        lower1 = np.array([0, 100, 100], dtype=np.uint8)
        upper1 = np.array([30, 255, 255], dtype=np.uint8)
        lower2 = np.array([160, 100, 100], dtype=np.uint8)
        upper2 = np.array([180, 255, 255], dtype=np.uint8)
        mask = cv2.inRange(hsv, lower1, upper1) | cv2.inRange(hsv, lower2, upper2)

        mask = cv2.erode(mask, None, iterations=2)
        mask = cv2.dilate(mask, None, iterations=2)
        mask = cv2.GaussianBlur(mask, (5, 5), 0)

        if self._prev_fire_mask is not None:
            diff = cv2.absdiff(mask, self._prev_fire_mask)
            movement = cv2.countNonZero(diff)
        else:
            movement = 0

        _, mask_thresh = cv2.threshold(mask, 50, 255, cv2.THRESH_BINARY)
        self._prev_fire_mask = mask_thresh

        frame_area = frame.shape[0] * frame.shape[1]
        contours, _ = cv2.findContours(mask_thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        fire_pixels = cv2.countNonZero(mask_thresh)
        coverage = fire_pixels / frame_area if frame_area > 0 else 0

        fire_regions = []
        for contour in contours:
            area = cv2.contourArea(contour)
            if area > FIRE_AREA_MIN:
                x, y, w, h = cv2.boundingRect(contour)
                fire_regions.append({
                    "bbox": (x, y, w, h),
                    "area": area,
                    "confidence": min(area / 5000, 0.95),
                })

        movement_valid = movement > FIRE_MOVEMENT_MIN

        return fire_regions, coverage, movement_valid

    def detect_smoke(self, frame):
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        lower = np.array([0, 0, 180], dtype=np.uint8)
        upper = np.array([180, 30, 255], dtype=np.uint8)
        mask = cv2.inRange(hsv, lower, upper)
        mask = cv2.erode(mask, None, iterations=1)
        mask = cv2.dilate(mask, None, iterations=1)
        mask = cv2.GaussianBlur(mask, (5, 5), 0)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        smoke_regions = []
        total_smoke_pixels = 0
        for contour in contours:
            area = cv2.contourArea(contour)
            if area > SMOKE_AREA_MIN:
                x, y, w, h = cv2.boundingRect(contour)
                smoke_regions.append({
                    "bbox": (x, y, w, h),
                    "area": area,
                })
                total_smoke_pixels += area

        frame_area = frame.shape[0] * frame.shape[1]
        smoke_coverage = total_smoke_pixels / frame_area if frame_area > 0 else 0

        return smoke_regions, smoke_coverage

    def get_detection_summary(self, result, frame):
        frame_h, frame_w = frame.shape[:2]
        sz_x, sz_y, sz_w, sz_h = self.get_stove_zone(frame_h, frame_w)

        detections = {
            "persons": 0,
            "kitchen_objects": [],
            "fire": [],
            "fire_coverage": 0.0,
            "fire_movement_valid": True,
            "smoke": [],
            "smoke_coverage": 0.0,
            "pots_on_stove": [],
            "stove_zone": (sz_x, sz_y, sz_w, sz_h),
            "frame_size": (frame_w, frame_h),
        }

        if result.boxes is not None:
            for box in result.boxes:
                cls_id = int(box.cls[0])
                conf = float(box.conf[0])
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                label = self.names[cls_id]
                display_name = COCO_KITCHEN_CLASSES.get(cls_id, label)

                obj = {
                    "class_id": cls_id,
                    "label": label,
                    "display_name": display_name,
                    "confidence": conf,
                    "bbox": (x1, y1, x2, y2),
                }

                if cls_id == 0:
                    detections["persons"] += 1
                detections["kitchen_objects"].append(obj)

                cx = (x1 + x2) // 2
                cy = (y1 + y2) // 2
                if cls_id in POT_CLASSES and sz_x <= cx <= sz_x + sz_w and sz_y <= cy <= sz_y + sz_h:
                    detections["pots_on_stove"].append(obj)

        fire_regions, fire_cov, fire_mov = self.detect_fire(frame)
        detections["fire"] = fire_regions
        detections["fire_coverage"] = fire_cov
        detections["fire_movement_valid"] = fire_mov

        smoke_regions, smoke_cov = self.detect_smoke(frame)
        detections["smoke"] = smoke_regions
        detections["smoke_coverage"] = smoke_cov

        return detections
