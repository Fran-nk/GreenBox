/// Represents a sensor reading from a GreenBox device.
///
/// This model is transport-agnostic — it works the same whether the data
/// comes from HTTPS polling or an MQTT subscription.
class SensorReading {
  final String sensorType;  // 'ph', 'ce', 'luz', 'humedad'
  final double value;
  final String unit;
  final DateTime timestamp;

  const SensorReading({
    required this.sensorType,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      sensorType: json['sensor_type'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'sensor_type': sensorType,
        'value': value,
        'unit': unit,
        'timestamp': timestamp.toIso8601String(),
      };
}
