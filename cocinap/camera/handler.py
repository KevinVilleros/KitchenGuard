import cv2
import threading
import time
from cocinap.config import CAMERA_ID, CAMERA_WIDTH, CAMERA_HEIGHT, CAMERA_FPS


class CameraHandler:
    def __init__(self):
        self.cap = None
        self.running = False
        self.frame = None
        self.lock = threading.Lock()
        self.thread = None
        self.fps = 0
        self._frame_count = 0
        self._fps_timer = time.time()

    def start(self):
        self.cap = cv2.VideoCapture(CAMERA_ID, cv2.CAP_DSHOW)
        if not self.cap.isOpened():
            raise RuntimeError(f"No se pudo abrir la cámara {CAMERA_ID}")

        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)
        self.cap.set(cv2.CAP_PROP_FPS, CAMERA_FPS)

        self.running = True
        self.thread = threading.Thread(target=self._capture_loop, daemon=True)
        self.thread.start()
        return self

    def _capture_loop(self):
        while self.running:
            ret, frame = self.cap.read()
            if ret:
                with self.lock:
                    self.frame = frame
                self._frame_count += 1
                elapsed = time.time() - self._fps_timer
                if elapsed >= 1.0:
                    self.fps = self._frame_count / elapsed
                    self._frame_count = 0
                    self._fps_timer = time.time()
            else:
                time.sleep(0.01)

    def get_frame(self):
        with self.lock:
            if self.frame is None:
                return None
            return self.frame.copy()

    def stop(self):
        self.running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=2)
        if self.cap:
            self.cap.release()
