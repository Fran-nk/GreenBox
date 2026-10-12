import '../models/water_study.dart';

/// Pure functions for the blue water footprint study.
///
/// Hydrostatic pressure → water height:  h = P / (ρ·g)
/// Water height → volume (rectangular tank):  V = width · length · h
/// Blue water footprint:  WF = consumed litres / harvested kg  (L/kg = m³/t)
class WaterFootprintCalculator {
  WaterFootprintCalculator._();

  static const double waterDensity = 1000.0; // kg/m³
  static const double gravity = 9.81; // m/s²

  /// Water column height (cm) for a pressure reading in kPa.
  static double pressureToHeightCm(double pressureKpa) {
    final heightM = (pressureKpa * 1000) / (waterDensity * gravity);
    return heightM * 100;
  }

  /// Inverse of [pressureToHeightCm]: pressure (kPa) of a water column in cm.
  static double heightToPressureKpa(double heightCm) {
    return (heightCm / 100) * waterDensity * gravity / 1000;
  }

  /// Water height (cm) for a volume (L) in the tank.
  static double volumeToHeightCm(TankDimensions tank, double volumeL) {
    final base = tank.widthCm * tank.lengthCm;
    return base <= 0 ? 0 : volumeL * 1000 / base;
  }

  /// Consumption (L) from manual levels: V_initial − V_final + refilled litres.
  /// Equivalent to [totalConsumptionL] when refills are summed.
  static double consumptionFromLevelsL({
    required double initialVolumeL,
    required double finalVolumeL,
    double refilledL = 0,
  }) {
    final total = initialVolumeL - finalVolumeL + refilledL;
    return total < 0 ? 0 : total;
  }

  /// Water volume (L) for a given height (cm) in the tank.
  static double heightToVolumeL(TankDimensions tank, double heightCm) {
    return tank.widthCm * tank.lengthCm * heightCm / 1000;
  }

  /// Water volume (L) for a pressure reading in kPa.
  static double pressureToVolumeL(TankDimensions tank, double pressureKpa) {
    return heightToVolumeL(tank, pressureToHeightCm(pressureKpa));
  }

  /// Current level as a percentage of the initial (100 %) volume.
  static double levelPercent(double currentVolumeL, double initialVolumeL) {
    if (initialVolumeL <= 0) return 0;
    return currentVolumeL / initialVolumeL * 100;
  }

  /// Total consumed water (L): sum of the drops between refills.
  ///
  /// (V_initial − V_before₁) + (V_after₁ − V_before₂) + … + (V_afterₙ − V_current)
  static double totalConsumptionL({
    required double initialVolumeL,
    required List<WaterRefill> refills,
    required double currentVolumeL,
  }) {
    final sorted = [...refills]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    double total = 0;
    double segmentStart = initialVolumeL;
    for (final r in sorted) {
      total += segmentStart - r.volumeBeforeL;
      segmentStart = r.volumeAfterL;
    }
    total += segmentStart - currentVolumeL;
    return total < 0 ? 0 : total;
  }

  /// Blue water footprint in L/kg. Returns null when the weight is not valid.
  static double? waterFootprintLPerKg(double consumptionL, double harvestWeightKg) {
    if (harvestWeightKg <= 0) return null;
    return consumptionL / harvestWeightKg;
  }
}
