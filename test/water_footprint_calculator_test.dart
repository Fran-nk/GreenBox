import 'package:flutter_test/flutter_test.dart';
import 'package:greenbox/domain/models/water_study.dart';
import 'package:greenbox/domain/services/water_footprint_calculator.dart';

void main() {
  const tank = TankDimensions(widthCm: 40, lengthCm: 30, heightCm: 25);

  WaterRefill refill(int minute, double before, double after) => WaterRefill(
        id: 'r$minute',
        studyId: 's',
        createdAt: DateTime(2026, 1, 1, 0, minute),
        volumeBeforeL: before,
        volumeAfterL: after,
      );

  test('1 kPa equals ~10.19 cm of water', () {
    expect(WaterFootprintCalculator.pressureToHeightCm(1), closeTo(10.194, 0.001));
  });

  test('tank max volume and volume from pressure', () {
    expect(tank.maxVolumeL, 30);
    // 1.47 kPa → ~14.98 cm → 40·30·14.98 / 1000 ≈ 17.98 L
    expect(WaterFootprintCalculator.pressureToVolumeL(tank, 1.47), closeTo(17.98, 0.01));
  });

  test('level percent relative to the first reading', () {
    expect(WaterFootprintCalculator.levelPercent(15, 20), 75);
    expect(WaterFootprintCalculator.levelPercent(15, 0), 0);
  });

  test('consumption without refills', () {
    expect(
      WaterFootprintCalculator.totalConsumptionL(initialVolumeL: 20, refills: [], currentVolumeL: 12),
      8,
    );
  });

  test('consumption with two refills sums every drop', () {
    // 20→14 (6) | refill 14→20 | 20→15 (5) | refill 15→19 | 19→16 (3) = 14 L
    final total = WaterFootprintCalculator.totalConsumptionL(
      initialVolumeL: 20,
      refills: [refill(2, 15, 19), refill(1, 14, 20)],
      currentVolumeL: 16,
    );
    expect(total, 14);
  });

  test('manual levels: height ↔ pressure and volume ↔ height round-trip', () {
    expect(WaterFootprintCalculator.pressureToHeightCm(
        WaterFootprintCalculator.heightToPressureKpa(15)), closeTo(15, 1e-9));
    expect(WaterFootprintCalculator.volumeToHeightCm(tank, 18), closeTo(15, 1e-9));
  });

  test('consumption from manual levels matches the refill-based sum', () {
    // Same scenario as above: 20 L → 16 L with 6 + 4 L refilled = 14 L
    expect(
      WaterFootprintCalculator.consumptionFromLevelsL(initialVolumeL: 20, finalVolumeL: 16, refilledL: 10),
      14,
    );
    expect(WaterFootprintCalculator.consumptionFromLevelsL(initialVolumeL: 10, finalVolumeL: 12), 0);
  });

  test('blue water footprint in L/kg', () {
    expect(WaterFootprintCalculator.waterFootprintLPerKg(20, 0.6), closeTo(33.33, 0.01));
    expect(WaterFootprintCalculator.waterFootprintLPerKg(20, 0), isNull);
  });
}
