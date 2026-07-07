/// Represents a single data point for chart visualisation.
class ChartDataPoint {
  final DateTime timestamp;
  final double value;
  final bool isInRange;

  const ChartDataPoint({
    required this.timestamp,
    required this.value,
    required this.isInRange,
  });
}
