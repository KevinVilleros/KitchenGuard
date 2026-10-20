import threading
import time
import ctypes

kernel32 = ctypes.windll.kernel32


class SoundAlarm:
    def __init__(self):
        self.playing = False
        self.thread = None
        self._alarm_active = False
        self._alarm_type = None
        self._lock = threading.Lock()

    def _beep_async(self, freq, duration):
        kernel32.Beep(ctypes.c_int(freq), ctypes.c_int(duration))

    def _stop_beep(self):
        kernel32.Beep(ctypes.c_int(0), ctypes.c_int(0))

    def _beep_pattern(self, pattern):
        while self._alarm_active:
            for freq, dur, slp in pattern:
                if not self._alarm_active:
                    return
                try:
                    self._beep_async(freq, dur)
                except Exception:
                    pass
                if slp > 0:
                    time.sleep(slp)

    def start_fire(self):
        with self._lock:
            if self.playing:
                return
            self._alarm_active = True
            self.playing = True
            self._alarm_type = "fire"
            pattern = [(880, 200, 0.05), (660, 200, 0.05), (880, 200, 0.05), (660, 200, 0.05)]
            self.thread = threading.Thread(target=self._beep_pattern, args=(pattern,), daemon=True)
            self.thread.start()

    def start_smoke(self):
        with self._lock:
            if self.playing:
                return
            self._alarm_active = True
            self.playing = True
            self._alarm_type = "smoke"
            pattern = [(1200, 150, 0.3), (900, 150, 0.3), (1200, 150, 0.3)]
            self.thread = threading.Thread(target=self._beep_pattern, args=(pattern,), daemon=True)
            self.thread.start()

    def start_unattended(self):
        with self._lock:
            if self.playing:
                return
            self._alarm_active = True
            self.playing = True
            self._alarm_type = "unattended"
            pattern = [(660, 200, 0.80), (660, 200, 0.80), (660, 200, 2.0)]
            self.thread = threading.Thread(target=self._beep_pattern, args=(pattern,), daemon=True)
            self.thread.start()

    def stop(self):
        with self._lock:
            self._alarm_active = False
            self.playing = False
            self._alarm_type = None
        self._stop_beep()
