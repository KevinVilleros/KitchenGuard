import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Anillo de progreso animado, dibujado con Flutter nativo (sin dependencias).
class RingProgress extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color trackColor;
  final Widget? center;

  const RingProgress({
    super.key,
    required this.value,
    required this.color,
    this.size = 132,
    this.stroke = 12,
    this.trackColor = const Color(0x22FFFFFF),
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, anim, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(anim, stroke, color, trackColor),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;
  final Color track;
  _RingPainter(this.value, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (math.min(size.width, size.height) - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(c, r, trackPaint);

    final rect = Rect.fromCircle(center: c, radius: r);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final prog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = 2 * math.pi * value;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, prog);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

/// Tarjeta con degradado suave y borde, base visual de la app.
class GradientCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    this.accent = Colors.orange,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: borderRadius,
      border: Border.all(color: accent.withValues(alpha: 0.25)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.16),
          const Color(0xFF1E1714),
        ],
      ),
    );
    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Encabezado de sección con icono y acento.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;
  const SectionTitle({
    super.key,
    required this.icon,
    required this.text,
    this.accent = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de estadística compacta: icono, valor grande y etiqueta.
class IconStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const IconStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1714),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de objetivo: icono circular + título + descripción.
class GoalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const GoalTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea de tiempo vertical para explicar pasos (con conector gráfico).
class StepTimeline extends StatelessWidget {
  final List<StepItem> items;
  final Color accent;

  const StepTimeline({super.key, required this.items, this.accent = Colors.orange});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: Icon(items[i].icon, size: 18, color: accent),
                  ),
                  if (i != items.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: accent.withValues(alpha: 0.3),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].body,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class StepItem {
  final IconData icon;
  final String title;
  final String body;
  const StepItem(this.icon, this.title, this.body);
}

/// Fila de verificación (checklist) con estado hecho/pendiente.
class ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final Color accent;

  const ChecklistRow({
    super.key,
    required this.icon,
    required this.label,
    required this.done,
    this.accent = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? Colors.green : Colors.white38;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: color, size: 20),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: accent.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: done ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
