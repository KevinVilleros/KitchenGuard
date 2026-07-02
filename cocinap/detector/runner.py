import threading
import time
from cocinap.detector.detector import Detector


_EMPTY_DETECTIONS = {
    "persons": 0,
    "kitchen_objects": [],
    "fire": [], "fire_coverage": 0.0, "fire_has_valid": False,
    "smoke": [], "smoke_coverage": 0.0,
    "pots_on_stove": [],
    "stove_zone": (0, 0, 0, 0),
    "frame_size": (0, 0),
}


class DetectionRunner:
    def __init__(self, get_frame_cb=None):
        self.detector = Detector()
        self.get_frame = get_frame_cb
        self._thread = None
        self._running = False
        self._lock = threading.Lock()
        self.latest = dict(_EMPTY_DETECTIONS)
        self._submitted_frame = None
        self._has_new_frame = False

    def start(self):
        self._running = True
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()
        return self

    def stop(self):
        self._running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)

    def submit_frame(self, frame):
        with self._lock:
            self._submitted_frame = frame.copy()
            self._has_new_frame = True

    def _get_frame(self):
        if self.get_frame:
            return self.get_frame()
        with self._lock:
            if self._has_new_frame:
                self._has_new_frame = False
                return self._submitted_frame
        return None

    def _loop(self):
        while self._running:
            frame = self._get_frame()
            if frame is None:
                time.sleep(0.005)
                continue
            result = self.detector.detect(frame)
            dets = self.detector.get_detection_summary(result, frame)
            with self._lock:
                self.latest = dets

    def get_latest(self):
        with self._lock:
            return dict(self.latest)
