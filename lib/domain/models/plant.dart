/// Represents a plant/crop being monitored by a GreenBox device.
class Plant {
  final String id;
  final String commonName;      // e.g. "Lechuga"
  final String scientificName;  // e.g. "Spinacia oleracea"
  final String imageUrl;
  final int currentDay;
  final int totalDays;
  final List<GrowthStage> growthStages;
  final bool isHealthy;
  final double growthProgress;  // 0.0 to 1.0
  final double recommendedMinHumidity;
  final double recommendedMaxHumidity;
  final List<String> activeSensors;
  final double typicalHarvestWeightKg; // reference weight per plant, used by the harvest simulator

  const Plant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.imageUrl,
    required this.currentDay,
    required this.totalDays,
    required this.growthStages,
    this.isHealthy = true,
    this.growthProgress = 0.0,
    this.recommendedMinHumidity = 60.0,
    this.recommendedMaxHumidity = 80.0,
    this.activeSensors = const ['ph', 'ce', 'humedad', 'luz', 'temperatura'],
    this.typicalHarvestWeightKg = 0.25,
  });

  /// Reference harvest weight per plant (kg) by common name.
  static double defaultHarvestWeightFor(String commonName) {
    final name = commonName.toLowerCase();
    if (name.contains('lechuga')) return 0.30;
    if (name.contains('espinaca')) return 0.15;
    return 0.25;
  }

  /// Recommended default crop templates for spinach and lettuce.
  static List<Plant> getDefaultTemplates() {
    return const [
      Plant(
        id: '11111111-1111-4111-a111-111111111111',
        commonName: 'Espinaca',
        scientificName: 'Spinacia oleracea',
        imageUrl: 'assets/images/espinaca.png',
        currentDay: 0,
        totalDays: 40,
        recommendedMinHumidity: 60.0,
        recommendedMaxHumidity: 75.0,
        typicalHarvestWeightKg: 0.15,
        growthStages: [
          GrowthStage(name: 'Germinación', days: 7, isCurrent: true),
          GrowthStage(name: 'Vegetativa', days: 20),
          GrowthStage(name: 'Madurez', days: 13),
        ],
      ),
      Plant(
        id: '22222222-2222-4222-a222-222222222222',
        commonName: 'Lechuga',
        scientificName: 'Lactuca sativa',
        imageUrl: 'assets/images/lechuga.png',
        currentDay: 0,
        totalDays: 30,
        recommendedMinHumidity: 55.0,
        recommendedMaxHumidity: 70.0,
        typicalHarvestWeightKg: 0.30,
        growthStages: [
          GrowthStage(name: 'Germinación', days: 5, isCurrent: true),
          GrowthStage(name: 'Vegetativa', days: 15),
          GrowthStage(name: 'Madurez', days: 10),
        ],
      ),
    ];
  }
}

/// A phase in the plant's growth cycle.
class GrowthStage {
  final String name;   // e.g. "Vegetativa", "Floración", "Fructificación"
  final int days;
  final bool isCurrent;

  const GrowthStage({
    required this.name,
    required this.days,
    this.isCurrent = false,
  });
}
