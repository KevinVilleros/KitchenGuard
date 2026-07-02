import cv2
import numpy as np
from collections import deque
from ultralytics import YOLO
from cocinap.config import (
    YOLO_MODEL, YOLO_CONFIDENCE, YOLO_DEVICE, YOLO_IMGSZ,
    DETECT_SCALE,
    FIRE_AREA_MIN, FIRE_CONFIDENCE_THRESHOLD,
    FIRE_SHAPE_MIN, FIRE_FLICKER_FRAMES, FIRE_STOVE_ZONE_ONLY,
    SMOKE_AREA_MIN, SMOKE_COVERAGE_MIN, SMOKE_EDGE_MAX, SMOKE_EDGE_MIN,
    SMOKE_FLICKER_FRAMES, SMOKE_TEXTURE_MIN, SMOKE_TEXTURE_MAX,
    SMOKE_CONFIDENCE_THRESHOLD, SMOKE_STOVE_ZONE_ONLY,
    STOVE_ZONE,
)


COCO_KITCHEN_CLASSES = {
    0: "persona", 41: "taza", 43: "botella",
    44: "cuchara", 45: "bol", 46: "banana",
    47: "tenedor", 48: "cuchillo", 49: "cuchara",
    56: "silla", 57: "sofá", 61: "maceta",
    62: "cama", 63: "mesa", 67: "horno/microondas",
    72: "tv", 73: "laptop", 74: "mouse",
    75: "control remoto", 76: "teclado", 77: "celular",
}

POT_CLASSES = {45, 41, 43, 47, 48, 49}

_AREA_MIN_FIRE = max(12, int(FIRE_AREA_MIN * DETECT_SCALE * DETECT_SCALE))
_AREA_MIN_SMOKE = max(15, int(SMOKE_AREA_MIN * DETECT_SCALE * DETECT_SCALE))


class Detector:
    def __init__(self):
        self.model = YOLO(YOLO_MODEL)
        self.names = self.model.names
        self._flicker_buffer = deque(maxlen=FIRE_FLICKER_FRAMES)
        self._prev_fire_mask = None
        self._smoke_flicker_buffer = deque(maxlen=SMOKE_FLICKER_FRAMES)
        self._prev_smoke_mask = None
        self._prev_smoke_gray = None

    def detect(self, frame):
        results = self.model(frame, conf=YOLO_CONFIDENCE, device=YOLO_DEVICE, imgsz=YOLO_IMGSZ, verbose=False)
        return results[0]

    def get_stove_zone(self, frame_h, frame_w):
        return (
            int(STOVE_ZONE["x"] * frame_w),
            int(STOVE_ZONE["y"] * frame_h),
            int(STOVE_ZONE["w"] * frame_w),
            int(STOVE_ZONE["h"] * frame_h),
        )

    def _in_stove_zone(self, x, y, w, h, sz_x, sz_y, sz_w, sz_h):
        cx, cy = x + w // 2, y + h // 2
        return sz_x <= cx <= sz_x + sz_w and sz_y <= cy <= sz_y + sz_h

    def _scale_pt(self, val):
        return int(val * DETECT_SCALE)

    def detect_fire(self, frame, stove_zone_tuple, person_mask=None):
        h, w = frame.shape[:2]
        sw, sh = max(1, self._scale_pt(w)), max(1, self._scale_pt(h))
        small = cv2.resize(frame, (sw, sh), interpolation=cv2.INTER_LINEAR)

        hsv = cv2.cvtColor(small, cv2.COLOR_BGR2HSV)
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
        frame_area = h * w

        # ---- Fire color masks ----
        core_mask = cv2.inRange(hsv, np.array([20, 20, 210], dtype=np.uint8), np.array([35, 80, 255], dtype=np.uint8))
        flame_mask = cv2.inRange(hsv, np.array([5, 60, 140], dtype=np.uint8), np.array([30, 190, 235], dtype=np.uint8))
        outer_mask = cv2.inRange(hsv, np.array([0, 80, 80], dtype=np.uint8), np.array([8, 160, 170], dtype=np.uint8))
        outer_red = cv2.inRange(hsv, np.array([160, 80, 80], dtype=np.uint8), np.array([180, 160, 170], dtype=np.uint8))
        outer_mask = cv2.bitwise_or(outer_mask, outer_red)

        # ---- Reject over-saturated (plastic/paint) and under-saturated (white/gray walls) ----
        sat = hsv[:, :, 1].astype(np.float32)
        val_ch = hsv[:, :, 2].astype(np.float32)
        high_sat_mask = (sat > 190).astype(np.uint8) * 255
        low_sat_mask = (sat < 20).astype(np.uint8) * 255

        # ---- Reject skin-colored pixels (common false positive in kitchen videos) ----
        skin_mask = cv2.inRange(hsv, np.array([0, 20, 80], dtype=np.uint8), np.array([20, 120, 255], dtype=np.uint8))

        # ---- Clean fire mask: flame body without extreme saturation or skin ----
        fire_body = cv2.bitwise_and(flame_mask, cv2.bitwise_not(high_sat_mask))
        fire_body = cv2.bitwise_and(fire_body, cv2.bitwise_not(low_sat_mask))
        fire_body = cv2.bitwise_and(fire_body, cv2.bitwise_not(skin_mask))
        core_mask = cv2.bitwise_and(core_mask, cv2.bitwise_not(skin_mask))
        outer_mask = cv2.bitwise_and(outer_mask, cv2.bitwise_not(skin_mask))

        # Weighted combination
        weighted = fire_body.astype(np.float32) * 2.0
        weighted += core_mask.astype(np.float32) * 4.0
        weighted += outer_mask.astype(np.float32) * 1.0
        combined = (weighted >= 1.0).astype(np.uint8) * 255

        combined = cv2.morphologyEx(combined, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8), iterations=1)
        combined = cv2.morphologyEx(combined, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8), iterations=1)

        # ---- Apply person mask (YOLO person detections → not fire) ----
        if person_mask is not None:
            person_small = cv2.resize(person_mask, (sw, sh), interpolation=cv2.INTER_NEAREST)
            combined = cv2.bitwise_and(combined, cv2.bitwise_not(person_small))
            core_mask = cv2.bitwise_and(core_mask, cv2.bitwise_not(person_small))
            fire_body = cv2.bitwise_and(fire_body, cv2.bitwise_not(person_small))
            outer_mask = cv2.bitwise_and(outer_mask, cv2.bitwise_not(person_small))

        # ---- Edge density ----
        edges = cv2.Canny(gray, 30, 100)

        # ---- Local texture variance (fire is noisy, smooth surfaces are not) ----
        gray_f32 = gray.astype(np.float32)
        local_mean = cv2.blur(gray_f32, (5, 5))
        local_mean_sq = cv2.blur(gray_f32 * gray_f32, (5, 5))
        local_var = np.maximum(local_mean_sq - local_mean * local_mean, 0)

        # ---- Flicker ----
        if self._flicker_buffer and gray.shape != self._flicker_buffer[-1].shape:
            self._flicker_buffer.clear()
        self._flicker_buffer.append(gray.copy())
        flicker_map = None
        if len(self._flicker_buffer) >= 3:
            stack = np.array(list(self._flicker_buffer)[-5:], dtype=np.float32)
            variance = np.var(stack, axis=0)
            _, flicker_map = cv2.threshold(variance, 30, 255, cv2.THRESH_BINARY)
            flicker_map = flicker_map.astype(np.uint8)

        # ---- Mask change from previous frame (static colored objects don't change) ----
        fire_mask_change = None
        if self._prev_fire_mask is not None and self._prev_fire_mask.shape == combined.shape:
            fire_mask_change = cv2.bitwise_xor(combined, self._prev_fire_mask)
        self._prev_fire_mask = combined.copy()

        contours, _ = cv2.findContours(combined, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        inv_scale = 1.0 / DETECT_SCALE
        sz_x, sz_y, sz_w, sz_h = stove_zone_tuple
        sz_x_s, sz_y_s = self._scale_pt(sz_x), self._scale_pt(sz_y)
        sz_w_s, sz_h_s = max(1, self._scale_pt(sz_w)), max(1, self._scale_pt(sz_h))

        fire_regions = []
        total_fire_pixels = 0

        for contour in contours:
            area = cv2.contourArea(contour)
            if area < _AREA_MIN_FIRE:
                continue

            perimeter = cv2.arcLength(contour, True)
            irregularity = (perimeter * perimeter) / (4 * np.pi * area) if perimeter > 0 and area > 0 else 0.0

            bx, by, bw, bh = cv2.boundingRect(contour)

            region_mask = np.zeros(combined.shape, dtype=np.uint8)
            cv2.drawContours(region_mask, [contour], -1, 255, -1)
            region_area = cv2.countNonZero(region_mask)

            flame_px = cv2.countNonZero(cv2.bitwise_and(fire_body, region_mask))
            core_px = cv2.countNonZero(cv2.bitwise_and(core_mask, region_mask))
            outer_px = cv2.countNonZero(cv2.bitwise_and(outer_mask, region_mask))
            total_pixels = flame_px + core_px + outer_px
            flame_ratio = flame_px / max(region_area, 1)

            if flame_ratio < 0.30:
                continue

            # ---- Reject regions covering > 35% of the frame (noise/lighting) ----
            if region_area > 0.35 * combined.size:
                continue

            # ---- Solidity check: fire regions are relatively convex ----
            hull = cv2.convexHull(contour)
            hull_area = cv2.contourArea(hull)
            solidity = area / max(hull_area, 1)
            if solidity < 0.40:
                continue

            # ---- Edge density filter ----
            edge_px = cv2.countNonZero(cv2.bitwise_and(edges, region_mask))
            edge_density = edge_px / max(region_area, 1)
            if edge_density > 0.35:
                continue

            # ---- Local texture: fire is grainy, smooth objects are not ----
            region_texture = float(cv2.mean(local_var, region_mask)[0])
            if region_texture < 8.0 and region_area > 50:
                continue

            # ---- Hue range ----
            hue = hsv[:, :, 0].astype(np.float32)
            region_hue = cv2.bitwise_and(hue.astype(np.uint8), region_mask)
            hue_vals = region_hue[region_hue > 0]
            if len(hue_vals) > 5:
                hue_range = float(np.max(hue_vals) - np.min(hue_vals))
            else:
                hue_range = 0.0

            # ---- Saturation variance ----
            region_sat = cv2.bitwise_and(sat.astype(np.uint8), region_mask)
            sat_vals = region_sat[region_sat > 0]
            sat_std = float(np.std(sat_vals)) if len(sat_vals) > 5 else 0.0

            # ---- Value variance ----
            region_val = cv2.bitwise_and(val_ch.astype(np.uint8), region_mask)
            val_vals = region_val[region_val > 0]
            val_std = float(np.std(val_vals)) if len(val_vals) > 5 else 0.0
            val_range = float(np.max(val_vals) - np.min(val_vals)) if len(val_vals) > 5 else 0.0

            # ---- Flicker ----
            region_flicker = 0.0
            if flicker_map is not None:
                flicker_px = cv2.countNonZero(cv2.bitwise_and(flicker_map, region_mask))
                region_flicker = flicker_px / max(region_area, 1)

            # ---- Mask change (static objects don't change) ----
            region_change = 1.0
            if fire_mask_change is not None:
                change_px = cv2.countNonZero(cv2.bitwise_and(fire_mask_change, region_mask))
                region_change = change_px / max(region_area, 1)

            in_stove = self._in_stove_zone(bx, by, bw, bh, sz_x_s, sz_y_s, sz_w_s, sz_h_s)
            has_core = core_px > 3
            good_shape = irregularity >= FIRE_SHAPE_MIN

            # ---- Confidence calculation ----
            conf = 0.0

            if good_shape:
                conf += 0.15
            elif irregularity > 1.3:
                conf += 0.05

            if has_core:
                conf += 0.25

            if flame_ratio > 0.60:
                conf += 0.10
            elif flame_ratio > 0.40:
                conf += 0.05

            if region_flicker > 0.15:
                conf += 0.25
            elif region_flicker > 0.05:
                conf += 0.10

            if region_texture > 15:
                conf += 0.05

            if edge_density < 0.03:
                conf += 0.10

            if hue_range > 10:
                conf += 0.05

            if sat_std > 25:
                conf += 0.05

            if val_range < 15:
                continue
            if val_std > 35:
                conf += 0.05

            if area > _AREA_MIN_FIRE * 8:
                conf += 0.05

            # stove zone bonus handled via FIRE_STOVE_ZONE_ONLY filter

            conf = max(0.0, min(conf, 0.95))

            if conf >= FIRE_CONFIDENCE_THRESHOLD and (not FIRE_STOVE_ZONE_ONLY or in_stove):
                fire_regions.append({
                    "bbox": (int(bx * inv_scale), int(by * inv_scale),
                             int(bw * inv_scale), int(bh * inv_scale)),
                    "area": int(area * inv_scale * inv_scale),
                    "confidence": round(conf, 2),
                    "irregularity": round(irregularity, 1),
                    "flicker": round(region_flicker, 2),
                    "has_core": has_core,
                    "in_stove_zone": in_stove,
                    "edge_density": round(edge_density, 3),
                })
                total_fire_pixels += total_pixels

        coverage = (total_fire_pixels * inv_scale * inv_scale) / frame_area if frame_area > 0 else 0
        has_valid_fire = len(fire_regions) > 0

        return fire_regions, coverage, has_valid_fire

    def _detect_smoke_on_small(self, small, person_mask=None, stove_zone_tuple=None):
        sw, sh = small.shape[1], small.shape[0]
        hsv = cv2.cvtColor(small, cv2.COLOR_BGR2HSV)
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)

        # Smoke: grayish, low saturation, mid brightness
        smoke_mask = cv2.inRange(hsv, np.array([0, 0, 80], dtype=np.uint8),
                                 np.array([180, 30, 190], dtype=np.uint8))

        # Exclude steam (bright white)
        steam = cv2.inRange(hsv, np.array([0, 0, 190], dtype=np.uint8),
                            np.array([180, 15, 255], dtype=np.uint8))

        # Exclude skin
        skin = cv2.inRange(hsv, np.array([0, 20, 80], dtype=np.uint8),
                           np.array([20, 120, 255], dtype=np.uint8))

        mask = cv2.bitwise_and(smoke_mask, cv2.bitwise_not(steam))
        mask = cv2.bitwise_and(mask, cv2.bitwise_not(skin))

        if person_mask is not None:
            person_small = cv2.resize(person_mask, (sw, sh), interpolation=cv2.INTER_NEAREST)
            mask = cv2.bitwise_and(mask, cv2.bitwise_not(person_small))

        # Restrict to stove zone if configured
        if SMOKE_STOVE_ZONE_ONLY and stove_zone_tuple is not None:
            sz_x_s, sz_y_s, sz_w_s, sz_h_s = stove_zone_tuple
            # Scale stove zone to small frame coords
            inv_s = 1.0 / DETECT_SCALE
            sz_x_small = int(sz_x_s / inv_s)
            sz_y_small = int(sz_y_s / inv_s)
            sz_w_small = int(sz_w_s / inv_s)
            sz_h_small = int(sz_h_s / inv_s)
            stove_mask = np.zeros((sh, sw), dtype=np.uint8)
            cv2.rectangle(stove_mask, (sz_x_small, sz_y_small),
                          (sz_x_small + sz_w_small, sz_y_small + sz_h_small), 255, -1)
            mask = cv2.bitwise_and(mask, stove_mask)

        # Motion filter: smoke moves, static walls don't
        if self._prev_smoke_gray is not None and self._prev_smoke_gray.shape == gray.shape:
            diff = cv2.absdiff(gray, self._prev_smoke_gray)
            _, motion_mask = cv2.threshold(diff, 3, 255, cv2.THRESH_BINARY)
            mask = cv2.bitwise_and(mask, motion_mask)

        # Morphology
        mask = cv2.erode(mask, np.ones((2, 2), np.uint8), iterations=1)
        mask = cv2.dilate(mask, np.ones((3, 3), np.uint8), iterations=2)

        edges = cv2.Canny(gray, 50, 150)
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        texture_map = cv2.absdiff(gray, blur)

        inv_scale = 1.0 / DETECT_SCALE
        smoke_regions = []
        total_smoke_pixels = 0

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        for contour in contours:
            area = cv2.contourArea(contour)
            if area < _AREA_MIN_SMOKE:
                continue

            bx, by, bw, bh = cv2.boundingRect(contour)
            region_mask = np.zeros(mask.shape, dtype=np.uint8)
            cv2.drawContours(region_mask, [contour], -1, 255, -1)
            region_area = cv2.countNonZero(region_mask)

            cov_ratio = region_area / (sw * sh)
            if cov_ratio < SMOKE_COVERAGE_MIN:
                continue

            edge_pixels = cv2.countNonZero(cv2.bitwise_and(edges, region_mask))
            edge_density = edge_pixels / max(region_area, 1)
            if edge_density > SMOKE_EDGE_MAX:
                continue

            texture_vals = texture_map[region_mask > 0]
            region_texture = float(np.mean(texture_vals)) if len(texture_vals) > 0 else 0
            if region_texture < SMOKE_TEXTURE_MIN or region_texture > SMOKE_TEXTURE_MAX:
                continue

            flicker_val = 0.0
            if self._prev_smoke_mask is not None and self._prev_smoke_mask.shape == region_mask.shape:
                change = cv2.bitwise_xor(region_mask, self._prev_smoke_mask)
                change_pixels = cv2.countNonZero(change)
                flicker_val = change_pixels / max(region_area, 1)
            self._smoke_flicker_buffer.append(flicker_val)
            flicker_var = float(np.var(list(self._smoke_flicker_buffer))) if len(self._smoke_flicker_buffer) > 1 else 0.0

            conf = 0.40
            if edge_density < 0.04:
                conf += 0.10
            if region_texture < 6.0:
                conf += 0.15
            elif region_texture < 9.0:
                conf += 0.05
            if flicker_var > 0.003:
                conf += 0.15
            elif flicker_var > 0.001:
                conf += 0.05
            if cov_ratio > 0.03:
                conf += 0.10
            conf = max(0.0, min(conf, 0.95))

            if conf < SMOKE_CONFIDENCE_THRESHOLD:
                continue

            smoke_regions.append({
                "bbox": (int(bx * inv_scale), int(by * inv_scale),
                         int(bw * inv_scale), int(bh * inv_scale)),
                "area": int(area * inv_scale * inv_scale),
                "edge_density": round(edge_density, 3),
                "texture": round(region_texture, 2),
                "flicker": round(flicker_var, 4),
                "confidence": round(conf, 2),
            })
            total_smoke_pixels += area

        self._prev_smoke_mask = mask.copy()
        self._prev_smoke_gray = gray.copy()
        frame_area_small = sw * sh
        smoke_coverage = (total_smoke_pixels * inv_scale * inv_scale) / (frame_area_small * inv_scale * inv_scale) if frame_area_small > 0 else 0
        return smoke_regions, smoke_coverage

    def detect_smoke(self, frame, person_mask=None, stove_zone_tuple=None):
        h, w = frame.shape[:2]
        sw, sh = max(1, self._scale_pt(w)), max(1, self._scale_pt(h))
        small = cv2.resize(frame, (sw, sh), interpolation=cv2.INTER_LINEAR)
        return self._detect_smoke_on_small(small, person_mask, stove_zone_tuple)

    def get_detection_summary(self, result, frame):
        frame_h, frame_w = frame.shape[:2]
        sz_x, sz_y, sz_w, sz_h = self.get_stove_zone(frame_h, frame_w)
        stove_tuple = (sz_x, sz_y, sz_w, sz_h)

        detections = {
            "persons": 0, "kitchen_objects": [],
            "fire": [], "fire_coverage": 0.0, "fire_has_valid": False,
            "smoke": [], "smoke_coverage": 0.0,
            "pots_on_stove": [],
            "stove_zone": stove_tuple,
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
                    "class_id": cls_id, "label": label,
                    "display_name": display_name, "confidence": conf,
                    "bbox": (x1, y1, x2, y2),
                }

                if cls_id == 0:
                    detections["persons"] += 1
                detections["kitchen_objects"].append(obj)

                cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
                if cls_id in POT_CLASSES and sz_x <= cx <= sz_x + sz_w and sz_y <= cy <= sz_y + sz_h:
                    detections["pots_on_stove"].append(obj)

        # Build person mask from YOLO person detections (expanded 25% for clothing)
        person_mask = np.zeros((frame_h, frame_w), dtype=np.uint8)
        if result.boxes is not None:
            for box in result.boxes:
                if int(box.cls[0]) == 0:
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    pw, ph = x2 - x1, y2 - y1
                    pad_x, pad_y = int(pw * 0.15), int(ph * 0.15)
                    x1 = max(0, x1 - pad_x)
                    y1 = max(0, y1 - pad_y)
                    x2 = min(frame_w, x2 + pad_x)
                    y2 = min(frame_h, y2 + pad_y)
                    cv2.rectangle(person_mask, (x1, y1), (x2, y2), 255, -1)

        fire_regions, fire_cov, fire_valid = self.detect_fire(frame, stove_tuple, person_mask)
        detections["fire"] = fire_regions
        detections["fire_coverage"] = fire_cov
        detections["fire_has_valid"] = fire_valid

        smoke_regions, smoke_cov = self.detect_smoke(frame, person_mask, stove_tuple)
        detections["smoke"] = smoke_regions
        detections["smoke_coverage"] = smoke_cov

        return detections
