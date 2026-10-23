import 'package:flutter/foundation.dart';
import '../content/content.dart';

/// Controla el tour guiado de la interfaz (coach marks).
class TourController extends ChangeNotifier {
  bool _active = false;
  int _step = 0;

  bool get active => _active;
  int get step => _step;
  int get totalSteps => AppTour.totalSteps;

  /// Pestaña válida que debe resaltarse en el paso actual.
  int? get highlightedTab => AppTour.tabIndexAt(_step);

  void start({int initialStep = 0}) {
    if (!_active || _step != initialStep) {
      _active = true;
      _step = initialStep.clamp(0, totalSteps - 1);
      notifyListeners();
    }
  }

  void next() {
    if (!_active) return;
    if (_step >= totalSteps - 1) {
      end();
    } else {
      _step++;
      notifyListeners();
    }
  }

  void prev() {
    if (!_active || _step <= 0) return;
    _step--;
    notifyListeners();
  }

  void skip() => end();

  void end() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }
}
