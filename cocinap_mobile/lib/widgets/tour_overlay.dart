import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../content/content.dart';
import '../providers/tour_controller.dart';

/// Capa de "coach marks" que oscurece la app y resalta la pestaña actual,
/// mostrando una tarjeta con la explicación de cada sección.
class TourOverlay extends StatefulWidget {
  final TourController tour;
  final GlobalKey navKey;
  final int destinationCount;
  final String lang;

  const TourOverlay({
    super.key,
    required this.tour,
    required this.navKey,
    required this.destinationCount,
    required this.lang,
  });

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  Rect? _hole;
  Rect? _navRect;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant TourOverlay old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _compute();
    });
  }

  void _compute() {
    final tab = widget.tour.highlightedTab;
    final ctx = widget.navKey.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      if (_hole != null || _navRect != null) {
        setState(() {
          _hole = null;
          _navRect = null;
        });
      }
      return;
    }
    final topLeft = ro.localToGlobal(Offset.zero);
    final navRect = topLeft & ro.size;
    Rect? hole;
    if (tab != null) {
      final itemW = ro.size.width / widget.destinationCount;
      hole = Rect.fromLTWH(
        navRect.left + itemW * tab + 6,
        navRect.top + 6,
        itemW - 12,
        ro.size.height - 12,
      );
    }
    if (hole != _hole || navRect != _navRect) {
      setState(() {
        _hole = hole;
        _navRect = navRect;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = AppTour.steps(widget.lang);
    final step = steps[widget.tour.step];
    final media = MediaQuery.of(context);
    final accent = scheme.primary;

    Widget card = _TourCard(
      step: step,
      index: widget.tour.step,
      total: widget.tour.totalSteps,
      accent: accent,
      lang: widget.lang,
      onSkip: widget.tour.skip,
      onPrev: widget.tour.step > 0 ? widget.tour.prev : null,
      onNext: widget.tour.next,
    );

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                child: CustomPaint(
                  painter: _HolePainter(
                    hole: _hole,
                    dim: Colors.black.withValues(alpha: 0.74),
                    accent: accent,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (step.tabIndex == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: card,
                ),
              )
            else
              Positioned(
                left: 16,
                right: 16,
                bottom: math.max(
                  16,
                  media.size.height -
                      (_navRect?.top ?? media.size.height) +
                      12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(180, media.size.height * 0.42),
                  ),
                  child: SingleChildScrollView(child: card),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect? hole;
  final Color dim;
  final Color accent;
  _HolePainter({required this.hole, required this.dim, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, Paint()..color = dim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(hole!.inflate(6), const Radius.circular(18));
    final cut = Path()..addRRect(rrect);
    final diff = Path.combine(PathOperation.difference, full, cut);
    canvas.drawPath(diff, Paint()..color = dim);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _HolePainter old) =>
      old.hole != hole || old.accent != accent;
}

class _TourCard extends StatelessWidget {
  final TourStep step;
  final int index;
  final int total;
  final Color accent;
  final String lang;
  final VoidCallback onSkip;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _TourCard({
    required this.step,
    required this.index,
    required this.total,
    required this.accent,
    required this.lang,
    required this.onSkip,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF221A16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${index + 1}/$total",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onSkip,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    lang == "en" ? "Skip" : "Saltar",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onPrev != null)
                TextButton.icon(
                  onPressed: onPrev,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(lang == "en" ? "Back" : "Atrás"),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onNext,
                icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 18),
                label: Text(
                  isLast
                      ? (lang == "en" ? "Finish" : "Listo")
                      : (lang == "en" ? "Next" : "Siguiente"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
