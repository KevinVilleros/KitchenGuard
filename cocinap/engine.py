import time
from cocinap.detector.runner import DetectionRunner
from cocinap.analyzer.risk_analyzer import RiskAnalyzer
from cocinap.alarm.sound_alarm import SoundAlarm
from cocinap.utils.visuals import draw_detections
from cocinap.webui import WebUI


class CocinaPEngine:
    def __init__(self, get_frame_cb=None, web_port=None):
        self.runner = DetectionRunner(get_frame_cb)
        self.analyzer = RiskAnalyzer()
        self.alarm = SoundAlarm()
        self.webui = WebUI(
            port=web_port or 8080,
            get_frame_cb=(lambda: self.runner.last_frame) if get_frame_cb else None,
        ) if web_port is not None else None
        self.fps = 0
        self._frame_count = 0
        self._fps_timer = time.time()

    def start(self):
        self.runner.start()
        if self.webui:
            self.webui.start()

    def stop(self):
        self.runner.stop()
        self.alarm.stop()
        if self.webui:
            self.webui.stop()

    def submit_frame(self, frame):
        self.runner.submit_frame(frame)

    def get_latest(self):
        return self.runner.get_latest()

    def analyze(self, dets):
        alerts = self.analyzer.analyze(dets)
        trigger, alarm_type = self.analyzer.should_trigger_alarm(alerts)
        if trigger:
            if alarm_type == "fire":
                self.alarm.start_fire()
            elif alarm_type == "smoke":
                self.alarm.start_smoke()
            elif alarm_type == "unattended":
                self.alarm.start_unattended()
            if self.webui:
                self.webui.send_fcm(alerts)
        elif not alerts:
            self.alarm.stop()

        if self.webui:
            status_text, _ = self.get_status(alerts, dets)
            self.webui.push_status(dets, alerts, status_text)

        return alerts, trigger, alarm_type

    def get_unattended(self, dets):
        if not dets.get("persons", 0) > 0 and len(dets.get("pots_on_stove", [])) > 0:
            return (time.time() - self.analyzer.last_person_time) / 60.0
        return 0

    def get_status(self, alerts, dets):
        return (
            self.analyzer.get_status_text(alerts, dets),
            self.analyzer.get_status_color(alerts),
        )

    def track_fps(self):
        self._frame_count += 1
        now = time.time()
        if now - self._fps_timer >= 0.5:
            self.fps = self._frame_count / (now - self._fps_timer + 0.001)
            self._frame_count = 0
            self._fps_timer = now
        return self.fps

    def draw(self, frame, dets, alerts, status_text, status_color, fps, unattended=0):
        return draw_detections(
            frame, dets, alerts,
            status_text, status_color, fps,
            unattended_minutes=unattended,
        )
