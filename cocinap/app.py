"""CocinaP - Native Windows Application (PySide6)"""
import sys
import os
import math
import time
import traceback
from datetime import datetime

from PySide6.QtCore import Qt, QTimer, QRectF, QPointF, Signal, Slot
from PySide6.QtGui import (
    QImage, QPixmap, QPainter, QColor, QPen, QBrush,
    QFont, QCursor, QAction, QCloseEvent, QIcon,
)
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTabWidget, QLabel, QPushButton, QScrollArea,
    QGroupBox, QDoubleSpinBox, QSpinBox, QCheckBox, QListWidget,
    QListWidgetItem, QMessageBox, QStatusBar, QFrame, QSizePolicy,
    QFormLayout, QComboBox, QSystemTrayIcon, QMenu, QSplashScreen,
)

import numpy as np
import cv2

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from cocinap.engine import CocinaPEngine
from cocinap.camera.handler import CameraHandler
import cocinap.config as cfg


def _global_excepthook(exc_type, exc_value, exc_tb):
    msg = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    crash_log = os.path.join(cfg._APP_DATA, "logs", "crash.log")
    try:
        with open(crash_log, "a") as f:
            f.write(f"\n=== {datetime.now()} ===\n{msg}\n")
    except Exception:
        pass
    box = QMessageBox()
    box.setIcon(QMessageBox.Critical)
    box.setWindowTitle("CocinaP - Error")
    box.setText("Ocurrio un error inesperado")
    box.setDetailedText(msg)
    box.exec()


sys.excepthook = _global_excepthook


class StoveZoneWidget(QWidget):
    changed = Signal(float, float, float, float)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumSize(320, 180)
        self.setMouseTracking(True)
        self.x = 0.25
        self.y = 0.35
        self.w = 0.50
        self.h = 0.45
        self._drag_mode = None
        self._drag_start = None
        self._drag_orig = None

    def set_values(self, x, y, w, h):
        self.x, self.y, self.w, self.h = x, y, w, h
        self.update()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        W, H = self.width(), self.height()
        p.fillRect(0, 0, W, H, QColor(26, 26, 46))
        p.setPen(QPen(QColor(42, 42, 62), 0.5))
        for i in range(11):
            p.drawLine(int(i * W / 10), 0, int(i * W / 10), H)
            p.drawLine(0, int(i * H / 10), W, int(i * H / 10))
        rx, ry = self.x * W, self.y * H
        rw, rh = self.w * W, self.h * H
        p.fillRect(QRectF(rx, ry, rw, rh), QColor(76, 175, 80, 64))
        p.setPen(QPen(QColor(76, 175, 80), 2))
        p.drawRect(QRectF(rx, ry, rw, rh))
        p.setBrush(QBrush(QColor(255, 152, 0, 38)))
        p.setPen(Qt.NoPen)
        for px, py in [(0.25, 0.3), (0.75, 0.3), (0.25, 0.7), (0.75, 0.7)]:
            br = min(rw, rh) * 0.12
            p.drawEllipse(QPointF(rx + px * rw, ry + py * rh), br, br)
        hs = 5
        p.setBrush(QBrush(QColor(76, 175, 80)))
        p.setPen(QPen(QColor(255, 255, 255), 1))
        for cx, cy in [(rx, ry), (rx+rw, ry), (rx, ry+rh), (rx+rw, ry+rh)]:
            p.drawRect(QRectF(cx-hs, cy-hs, hs*2, hs*2))
        p.setBrush(QBrush(QColor(129, 199, 132)))
        p.setPen(Qt.NoPen)
        for mx, my in [(rx+rw/2, ry), (rx+rw/2, ry+rh), (rx, ry+rh/2), (rx+rw, ry+rh/2)]:
            p.drawEllipse(QPointF(mx, my), 3, 3)
        p.setPen(QColor(255, 255, 255, 128))
        p.setFont(QFont("Segoe UI", 9))
        p.drawText(QRectF(rx+4, ry+4, rw-8, 16), Qt.AlignLeft,
                   f"{int(self.w*100)}% x {int(self.h*100)}%")

    def _hit_test(self, pos):
        W, H = self.width(), self.height()
        rx, ry = self.x * W, self.y * H
        rw, rh = self.w * W, self.h * H
        tol = 8
        corners = [("tl", rx, ry), ("tr", rx+rw, ry), ("bl", rx, ry+rh), ("br", rx+rw, ry+rh)]
        for mode, cx, cy in corners:
            if math.hypot(pos.x() - cx, pos.y() - cy) <= tol:
                return mode
        if rx <= pos.x() <= rx+rw and abs(pos.y() - ry) <= tol: return "t"
        if rx <= pos.x() <= rx+rw and abs(pos.y() - (ry+rh)) <= tol: return "b"
        if ry <= pos.y() <= ry+rh and abs(pos.x() - rx) <= tol: return "l"
        if ry <= pos.y() <= ry+rh and abs(pos.x() - (rx+rw)) <= tol: return "r"
        if rx <= pos.x() <= rx+rw and ry <= pos.y() <= ry+rh:
            return "move"
        return None

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            mode = self._hit_test(event.position())
            if mode:
                self._drag_mode = mode
                self._drag_start = event.position()
                self._drag_orig = (self.x, self.y, self.w, self.h)

    def mouseMoveEvent(self, event):
        if self._drag_mode and event.buttons() & Qt.LeftButton:
            pos = event.position()
            dx = (pos.x() - self._drag_start.x()) / self.width()
            dy = (pos.y() - self._drag_start.y()) / self.height()
            ox, oy, ow, oh = self._drag_orig
            nx, ny, nw, nh = ox, oy, ow, oh
            m = self._drag_mode
            if m == "move":
                nx = max(0, min(1 - ow, ox + dx))
                ny = max(0, min(1 - oh, oy + dy))
            elif m in ("r", "tr", "br", "e"):
                nw = max(0.05, min(1 - ox, ow + dx))
            elif m in ("l", "tl", "bl"):
                dw = min(dx, ow - 0.05)
                nx = ox + dw; nw = ow - dw
            elif m in ("b", "s"):
                nh = max(0.05, min(1 - oy, oh + dy))
            elif m in ("t", "n"):
                dh = min(dy, oh - 0.05)
                ny = oy + dh; nh = oh - dh
            elif m == "tl":
                dw = min(dx, ow - 0.05); dh = min(dy, oh - 0.05)
                nx = ox + dw; ny = oy + dh; nw = ow - dw; nh = oh - dh
            elif m == "tr":
                dh = min(dy, oh - 0.05); ny = oy + dh
                nw = max(0.05, min(1 - ox, ow + dx)); nh = oh - dh
            elif m == "bl":
                dw = min(dx, ow - 0.05); nx = ox + dw
                nw = ow - dw; nh = max(0.05, min(1 - oy, oh + dy))
            elif m == "br":
                nw = max(0.05, min(1 - ox, ow + dx))
                nh = max(0.05, min(1 - oy, oh + dy))
            if nx < 0: nw += nx; nx = 0
            if ny < 0: nh += ny; ny = 0
            if nx + nw > 1: nw = 1 - nx
            if ny + nh > 1: nh = 1 - ny
            nw, nh = max(0.05, nw), max(0.05, nh)
            self.x, self.y, self.w, self.h = nx, ny, nw, nh
            self.changed.emit(nx, ny, nw, nh)
            self.update()
        else:
            mode = self._hit_test(event.position())
            cursors = {
                "tl": Qt.SizeFDiagCursor, "br": Qt.SizeFDiagCursor,
                "tr": Qt.SizeBDiagCursor, "bl": Qt.SizeBDiagCursor,
                "t": Qt.SizeVerCursor, "b": Qt.SizeVerCursor,
                "l": Qt.SizeHorCursor, "r": Qt.SizeHorCursor,
                "move": Qt.SizeAllCursor,
            }
            self.setCursor(QCursor(cursors.get(mode, Qt.ArrowCursor)))

    def mouseReleaseEvent(self, event):
        self._drag_mode = None
        self._drag_start = None
        self._drag_orig = None


class CameraTab(QWidget):
    def __init__(self, engine, camera, parent=None):
        super().__init__(parent)
        self.engine = engine
        self.camera = camera
        self._running = False

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.video_label = QLabel()
        self.video_label.setAlignment(Qt.AlignCenter)
        self.video_label.setStyleSheet("background:#111")
        self.video_label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        layout.addWidget(self.video_label, 1)

        status_bar = QFrame()
        status_bar.setStyleSheet("background:#1a1a1a;border-radius:4px;padding:6px")
        s_layout = QHBoxLayout(status_bar)
        s_layout.setContentsMargins(8, 4, 8, 4)

        self.fire_label = QLabel("Fuego: 0")
        self.smoke_label = QLabel("Humo: 0")
        self.person_label = QLabel("Personas: 0")
        self.status_label = QLabel("Iniciando...")
        self.fps_label = QLabel("0 FPS")
        for lbl in [self.fire_label, self.smoke_label, self.person_label, self.status_label, self.fps_label]:
            lbl.setStyleSheet("color:#ccc;font-size:12px;padding:2px 8px")
            s_layout.addWidget(lbl)
        s_layout.addStretch()
        layout.addWidget(status_bar)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self._update_frame)

    def start(self):
        self._running = True
        self.timer.start(30)

    def stop(self):
        self._running = False
        self.timer.stop()

    def _update_frame(self):
        if not self._running:
            return
        try:
            frame = self.camera.get_frame() if self.camera else None
            if frame is None:
                return
            self.engine.track_fps()
            dets = self.engine.get_latest()
            alerts, _, _ = self.engine.analyze(dets)
            unattended = self.engine.get_unattended(dets)
            status_text, status_color = self.engine.get_status(alerts, dets)
            display = self.engine.draw(frame, dets, alerts, status_text, status_color, self.engine.fps, unattended)

            rgb = cv2.cvtColor(display, cv2.COLOR_BGR2RGB)
            h, w, ch = rgb.shape
            img = QImage(rgb.data, w, h, ch * w, QImage.Format_RGB888)
            pix = QPixmap.fromImage(img)
            scaled = pix.scaled(self.video_label.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self.video_label.setPixmap(scaled)

            self.fire_label.setText(f"Fuego: {len(dets.get('fire', []))}")
            self.smoke_label.setText(f"Humo: {len(dets.get('smoke', []))}")
            self.person_label.setText(f"Personas: {dets.get('persons', 0)}")
            self.status_label.setText(status_text)
            self.fps_label.setText(f"{self.engine.fps:.0f} FPS")
        except Exception:
            pass


class ConfigTab(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)

        stove_group = QGroupBox("Zona Estufa")
        stove_group.setStyleSheet("QGroupBox{color:#ff9800;font-weight:bold;border:1px solid #333;border-radius:6px;margin-top:8px;padding-top:16px} QGroupBox::title{subcontrol-origin:margin;left:10px;padding:0 4px}")
        stove_inner = QVBoxLayout(stove_group)
        stove_inner.addWidget(QLabel("Arrastra el rectangulo para ajustar la zona"))
        self.sz_widget = StoveZoneWidget()
        stove_inner.addWidget(self.sz_widget)

        sz_spins = QHBoxLayout()
        self.sz_x = QDoubleSpinBox(); self.sz_x.setRange(0, 0.9); self.sz_x.setSingleStep(0.01); self.sz_x.setDecimals(2)
        self.sz_y = QDoubleSpinBox(); self.sz_y.setRange(0, 0.9); self.sz_y.setSingleStep(0.01); self.sz_y.setDecimals(2)
        self.sz_w = QDoubleSpinBox(); self.sz_w.setRange(0.05, 1); self.sz_w.setSingleStep(0.01); self.sz_w.setDecimals(2)
        self.sz_h = QDoubleSpinBox(); self.sz_h.setRange(0.05, 1); self.sz_h.setSingleStep(0.01); self.sz_h.setDecimals(2)
        for spin, label in [(self.sz_x, "X"), (self.sz_y, "Y"), (self.sz_w, "Ancho"), (self.sz_h, "Alto")]:
            f_layout = QVBoxLayout()
            f_layout.addWidget(QLabel(label))
            f_layout.addWidget(spin)
            sz_spins.addLayout(f_layout)
        stove_inner.addLayout(sz_spins)

        self.sz_widget.changed.connect(lambda x, y, w, h: (
            self.sz_x.setValue(x), self.sz_y.setValue(y),
            self.sz_w.setValue(w), self.sz_h.setValue(h),
            cfg.STOVE_ZONE.update({"x": x, "y": y, "w": w, "h": h}),
            cfg.save_config()
        ))
        for spin, attr in [(self.sz_x, 'x'), (self.sz_y, 'y'), (self.sz_w, 'w'), (self.sz_h, 'h')]:
            spin.valueChanged.connect(lambda v, a=attr: (
                setattr(self.sz_widget, a, v), self.sz_widget.update()
            ))
        layout.addWidget(stove_group)

        cam_group = QGroupBox("Camara")
        cam_group.setStyleSheet("QGroupBox{color:#ff9800;font-weight:bold;border:1px solid #333;border-radius:6px;margin-top:8px;padding-top:16px} QGroupBox::title{subcontrol-origin:margin;left:10px;padding:0 4px}")
        cam_layout = QFormLayout(cam_group)
        self.cam_combo = QComboBox()
        for i in range(10):
            self.cam_combo.addItem(f"Camara {i}", i)
        self.cam_combo.setCurrentIndex(cfg.CAMERA_ID)
        self.cam_combo.currentIndexChanged.connect(self._on_camera_change)
        cam_layout.addRow("Dispositivo:", self.cam_combo)

        self.auto_start_cb = QCheckBox("Iniciar con Windows")
        self.auto_start_cb.setChecked(cfg.AUTO_START)
        self.auto_start_cb.toggled.connect(self._on_auto_start)
        cam_layout.addRow("", self.auto_start_cb)
        layout.addWidget(cam_group)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea{border:none}")
        scroll.setFrameShape(QFrame.NoFrame)
        params_widget = QWidget()
        self._params_layout = QVBoxLayout(params_widget)
        scroll.setWidget(params_widget)
        layout.addWidget(scroll, 1)

        self._param_spins = {}
        last_cat = ""
        for key, label, typ, mn, mx, step in cfg.CFG_META:
            cat = key.split("_")[0]
            if cat != last_cat:
                gb = QGroupBox(cat)
                gb.setStyleSheet("QGroupBox{color:#ff9800;font-weight:bold;border:1px solid #333;border-radius:6px;margin-top:8px;padding-top:16px;padding-right:4px;padding-bottom:4px;padding-left:4px} QGroupBox::title{subcontrol-origin:margin;left:10px;padding:0 4px}")
                self._params_layout.addWidget(gb)
                self._current_group = gb
                self._current_group_layout = QFormLayout(gb)
                last_cat = cat

            current_val = getattr(cfg, key, 0)
            if typ == "float":
                spin = QDoubleSpinBox()
                spin.setRange(mn, mx)
                spin.setSingleStep(step)
                spin.setDecimals(4)
            else:
                spin = QSpinBox()
                spin.setRange(int(mn), int(mx))
                spin.setSingleStep(int(step))
            spin.setValue(current_val)
            spin.valueChanged.connect(lambda v, k=key, t=typ: (
                setattr(cfg, k, float(v) if t == "float" else int(v)),
                cfg.save_config()
            ))
            self._current_group_layout.addRow(label, spin)
            self._param_spins[key] = spin

    def _on_camera_change(self, idx):
        cfg.CAMERA_ID = idx
        cfg.save_config()
        QMessageBox.information(self, "Camara", f"Camara {idx} seleccionada.\nReinicie la app para aplicar el cambio.")

    def _on_auto_start(self, checked):
        cfg.AUTO_START = checked
        cfg.save_config()
        key = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
        if checked:
            if getattr(sys, 'frozen', False):
                exe = sys.executable
            else:
                exe = f'"{sys.executable}" "{__file__}"'
            os.system(f'REG ADD "{key}" /V "CocinaP" /t REG_SZ /F /D "{exe}"')
        else:
            os.system(f'REG DELETE "{key}" /V "CocinaP" /F 2>nul')

    def load_values(self):
        for key, spin in self._param_spins.items():
            spin.setValue(getattr(cfg, key, 0))
        sz = cfg.STOVE_ZONE
        self.sz_widget.set_values(sz["x"], sz["y"], sz["w"], sz["h"])
        self.sz_x.setValue(sz["x"]); self.sz_y.setValue(sz["y"])
        self.sz_w.setValue(sz["w"]); self.sz_h.setValue(sz["h"])
        self.cam_combo.setCurrentIndex(cfg.CAMERA_ID)
        self.auto_start_cb.setChecked(cfg.AUTO_START)


class AlarmsTab(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)

        top = QHBoxLayout()
        top.addWidget(QLabel("Ultimas alarmas"))
        top.addStretch()
        clear_btn = QPushButton("Limpiar")
        clear_btn.setStyleSheet("QPushButton{background:#333;color:#eee;padding:4px 12px;border-radius:4px}")
        clear_btn.clicked.connect(self._clear)
        top.addWidget(clear_btn)
        layout.addLayout(top)

        self.list_widget = QListWidget()
        self.list_widget.setStyleSheet("QListWidget{background:#1a1a1a;border:1px solid #333;border-radius:4px;padding:4px} QListWidget::item{padding:6px;border-bottom:1px solid #2a2a2a}")
        layout.addWidget(self.list_widget, 1)

    def add_alarm(self, alarm):
        text = f"[{alarm.get('time','')}] [{alarm.get('severity','')}] {alarm.get('message','')}"
        item = QListWidgetItem(text)
        sev = alarm.get("severity", "")
        color = {"CRITICO": "#f44336", "ALTO": "#ff9800", "MEDIO": "#ffeb3b", "BAJO": "#4caf50"}.get(sev, "#888")
        item.setForeground(QColor(color))
        self.list_widget.insertItem(0, item)
        if self.list_widget.count() > 100:
            self.list_widget.takeItem(self.list_widget.count() - 1)

    def _clear(self):
        self.list_widget.clear()


class MainWindow(QMainWindow):
    def __init__(self, splash=None):
        super().__init__()
        self.setWindowTitle("CocinaP - Seguridad en Cocina")
        self.setMinimumSize(960, 680)
        self.resize(1280, 800)
        self.setStyleSheet("QMainWindow{background:#111} QWidget{color:#eee;font-family:'Segoe UI',sans-serif}")

        self._splash = splash

        self.camera = None
        self._camera_ok = False
        self._init_camera()

        self.engine = CocinaPEngine(
            self.camera.get_frame if self._camera_ok else (lambda: None),
            web_port=cfg.WEB_PORT,
        )

        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(8, 8, 8, 8)

        self.tabs = QTabWidget()
        self.tabs.setStyleSheet("QTabWidget::pane{border:1px solid #333;border-radius:4px;background:#1a1a1a} QTabBar::tab{background:#222;color:#aaa;padding:8px 16px;border:1px solid #333;border-bottom:none;border-radius:4px 4px 0 0;margin-right:2px} QTabBar::tab:selected{background:#1a1a1a;color:#ff9800;font-weight:bold}")
        layout.addWidget(self.tabs, 1)

        self.cam_tab = CameraTab(self.engine, self.camera)
        self.config_tab = ConfigTab()
        self.alarms_tab = AlarmsTab()

        self.tabs.addTab(self.cam_tab, "Camara")
        self.tabs.addTab(self.config_tab, "Config")
        self.tabs.addTab(self.alarms_tab, "Alarmas")

        self.status_bar = QStatusBar()
        self.status_bar.setStyleSheet("QStatusBar{background:#1a1a1a;border-top:1px solid #333;color:#888;font-size:12px}")
        self.setStatusBar(self.status_bar)
        self._update_status_bar()

        menu = self.menuBar()
        menu.setStyleSheet("QMenuBar{background:#1a1a1a;color:#ccc} QMenuBar::item:selected{background:#333} QMenu{background:#1a1a1a;color:#ccc;border:1px solid #333} QMenu::item:selected{background:#ff9800;color:#111}")
        file_menu = menu.addMenu("Archivo")
        exit_action = QAction("Salir", self)
        exit_action.setShortcut("Ctrl+Q")
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)

        help_menu = menu.addMenu("Ayuda")
        about_action = QAction("Acerca de", self)
        about_action.triggered.connect(lambda: QMessageBox.about(self, "CocinaP", "CocinaP v1.0.1\nSistema de Seguridad en Cocina\nDeteccion de fuego, humo y cocina desatendida"))
        help_menu.addAction(about_action)

        self._tray_icon = None
        self._setup_tray()

        self.engine.start()
        QTimer.singleShot(500, self._finish_init)

    def _init_camera(self):
        try:
            self.camera = CameraHandler()
            self.camera.start()
            self._camera_ok = True
        except Exception as e:
            print(f"[app] Camara no disponible: {e}")

    def _finish_init(self):
        if self._camera_ok:
            self.cam_tab.start()
        self.config_tab.load_values()
        if self.engine.webui:
            self.engine.webui.push_status({"fire": [], "smoke": [], "persons": 0, "fire_coverage": 0, "smoke_coverage": 0, "pots_on_stove": []}, [], "Sistema listo" if self._camera_ok else "Sin camara")
        self._update_status_bar()

        if self._splash:
            self._splash.close()

        self._status_timer = QTimer(self)
        self._status_timer.timeout.connect(self._poll_status)
        self._status_timer.start(500)

    def _update_status_bar(self):
        if not self._camera_ok:
            self.status_bar.showMessage("Sin camara - solo configuracion")
        else:
            self.status_bar.showMessage("Sistema listo")

    def _setup_tray(self):
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return
        self._tray_icon = QSystemTrayIcon(self)
        self._tray_icon.setToolTip("CocinaP - Seguridad en Cocina")
        tray_menu = QMenu()
        show_action = tray_menu.addAction("Mostrar/Ocultar")
        show_action.triggered.connect(self._toggle_visible)
        tray_menu.addSeparator()
        quit_action = tray_menu.addAction("Salir")
        quit_action.triggered.connect(self.close)
        self._tray_icon.setContextMenu(tray_menu)
        self._tray_icon.activated.connect(self._tray_activated)
        self._tray_icon.show()

    def _tray_activated(self, reason):
        if reason == QSystemTrayIcon.DoubleClick:
            self._toggle_visible()

    def _toggle_visible(self):
        if self.isVisible():
            self.hide()
        else:
            self.show()
            self.raise_()
            self.activateWindow()

    def _poll_status(self):
        try:
            dets = self.engine.get_latest()
            alerts, _, _ = self.engine.analyze(dets)
            status_text, _ = self.engine.get_status(alerts, dets)
            self.status_bar.showMessage(status_text)
            if alerts:
                worst = max(alerts, key=lambda a: {"CRITICO": 3, "ALTO": 2, "MEDIO": 1, "BAJO": 0}.get(a.get("severity", ""), 0))
                self.alarms_tab.add_alarm(worst)
                if self._tray_icon and not self.isVisible():
                    self._tray_icon.showMessage(
                        "CocinaP - Alarma",
                        f"[{worst.get('severity','')}] {worst.get('message','')}",
                        QSystemTrayIcon.Warning,
                        5000
                    )
        except Exception:
            pass

    def closeEvent(self, event: QCloseEvent):
        self.cam_tab.stop()
        self.engine.stop()
        if self.camera:
            self.camera.stop()
        event.accept()


def _create_splash():
    pixmap = QPixmap(400, 250)
    pixmap.fill(QColor(26, 26, 46))
    p = QPainter(pixmap)
    p.setRenderHint(QPainter.Antialiasing)
    p.setPen(QColor(255, 152, 0))
    p.setFont(QFont("Segoe UI", 22, QFont.Bold))
    p.drawText(pixmap.rect(), Qt.AlignCenter, "CocinaP")
    p.setPen(QColor(255, 255, 255, 180))
    p.setFont(QFont("Segoe UI", 10))
    p.drawText(pixmap.rect().adjusted(0, 40, 0, 0), Qt.AlignCenter, "Seguridad en Cocina")
    p.setPen(QColor(255, 255, 255, 100))
    p.setFont(QFont("Segoe UI", 8))
    p.drawText(pixmap.rect().adjusted(0, 0, 0, -20), Qt.AlignBottom | Qt.AlignHCenter, "Cargando...")
    p.end()
    splash = QSplashScreen(pixmap)
    splash.show()
    return splash


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("CocinaP")
    app.setOrganizationName("CocinaP")

    sys.excepthook = _global_excepthook

    splash = _create_splash()
    app.processEvents()

    window = MainWindow(splash=splash)
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
