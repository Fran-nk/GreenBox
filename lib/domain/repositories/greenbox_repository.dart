import '../models/sensor_reading.dart';
import '../models/plant.dart';
import '../models/crop_card.dart';
import '../models/chart_data_point.dart';
import '../models/water_study.dart';

/// Abstract data repository for GreenBox sensor data.
///
/// ┌──────────────────────────────────────────────────────────────┐
/// │  This is the CORE ABSTRACTION for transport-agnostic data.  │
/// │  The UI depends ONLY on this interface.                     │
/// │                                                              │
/// │  Implementations:                                           │
/// │  • HttpGreenBoxRepository  — current (polling via REST)     │
/// │  • MqttGreenBoxRepository  — future  (real-time via MQTT)   │
/// └──────────────────────────────────────────────────────────────┘
abstract class GreenBoxRepository {
  /// Get the current sensor readings for a specific plant/device.
  Future<List<SensorReading>> getSensorReadings(String plantId);

  /// Get the active plant details (the selected one on the dashboard).
  Future<Plant> getActivePlant(String plantId);

  /// Get all crops for the crop carousel at the top.
  Future<List<CropCard>> getCrops();

  /// Get historical chart data for a given sensor type and time range.
  Future<List<ChartDataPoint>> getChartData({
    required String plantId,
    required String sensorType,
    required ChartTimeRange timeRange,
  });

  /// Stream of sensor readings for real-time updates.
  /// With HTTPS this can be implemented as polling,
  /// with MQTT as a native subscription.
  Stream<List<SensorReading>> watchSensorReadings(String plantId);

  /// Get the catalog of available plants to choose from when adding a new device.
  Future<List<Plant>> getPlantTemplates();

  /// Register a new physical device and link it to a plant type.
  Future<void> addDevice({
    required String deviceId,
    required String name,
    required String plantTemplateId,
    required Map<String, double> thresholds,
    List<String>? activeSensors,
  });

  /// Delete a physical device and all associated data.
  Future<void> deleteDevice(String deviceId);

  /// Update the name, plant template, and thresholds of a physical device.
  Future<void> updateDevice(String deviceId, {
    required String name,
    required String plantTemplateId,
    required Map<String, double> thresholds,
    List<String>? activeSensors,
  });

  // ── Blue water footprint ──

  /// Get the tank dimensions configured for a device (null if not set).
  Future<TankDimensions?> getTankDimensions(String deviceId);

  /// Save the tank dimensions for a device.
  Future<void> saveTankDimensions(String deviceId, TankDimensions dimensions);

  /// Get the active (not finished) water footprint study of a device.
  Future<WaterStudy?> getActiveStudy(String deviceId);

  /// Start a study; the first reading is the 100 % water level.
  Future<WaterStudy> startStudy({
    required String deviceId,
    String? plantId,
    required double initialPressureKpa,
    required double initialVolumeL,
  });

  /// Register a tank refill (volume right before and right after refilling).
  Future<WaterRefill> addRefill({
    required String studyId,
    required double volumeBeforeL,
    required double volumeAfterL,
  });

  /// Get all refills of a study.
  Future<List<WaterRefill>> getRefills(String studyId);

  /// Finish the harvest and store the blue water footprint result.
  Future<void> finishStudy({
    required String studyId,
    required double finalPressureKpa,
    required double finalVolumeL,
    required double totalConsumptionL,
    required int plantCount,
    required double harvestWeightKg,
    required double waterFootprintLPerKg,
  });

  /// Get the finished studies of a device (most recent first).
  Future<List<WaterStudy>> getStudyHistory(String deviceId);

  /// Clean up resources (close connections, cancel subscriptions).
  void dispose();
}

/// Supported time ranges for chart filtering.
enum ChartTimeRange {
  daily,
  weekly,
  monthly,
}
