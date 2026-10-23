import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fuente de video del modo independiente.
enum StandaloneCameraSource {
  /// Cámara integrada / USB del propio móvil.
  phone,
  /// Cámara IP del hogar o de seguridad vía stream HTTP/MJPEG.
  ipCamera,
}

/// Modo de repetición de las alertas cuando la cocina sigue desatendida.
enum AlertRepeatMode {
  /// Repite el último intervalo indefinidamente.
  repeatLast,
  /// Emite cada intervalo configurado una sola vez y luego deja de avisar.
  oncePerInterval,
}

/// Resultado de una alerta por cocina desatendida.
class StandaloneAlert {
  final String message;
  final DateTime time;

  /// Minutos transcurridos sin presencia cuando se emitió (0 si no aplica).
  final int atMinute;

  const StandaloneAlert(this.message, this.time, {this.atMinute = 0});
}

/// Plantilla de un intervalo de alerta.
class AlertInterval {
  /// Minutos de ausencia (desde la última detección de persona) a los que se
  /// dispara esta alerta.
  final int minutes;

  const AlertInterval(this.minutes);
}

/// Proveedor del modo standalone: monitoreo con cámara del móvil o cámara IP,
/// temporizador configurable y alertas escalonadas si no hay persona.
///
/// El temporizador "plazo de monitoreo" representa el tiempo estimado de
/// cocción. Dentro de ese plazo, y a medida que pasan minutos sin detectar una
/// persona, se disparan **alertas por intervalos configurables** (por ejemplo a
/// los 10, 15 y 20 minutos), escalando la severidad.
class StandaloneProvider extends ChangeNotifier {
  StandaloneCameraSource _cameraSource = StandaloneCameraSource.phone;
  String _cameraUrl = "";

  // --- Timer de monitoreo (plazo estimado de cocción) ---
  int _durationMinutes = 30;
  int _remainingSeconds = 0;
  bool _timerRunning = false;
  bool _timerPaused = false;
  Timer? _timerTick;

  // --- Detección de persona ---
  bool _personPresent = false;
  DateTime? _lastPersonSeen;
  bool _cameraActive = false;
  double _lastScore = 0;
  int _consecutivePresentFrames = 0;
  int _consecutiveAbsentFrames = 0;
  static const int _presenceConfirmFrames = 2;
  static const int _absenceConfirmFrames = 3;

  // Referencia para medir cuánto tiempo lleva la cocina sin persona:
  // el último momento en que se vio a alguien, o el inicio del monitoreo.
  DateTime? _timerStartedAt;

  // --- Configuración ---
  double _confidence = 0.5;

  /// Umbral corto (segundos) usado como "gracia" inicial antes de considerar
  /// que la cocina está realmente desatendida. Se mantiene por compatibilidad.
  int _noPersonAlertSeconds = 30;

  // --- Alertas por intervalos ---
  bool _intervalAlertsEnabled = true;
  AlertRepeatMode _repeatMode = AlertRepeatMode.repeatLast;
  List<int> _alertIntervals = const [10, 15, 20, 30];

  /// Índices de intervalo ya disparados en el ciclo de ausencia actual.
  final Set<int> _firedIntervals = {};

  // Minutos peligrosos estimados (para clasificar severidad).
  int _dangerMinutes = 5;

  final List<StandaloneAlert> _alerts = [];
  bool _alerted = false;
  DateTime? _lastAlertAt;

  StandaloneCameraSource get cameraSource => _cameraSource;
  String get cameraUrl => _cameraUrl;
  int get durationMinutes => _durationMinutes;
  int get remainingSeconds => _remainingSeconds;
  bool get timerRunning => _timerRunning;
  bool get timerPaused => _timerPaused;
  bool get personPresent => _personPresent;
  bool get cameraActive => _cameraActive;
  double get lastScore => _lastScore;
  double get confidence => _confidence;
  int get noPersonAlertSeconds => _noPersonAlertSeconds;
  int get consecutivePresentFrames => _consecutivePresentFrames;
  int get consecutiveAbsentFrames => _consecutiveAbsentFrames;

  int get dangerMinutes => _dangerMinutes;
  bool get intervalAlertsEnabled => _intervalAlertsEnabled;
  AlertRepeatMode get repeatMode => _repeatMode;
  List<int> get alertIntervals => List.unmodifiable(_alertIntervals);
  List<StandaloneAlert> get alerts => _alerts;

  /// Intervalos válidos ordenados y sin duplicados (>= 1 minuto).
  List<int> get sortedIntervals {
    final set = _alertIntervals.where((m) => m >= 1).toSet().toList()..sort();
    return set;
  }

  /// Segundos transcurridos sin detectar persona (desde la última detección o
  /// desde el inicio del monitoreo).
  int get absenceSeconds {
    final ref = _lastPersonSeen ?? _timerStartedAt;
    if (ref == null) return 0;
    return DateTime.now().difference(ref).inSeconds;
  }

  double get absenceMinutes => absenceSeconds / 60.0;

  /// Progreso del temporizador en [0, 1].
  double get timerProgress {
    if (_durationMinutes <= 0) return 0;
    final total = _durationMinutes * 60;
    return ((total - _remainingSeconds) / total).clamp(0.0, 1.0).toDouble();
  }

  String get cameraSourceLabel => switch (_cameraSource) {
        StandaloneCameraSource.phone => "Cámara del móvil",
        StandaloneCameraSource.ipCamera => "Cámara IP (hogar/seguridad)",
      };

  /// Número de alertas de intervalo ya emitidas en el ciclo actual.
  int get firedIntervalCount => _firedIntervals.length;

  void setCameraSource(StandaloneCameraSource source) {
    if (_cameraSource == source) return;
    _cameraSource = source;
    notifyListeners();
  }

  void setCameraUrl(String url) {
    _cameraUrl = url.trim();
    notifyListeners();
  }

  // --- Timer ---

  void setDurationMinutes(int minutes) {
    _durationMinutes = minutes.clamp(1, 240).toInt();
    notifyListeners();
  }

  void startTimer({int? minutes}) {
    if (minutes != null) setDurationMinutes(minutes);
    _remainingSeconds = _durationMinutes * 60;
    _timerRunning = true;
    _timerPaused = false;
    _personPresent = false;
    _consecutivePresentFrames = 0;
    _consecutiveAbsentFrames = 0;
    _lastPersonSeen = null;
    _timerStartedAt = DateTime.now();
    _lastAlertAt = null;
    _alerted = false;
    _firedIntervals.clear();
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _persistSession();
    notifyListeners();
  }

  void pauseTimer() {
    if (!_timerRunning || _timerPaused) return;
    _timerPaused = true;
    notifyListeners();
  }

  void resumeTimer() {
    if (!_timerRunning || !_timerPaused) return;
    _timerPaused = false;
    // Reinicia el conteo de ausencia: tras reanudar se vuelve a vigilar.
    _lastPersonSeen = null;
    _timerStartedAt = DateTime.now();
    _lastAlertAt = null;
    _alerted = false;
    _firedIntervals.clear();
    notifyListeners();
  }

  void stopTimer() {
    _timerTick?.cancel();
    _timerRunning = false;
    _timerPaused = false;
    _remainingSeconds = 0;
    _alerted = false;
    _lastAlertAt = null;
    _timerStartedAt = null;
    _consecutivePresentFrames = 0;
    _consecutiveAbsentFrames = 0;
    _firedIntervals.clear();
    _clearSession();
    notifyListeners();
  }

  void _onTick() {
    if (!_timerRunning || _timerPaused) {
      notifyListeners();
      return;
    }
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
    }
    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      notifyListeners();
      stopTimer();
      return;
    }
    notifyListeners();
  }

  // --- Detección ---

  void setCameraActive(bool active) {
    if (_cameraActive == active) return;
    _cameraActive = active;
    notifyListeners();
  }

  void setConfidence(double value) {
    _confidence = value.clamp(0.2, 0.9).toDouble();
    notifyListeners();
  }

  void setNoPersonAlertSeconds(int seconds) {
    _noPersonAlertSeconds = seconds.clamp(10, 120).toInt();
    notifyListeners();
  }

  void setDangerMinutes(int minutes) {
    _dangerMinutes = minutes.clamp(1, 60).toInt();
    notifyListeners();
  }

  void setIntervalAlertsEnabled(bool value) {
    _intervalAlertsEnabled = value;
    notifyListeners();
  }

  void setRepeatMode(AlertRepeatMode mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  void setAlertIntervals(List<int> minutes) {
    _alertIntervals = minutes.where((m) => m >= 1 && m <= 240).toSet().toList()
      ..sort();
    notifyListeners();
  }

  /// Confirma presencia/ausencia tras frames consecutivos para reducir
  /// falsos positivos durante parpadeos de ML Kit.
  void onPersonDetected(int count, {double score = 0}) {
    _lastScore = score;
    if (count > 0) {
      _consecutivePresentFrames++;
      _consecutiveAbsentFrames = 0;
    } else {
      _consecutiveAbsentFrames++;
      _consecutivePresentFrames = 0;
    }

    final confirmedPresent =
        _consecutivePresentFrames >= _presenceConfirmFrames;
    final confirmedAbsent =
        _consecutiveAbsentFrames >= _absenceConfirmFrames;

    if (confirmedPresent) {
      _lastPersonSeen = DateTime.now();
      _alerted = false;
      _lastAlertAt = null;
      _firedIntervals.clear();
    }

    final nextPresent = confirmedPresent
        ? true
        : confirmedAbsent
            ? false
            : _personPresent;
    if (_personPresent == nextPresent) return;

    _personPresent = nextPresent;
    notifyListeners();
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('standalone_session_running', true);
    await prefs.setInt('standalone_session_remaining_seconds', _remainingSeconds);
    await prefs.setInt('standalone_session_duration_minutes', _durationMinutes);
    await prefs.setInt(
      'standalone_session_started_at_ms',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('standalone_session_running') != true) return;

    final startedAt = prefs.getInt('standalone_session_started_at_ms');
    final savedRemaining = prefs.getInt('standalone_session_remaining_seconds');
    final savedDuration = prefs.getInt('standalone_session_duration_minutes');
    if (startedAt == null || savedRemaining == null || savedDuration == null) {
      await _clearSession();
      return;
    }

    final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
    final elapsedSeconds = elapsed ~/ 1000;
    final remaining = savedRemaining - elapsedSeconds;
    if (remaining <= 0) {
      await _clearSession();
      return;
    }

    _durationMinutes = savedDuration.clamp(1, 240).toInt();
    _remainingSeconds = remaining;
    _timerRunning = true;
    _timerPaused = false;
    _timerStartedAt = DateTime.now().subtract(Duration(seconds: elapsedSeconds));
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    notifyListeners();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('standalone_session_running');
    await prefs.remove('standalone_session_remaining_seconds');
    await prefs.remove('standalone_session_duration_minutes');
    await prefs.remove('standalone_session_started_at_ms');
  }

  /// Devuelve el intervalo (en minutos) que debe dispararse ahora, o `null` si
  /// no corresponde ninguna alerta.
  ///
  /// Reglas:
  /// - Solo con el temporizador activo y la cocina sin persona.
  /// - Se respeta un corto periodo de gracia ([_noPersonAlertSeconds]).
  /// - Se dispara cada intervalo configurado que ya se haya alcanzado y no se
  ///   haya disparado todavía en el ciclo de ausencia actual.
  int? nextDueInterval() {
    if (!_intervalAlertsEnabled) return null;
    if (!_timerRunning || _timerPaused) return null;
    if (_personPresent) return null;

    final intervals = sortedIntervals;
    if (intervals.isEmpty) return null;

    // Gracia inicial: evita falsos positivos por parpadeos de la detección.
    if (absenceSeconds < _noPersonAlertSeconds) return null;

    final minutes = absenceMinutes;
    for (final interval in intervals) {
      if (minutes + 1e-6 >= interval && !_firedIntervals.contains(interval)) {
        return interval;
      }
    }

    // Repetición del último intervalo cuando se configuró así.
    if (_repeatMode == AlertRepeatMode.repeatLast) {
      final last = intervals.last;
      if (minutes >= last &&
          _firedIntervals.length >= intervals.length) {
        final lastFired = _lastAlertAt;
        if (lastFired == null) return last;
        final since = DateTime.now().difference(lastFired).inSeconds;
        // Repite cada 'last' minutos tras la última alerta.
        if (since >= last * 60) return last;
      }
    }
    return null;
  }

  /// Registra que el intervalo [minutes] fue disparado.
  void markIntervalFired(int minutes, String message) {
    _firedIntervals.add(minutes);
    _alerted = true;
    _lastAlertAt = DateTime.now();
    _alerts.insert(0, StandaloneAlert(message, DateTime.now(), atMinute: minutes));
    if (_alerts.length > 100) _alerts.removeLast();
    notifyListeners();
  }

  /// Compatibilidad: usa el umbral corto como alerta genérica.
  bool shouldAlert() {
    if (!_timerRunning || _timerPaused) return false;
    if (_personPresent) return false;
    if (absenceSeconds < _noPersonAlertSeconds) return false;
    if (!_alerted) return true;
    final last = _lastAlertAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inSeconds >= _noPersonAlertSeconds;
  }

  String get statusText {
    if (!_timerRunning) return "Inicia el tiempo de monitoreo";
    if (_timerPaused) return "Monitoreo en PAUSA";
    if (!_cameraActive) return "Iniciando cámara...";
    if (_personPresent) return "Persona detectada - cocina atendida";
    final m = absenceMinutes;
    return "SIN PERSONA DETECTADA (${m.toStringAsFixed(1)} min)";
  }

  void triggerAlert(String message) {
    _alerted = true;
    _lastAlertAt = DateTime.now();
    _alerts.insert(0, StandaloneAlert(message, DateTime.now()));
    if (_alerts.length > 100) _alerts.removeLast();
    notifyListeners();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  String get remainingLabel {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }
}
