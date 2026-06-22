import threading
import time
import winsound


class SoundAlarm:
    def __init__(self):
        self.playing = False
        self.thread = None
        self._alarm_active = False
        self._alarm_type = None

    def _beep_fire(self):
        while self._alarm_active:
            for freq in [880, 660, 880, 660]:
                if not self._alarm_active:
                    break
                try:
                    winsound.Beep(freq, 200)
                except Exception:
                    pass
                time.sleep(0.05)

    def _beep_unattended(self):
        while self._alarm_active:
            if not self._alarm_active:
                break
            try:
                winsound.Beep(660, 400)
            except Exception:
                pass
            time.sleep(0.8)
            if not self._alarm_active:
                break
            try:
                winsound.Beep(660, 400)
            except Exception:
                pass
            time.sleep(2.0)

    def start_fire(self):
        if self.playing:
            return
        self._alarm_active = True
        self.playing = True
        self._alarm_type = "fire"
        self.thread = threading.Thread(target=self._beep_fire, daemon=True)
        self.thread.start()

    def start_unattended(self):
        if self.playing:
            return
        self._alarm_active = True
        self.playing = True
        self._alarm_type = "unattended"
        self.thread = threading.Thread(target=self._beep_unattended, daemon=True)
        self.thread.start()

    def stop(self):
        self._alarm_active = False
        self.playing = False
        self._alarm_type = None

    def beep_once(self, freq=880, duration=500):
        try:
            winsound.Beep(freq, duration)
        except Exception:
            pass
