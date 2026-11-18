/// A detected object with normalized image coordinates in the range [0, 1].
class DetectedBox {
  final double top;
  final double left;
  final double bottom;
  final double right;
  final double score;
  final int classId;
  final String label;

  const DetectedBox({
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
    required this.score,
    required this.classId,
    required this.label,
  });
}

/// Result of a person-detection inference.
class DetectionResult {
  final int count;
  final double maxScore;
  final List<DetectedBox> boxes;

  const DetectionResult(this.count, this.maxScore, [this.boxes = const []]);

  static const DetectionResult empty = DetectionResult(0, 0);
}
