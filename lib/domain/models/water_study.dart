/// Dimensions of the rectangular water tank (cm).
class TankDimensions {
  final double widthCm;
  final double lengthCm;
  final double heightCm;

  const TankDimensions({
    required this.widthCm,
    required this.lengthCm,
    required this.heightCm,
  });

  /// Maximum capacity of the tank in litres.
  double get maxVolumeL => widthCm * lengthCm * heightCm / 1000;

  bool get isValid => widthCm > 0 && lengthCm > 0 && heightCm > 0;
}

/// A blue water footprint study for one device (one crop cycle).
class WaterStudy {
  final String id;
  final String deviceId;
  final String? plantId;
  final String status; // 'active' | 'finished'
  final DateTime startedAt;
  final DateTime? finishedAt;
  final double initialPressureKpa;
  final double initialVolumeL;
  final double? finalPressureKpa;
  final double? finalVolumeL;
  final double? totalConsumptionL;
  final int? plantCount;
  final double? harvestWeightKg;
  final double? waterFootprintLPerKg;

  const WaterStudy({
    required this.id,
    required this.deviceId,
    this.plantId,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    required this.initialPressureKpa,
    required this.initialVolumeL,
    this.finalPressureKpa,
    this.finalVolumeL,
    this.totalConsumptionL,
    this.plantCount,
    this.harvestWeightKg,
    this.waterFootprintLPerKg,
  });

  bool get isActive => status == 'active';

  factory WaterStudy.fromJson(Map<String, dynamic> json) {
    double? d(String key) => json[key] == null ? null : (json[key] as num).toDouble();
    return WaterStudy(
      id: json['id'].toString(),
      deviceId: json['device_id'].toString(),
      plantId: json['plant_id']?.toString(),
      status: json['status'] ?? 'active',
      startedAt: DateTime.parse(json['started_at']),
      finishedAt: json['finished_at'] != null ? DateTime.parse(json['finished_at']) : null,
      initialPressureKpa: d('initial_pressure_kpa') ?? 0,
      initialVolumeL: d('initial_volume_l') ?? 0,
      finalPressureKpa: d('final_pressure_kpa'),
      finalVolumeL: d('final_volume_l'),
      totalConsumptionL: d('total_consumption_l'),
      plantCount: json['plant_count'] as int?,
      harvestWeightKg: d('harvest_weight_kg'),
      waterFootprintLPerKg: d('water_footprint_l_per_kg'),
    );
  }
}

/// A refill of the tank during an active study.
class WaterRefill {
  final String id;
  final String studyId;
  final DateTime createdAt;
  final double volumeBeforeL;
  final double volumeAfterL;

  const WaterRefill({
    required this.id,
    required this.studyId,
    required this.createdAt,
    required this.volumeBeforeL,
    required this.volumeAfterL,
  });

  double get addedL => volumeAfterL - volumeBeforeL;

  factory WaterRefill.fromJson(Map<String, dynamic> json) {
    return WaterRefill(
      id: json['id'].toString(),
      studyId: json['study_id'].toString(),
      createdAt: DateTime.parse(json['created_at']),
      volumeBeforeL: (json['volume_before_l'] as num).toDouble(),
      volumeAfterL: (json['volume_after_l'] as num).toDouble(),
    );
  }
}
