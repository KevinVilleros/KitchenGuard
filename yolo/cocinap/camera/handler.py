import cv2
import threading
import time
import re
from cocinap.config import CAMERA_ID, CAMERA_URL, CAMERA_WIDTH, CAMERA_HEIGHT, CAMERA_FPS

_RTSP_PATTERN = re.compile(r"^(rtsp|rtmp|http|https)://", re.IGNORECASE)
_RECONNECT_DELAY = 3
_MAX_RECONNECT_ATTEMPTS = 0  # infinite


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
        self.source = None
        self.is_network = False
        self.connected = False

    def start(self):
        self.source = CAMERA_URL.strip() if CAMERA_URL else None
        self.is_network = bool(self.source and _RTSP_PATTERN.match(self.source))

        self.running = True
        self.thread = threading.Thread(target=self._capture_loop, daemon=True)
        self.thread.start()
        return self

    def _open_capture(self):
        """Open video capture for local device or network stream."""
        if self.cap:
            self.cap.release()
            self.cap = None

        if self.is_network:
            self.cap = cv2.VideoCapture(self.source, cv2.CAP_FFMPEG)
            self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        else:
            cam_id = CAMERA_ID
            self.cap = cv2.VideoCapture(cam_id, cv2.CAP_DSHOW)
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)
            self.cap.set(cv2.CAP_PROP_FPS, CAMERA_FPS)

        if self.cap.isOpened():
            self.connected = True
            return True

        self.connected = False
        return False

    def _capture_loop(self):
        attempts = 0
        while self.running:
            if not self._open_capture():
                if self.is_network:
                    attempts += 1
                    if _MAX_RECONNECT_ATTEMPTS and attempts >= _MAX_RECONNECT_ATTEMPTS:
                        print(f"[camera] Maximo de reconexiones alcanzado ({attempts})")
                        break
                    print(f"[camera] No se pudo conectar a {self.source}. Reintento {_RECONNECT_DELAY}s...")
                    time.sleep(_RECONNECT_DELAY)
                else:
                    print(f"[camera] No se pudo abrir camara {CAMERA_ID}")
                    break
                continue

            if self.is_network:
                print(f"[camera] Conectado a {self.source}")
            else:
                print(f"[camera] Camara {CAMERA_ID} abierta")

            attempts = 0
            consecutive_fails = 0

            while self.running:
                ret, frame = self.cap.read()
                if ret:
                    consecutive_fails = 0
                    with self.lock:
                        self.frame = frame
                    self._frame_count += 1
                    elapsed = time.time() - self._fps_timer
                    if elapsed >= 1.0:
                        self.fps = self._frame_count / elapsed
                        self._frame_count = 0
                        self._fps_timer = time.time()
                else:
                    consecutive_fails += 1
                    if self.is_network and consecutive_fails > 30:
                        print(f"[camera] Stream perdido de {self.source}. Reconectando...")
                        self.connected = False
                        break
                    time.sleep(0.01 if not self.is_network else 0.1)

    def get_frame(self):
        with self.lock:
            if self.frame is None:
                return None
            return self.frame.copy()

    def stop(self):
        self.running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=5)
        if self.cap:
            self.cap.release()

    def get_source_info(self):
        """Return info about current video source."""
        if self.is_network:
            return {"type": "network", "url": self.source, "connected": self.connected}
        return {"type": "local", "id": CAMERA_ID, "connected": self.connected}
