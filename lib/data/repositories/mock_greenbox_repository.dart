import 'dart:async';

import '../../domain/models/sensor_reading.dart';
import '../../domain/models/plant.dart';
import '../../domain/models/crop_card.dart';
import '../../domain/models/chart_data_point.dart';
import '../../domain/repositories/greenbox_repository.dart';

/// Mock implementation of [GreenBoxRepository] for development.
///
/// Returns hardcoded data matching the Figma design.
/// Replace this with [HttpGreenBoxRepository] or [MqttGreenBoxRepository]
/// when the backend is ready.
class MockGreenBoxRepository implements GreenBoxRepository {
  Timer? _pollingTimer;
  final _sensorController = StreamController<List<SensorReading>>.broadcast();

  @override
  Future<List<SensorReading>> getSensorReadings(String plantId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    return [
      SensorReading(sensorType: 'ph', value: 6.5, unit: '', timestamp: now),
      SensorReading(sensorType: 'ce', value: 1500, unit: 'µS/cm', timestamp: now),
      SensorReading(sensorType: 'luz', value: 6.5, unit: 'DLI', timestamp: now),
      SensorReading(sensorType: 'humedad', value: 90, unit: '%', timestamp: now),
    ];
  }

  @override
  Future<Plant> getActivePlant(String plantId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    return const Plant(
      id: 'lechuga-01',
      commonName: 'Lechuga',
      scientificName: 'Spinacia oleracea',
      imageUrl: 'assets/images/lechuga.png',
      currentDay: 10,
      totalDays: 30,
      isHealthy: true,
      growthProgress: 0.33,
      growthStages: [
        GrowthStage(name: 'Vegetativa', days: 15, isCurrent: true),
        GrowthStage(name: 'Floración', days: 15),
        GrowthStage(name: 'Fructificación', days: 15),
      ],
    );
  }

  @override
  Future<List<CropCard>> getCrops() async {
    await Future.delayed(const Duration(milliseconds: 200));

    return const [
      CropCard(id: '1', name: 'Naranja', imageUrl: 'assets/images/naranja.png', progress: 0.37),
      CropCard(id: '2', name: 'Espinaca', imageUrl: 'assets/images/espinaca.png', progress: 0.46),
      CropCard(id: '3', name: 'Lechuga', imageUrl: 'assets/images/lechuga.png', progress: 0.42),
      CropCard(id: '4', name: 'Fresa', imageUrl: 'assets/images/fresa.png', progress: 0.75, hasAlert: true),
    ];
  }

  @override
  Future<List<ChartDataPoint>> getChartData({
    required String plantId,
    required String sensorType,
    required ChartTimeRange timeRange,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Generate mock data matching the bar chart in the Figma design
    final now = DateTime.now();
    final List<double> values = [
      4.5, 5.2, 7.0, 7.0, 7.0, 7.0, 7.0, 7.0, 5.0, 5.0,
      6.5, 6.5, 6.5, 6.5, 8.5, 7.0, 7.0, 7.0, 6.8, 6.8,
      5.5, 6.8, 6.8, 4.8, 4.8, 4.8, 4.8, 4.8, 5.5, 5.5,
    ];

    return List.generate(values.length, (i) {
      final value = values[i];
      return ChartDataPoint(
        timestamp: now.subtract(Duration(days: values.length - i)),
        value: value,
        isInRange: value >= 5.5 && value <= 7.5,
      );
    });
  }

  @override
  Stream<List<SensorReading>> watchSensorReadings(String plantId) {
    // Simulate polling (every 5 seconds, like HTTPS would do)
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final readings = await getSensorReadings(plantId);
      _sensorController.add(readings);
    });

    // Emit initial data
    getSensorReadings(plantId).then(_sensorController.add);

    return _sensorController.stream;
  }

  @override
  Future<List<Plant>> getPlantTemplates() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Plant.getDefaultTemplates();
  }

  @override
  Future<void> addDevice({
    required String deviceId,
    required String name,
    required String plantTemplateId,
    required Map<String, double> thresholds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // No-op for simulated device adding
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // No-op for simulated device deleting
  }

  @override
  Future<void> updateDevice(String deviceId, {
    required String name,
    required String plantTemplateId,
    required Map<String, double> thresholds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // No-op for simulated device updating
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _sensorController.close();
  }
}
