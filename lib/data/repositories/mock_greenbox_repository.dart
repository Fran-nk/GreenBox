import 'dart:async';

import '../../domain/models/sensor_reading.dart';
import '../../domain/models/plant.dart';
import '../../domain/models/crop_card.dart';
import '../../domain/models/chart_data_point.dart';
import '../../domain/models/water_study.dart';
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
      SensorReading(sensorType: 'temperatura', value: 24.5, unit: '°C', timestamp: now),
      SensorReading(sensorType: 'presion', value: 1.47, unit: 'kPa', timestamp: now),
    ];
  }

  final List<CropCard> _mockCrops = [
    const CropCard(id: '1', name: 'Naranja 01', imageUrl: 'assets/images/naranja.png', progress: 0.37),
    const CropCard(id: '2', name: 'Espinaca 01', imageUrl: 'assets/images/espinaca.png', progress: 0.46),
    const CropCard(id: '3', name: 'Lechuga 01', imageUrl: 'assets/images/lechuga.png', progress: 0.42),
    const CropCard(id: '4', name: 'Fresa 01', imageUrl: 'assets/images/fresa.png', progress: 0.75, hasAlert: true),
  ];

  final Map<String, List<String>> _mockActiveSensors = {};

  @override
  Future<List<CropCard>> getCrops() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_mockCrops);
  }

  @override
  Future<Plant> getActivePlant(String plantId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final crop = _mockCrops.firstWhere(
      (c) => c.id == plantId,
      orElse: () => _mockCrops.first,
    );

    return Plant(
      id: crop.id,
      commonName: crop.name,
      scientificName: 'Spinacia oleracea',
      imageUrl: crop.imageUrl,
      currentDay: 10,
      totalDays: 30,
      isHealthy: true,
      growthProgress: crop.progress,
      activeSensors: _mockActiveSensors[plantId] ?? const ['ph', 'ce', 'humedad', 'luz', 'temperatura'],
      growthStages: const [
        GrowthStage(name: 'Vegetativa', days: 15, isCurrent: true),
        GrowthStage(name: 'Floración', days: 15),
        GrowthStage(name: 'Fructificación', days: 15),
      ],
    );
  }

  @override
  Future<List<ChartDataPoint>> getChartData({
    required String plantId,
    required String sensorType,
    required ChartTimeRange timeRange,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

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
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final readings = await getSensorReadings(plantId);
      _sensorController.add(readings);
    });

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
    List<String>? activeSensors,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockCrops.add(CropCard(
      id: deviceId,
      name: name,
      imageUrl: 'assets/images/lechuga.png',
      progress: 0.1,
    ));
    if (activeSensors != null) {
      _mockActiveSensors[deviceId] = activeSensors;
    }
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockCrops.removeWhere((c) => c.id == deviceId);
    _mockActiveSensors.remove(deviceId);
  }

  @override
  Future<void> updateDevice(String deviceId, {
    required String name,
    required String plantTemplateId,
    required Map<String, double> thresholds,
    List<String>? activeSensors,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockCrops.indexWhere((c) => c.id == deviceId);
    if (index != -1) {
      _mockCrops[index] = _mockCrops[index].copyWith(name: name);
    }
    if (activeSensors != null) {
      _mockActiveSensors[deviceId] = activeSensors;
    }
  }

  // ── Blue water footprint (in memory) ──

  final Map<String, TankDimensions> _mockTanks = {};
  final List<WaterStudy> _mockStudies = [];
  final List<WaterRefill> _mockRefills = [];

  @override
  Future<TankDimensions?> getTankDimensions(String deviceId) async => _mockTanks[deviceId];

  @override
  Future<void> saveTankDimensions(String deviceId, TankDimensions dimensions) async {
    _mockTanks[deviceId] = dimensions;
  }

  @override
  Future<WaterStudy?> getActiveStudy(String deviceId) async {
    for (final s in _mockStudies) {
      if (s.deviceId == deviceId && s.isActive) return s;
    }
    return null;
  }

  @override
  Future<WaterStudy> startStudy({
    required String deviceId,
    String? plantId,
    required double initialPressureKpa,
    required double initialVolumeL,
  }) async {
    final study = WaterStudy(
      id: 'study-${_mockStudies.length + 1}',
      deviceId: deviceId,
      plantId: plantId,
      status: 'active',
      startedAt: DateTime.now(),
      initialPressureKpa: initialPressureKpa,
      initialVolumeL: initialVolumeL,
    );
    _mockStudies.add(study);
    return study;
  }

  @override
  Future<WaterRefill> addRefill({
    required String studyId,
    required double volumeBeforeL,
    required double volumeAfterL,
  }) async {
    final refill = WaterRefill(
      id: 'refill-${_mockRefills.length + 1}',
      studyId: studyId,
      createdAt: DateTime.now(),
      volumeBeforeL: volumeBeforeL,
      volumeAfterL: volumeAfterL,
    );
    _mockRefills.add(refill);
    return refill;
  }

  @override
  Future<List<WaterRefill>> getRefills(String studyId) async {
    return _mockRefills.where((r) => r.studyId == studyId).toList();
  }

  @override
  Future<void> finishStudy({
    required String studyId,
    required double finalPressureKpa,
    required double finalVolumeL,
    required double totalConsumptionL,
    required int plantCount,
    required double harvestWeightKg,
    required double waterFootprintLPerKg,
  }) async {
    final index = _mockStudies.indexWhere((s) => s.id == studyId);
    if (index == -1) return;
    final s = _mockStudies[index];
    _mockStudies[index] = WaterStudy(
      id: s.id,
      deviceId: s.deviceId,
      plantId: s.plantId,
      status: 'finished',
      startedAt: s.startedAt,
      finishedAt: DateTime.now(),
      initialPressureKpa: s.initialPressureKpa,
      initialVolumeL: s.initialVolumeL,
      finalPressureKpa: finalPressureKpa,
      finalVolumeL: finalVolumeL,
      totalConsumptionL: totalConsumptionL,
      plantCount: plantCount,
      harvestWeightKg: harvestWeightKg,
      waterFootprintLPerKg: waterFootprintLPerKg,
    );
  }

  @override
  Future<List<WaterStudy>> getStudyHistory(String deviceId) async {
    return _mockStudies
        .where((s) => s.deviceId == deviceId && !s.isActive)
        .toList()
        .reversed
        .toList();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _sensorController.close();
  }
}
