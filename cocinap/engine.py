import time
from cocinap.detector.runner import DetectionRunner
from cocinap.analyzer.risk_analyzer import RiskAnalyzer
from cocinap.alarm.sound_alarm import SoundAlarm
from cocinap.utils.visuals import draw_detections
from cocinap.webui import WebUI
import cocinap.config as cfg


class CocinaPEngine:
    def __init__(self, get_frame_cb=None, web_port=None):
        self.runner = DetectionRunner(get_frame_cb)
        self.analyzer = RiskAnalyzer()
        self.alarm = SoundAlarm()
        self.webui = WebUI(
            port=web_port or 8080,
            get_frame_cb=(lambda: self.runner.last_frame) if get_frame_cb else None,
            engine=self,
        ) if web_port is not None else None
        self.fps = 0
        self._frame_count = 0
        self._fps_timer = time.time()

        # Kitchen timer state
        self.timer_running = False
        self.timer_start_ts = 0.0
        self.timer_paused = False
        self.timer_paused_remaining = 0.0
        self.timer_duration = 0.0  # seconds
        self._timer_expired_notified = False

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

    # ---- Kitchen timer ----
    def timer_get_state(self):
        if not self.timer_running:
            return {"running": False, "remaining": 0, "duration": 0}
        if self.timer_paused:
            remaining = self.timer_paused_remaining
        else:
            elapsed = time.time() - self.timer_start_ts
            remaining = max(0, self.timer_duration - elapsed)
        return {
            "running": True,
            "remaining": int(remaining),
            "duration": int(self.timer_duration),
            "paused": self.timer_paused,
        }

    def timer_start(self, minutes=None):
        if minutes is None:
            minutes = cfg.KITCHEN_TIMER_DURATION
        if minutes <= 0:
            return
        self.timer_duration = minutes * 60
        self.timer_start_ts = time.time()
        self.timer_running = True
        self.timer_paused = False
        self.timer_paused_remaining = 0.0
        self._timer_expired_notified = False
        self.analyzer.reset_session()
        self.analyzer._log_event(f"TIMER INICIADO - plazo {minutes} min")

    def timer_stop(self):
        self.timer_running = False
        self.timer_paused = False
        self.timer_start_ts = 0.0
        self.timer_paused_remaining = 0.0
        self._timer_expired_notified = False

    def timer_pause(self):
        if not self.timer_running or self.timer_paused:
            return
        elapsed = time.time() - self.timer_start_ts
        self.timer_paused_remaining = max(0, self.timer_duration - elapsed)
        self.timer_paused = True

    def timer_resume(self):
        if not self.timer_running or not self.timer_paused:
            return
        self.timer_duration = self.timer_paused_remaining
        self.timer_start_ts = time.time()
        self.timer_paused = False
        self.timer_paused_remaining = 0.0

    # ----

    def is_active(self):
        """The system only operates while the timer window is running."""
        if not self.timer_running or self.timer_paused:
            return False
        return self.timer_get_state()["remaining"] > 0

    # ----

    def analyze(self, dets):
        active = self.is_active()
        timer = self.timer_get_state()

        # Timer just expired: notify once and mark inactive
        if self.timer_running and not self.timer_paused and timer["remaining"] <= 0:
            if not self._timer_expired_notified:
                self._timer_expired_notified = True
                self.alarm.stop()
                self.analyzer._log_event("TIMER TERMINADO - sistema inactivo")
                if self.webui:
                    self.webui.send_fcm_event(
                        "CocinaP - Plazo terminado",
                        "El tiempo de monitoreo finalizó. El sistema está inactivo.",
                        "TIMER_TERMINADO", "MEDIO",
                    )
                    self.webui.push_status(dets, [{
                        "type": "TIMER_TERMINADO", "severity": "MEDIO",
                        "message": "⏰ Plazo terminado - sistema inactivo",
                    }], "⏸ SISTEMA INACTIVO - inicie el plazo", timer)
                return [], False, None
        elif self.timer_running:
            self._timer_expired_notified = False

        if not active:
            self.alarm.stop()
            if self.webui:
                self.webui.push_status(dets, [], "⏸ SISTEMA INACTIVO - inicie el plazo", timer)
            return [], False, None

        alerts = self.analyzer.analyze(
            dets,
            timer_active=active,
            timer_alert_seconds=cfg.KITCHEN_TIMER_ALERT_SECONDS,
            alarm_unattended=cfg.ALARM_UNATTENDED_ENABLED,
            alarm_smoke=cfg.ALARM_SMOKE_ENABLED,
            alarm_fire=cfg.ALARM_FIRE_ENABLED,
        )
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
            self.webui.push_status(dets, alerts, status_text, timer)

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
