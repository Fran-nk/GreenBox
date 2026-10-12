import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/water_study.dart';
import '../../domain/services/water_footprint_calculator.dart';

/// Values entered in the harvest simulator, remembered between openings.
class HarvestSimulation {
  final double? initialLevelCm;
  final double? finalLevelCm;
  final double refilledL;
  final int plantCount;
  final double weightPerPlantKg;

  const HarvestSimulation({
    this.initialLevelCm,
    this.finalLevelCm,
    this.refilledL = 0,
    this.plantCount = 1,
    required this.weightPerPlantKg,
  });
}

/// Bottom sheet that emulates a whole study by hand: initial and final water
/// level, refilled litres, number of plants and weight per plant, showing the
/// blue water footprint live. It never saves anything; it only reports the
/// entered values through [onChanged] so they can prefill the next opening
/// and the finish dialog.
class HarvestSimulatorSheet extends StatefulWidget {
  final String cropName;
  final TankDimensions tank;
  final HarvestSimulation initial;
  final void Function(HarvestSimulation simulation) onChanged;

  const HarvestSimulatorSheet({
    super.key,
    required this.cropName,
    required this.tank,
    required this.initial,
    required this.onChanged,
  });

  static const double minWeightKg = 0.05;
  static const double maxWeightKg = 1.0;

  @override
  State<HarvestSimulatorSheet> createState() => _HarvestSimulatorSheetState();
}

class _HarvestSimulatorSheetState extends State<HarvestSimulatorSheet> {
  late final TextEditingController _initialController;
  late final TextEditingController _finalController;
  late final TextEditingController _refilledController;
  late final TextEditingController _weightController;
  late int _plantCount;
  late double _weightPerPlantKg;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _initialController = TextEditingController(text: _fmt(s.initialLevelCm));
    _finalController = TextEditingController(text: _fmt(s.finalLevelCm));
    _refilledController = TextEditingController(text: s.refilledL > 0 ? s.refilledL.toStringAsFixed(2) : '');
    _plantCount = s.plantCount;
    _weightPerPlantKg = s.weightPerPlantKg;
    _weightController = TextEditingController(text: (_weightPerPlantKg * 1000).round().toString());
  }

  HarvestSimulation get _current => HarvestSimulation(
        initialLevelCm: _parse(_initialController.text),
        finalLevelCm: _parse(_finalController.text),
        refilledL: _parse(_refilledController.text) ?? 0,
        plantCount: _plantCount,
        weightPerPlantKg: _weightPerPlantKg,
      );

  void _changed() {
    setState(() {});
    widget.onChanged(_current);
  }

  void _setWeight(double kg, {bool updateField = true}) {
    _weightPerPlantKg = kg;
    if (updateField) _weightController.text = (kg * 1000).round().toString();
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final sim = _current;
    final tank = widget.tank;
    final initialL = sim.initialLevelCm != null
        ? WaterFootprintCalculator.heightToVolumeL(tank, sim.initialLevelCm!)
        : null;
    final finalL = sim.finalLevelCm != null
        ? WaterFootprintCalculator.heightToVolumeL(tank, sim.finalLevelCm!)
        : null;
    final consumption = initialL != null && finalL != null
        ? WaterFootprintCalculator.consumptionFromLevelsL(
            initialVolumeL: initialL,
            finalVolumeL: finalL,
            refilledL: sim.refilledL,
          )
        : null;
    final totalKg = _plantCount * _weightPerPlantKg;
    final wf = consumption != null
        ? WaterFootprintCalculator.waterFootprintLPerKg(consumption, totalKg)
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 30 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Simulador de huella hídrica', style: AppTextStyles.greeting.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              '${widget.cropName} · Solo simulación: no guarda ni finaliza el estudio.',
              style: AppTextStyles.chartLabel,
            ),
            const SizedBox(height: 20),

            // ── Agua ──
            Text('Agua', style: AppTextStyles.chartFilter.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_initialController, 'Nivel inicial', 'cm')),
                const SizedBox(width: 8),
                Expanded(child: _field(_finalController, 'Nivel final', 'cm')),
              ],
            ),
            const SizedBox(height: 8),
            _field(_refilledController, 'Agua recargada (total)', 'L'),
            const SizedBox(height: 8),
            _row('Volumen inicial → final',
                '${initialL?.toStringAsFixed(2) ?? '—'} → ${finalL?.toStringAsFixed(2) ?? '—'} L'),
            _row('Agua consumida', consumption != null ? '${consumption.toStringAsFixed(2)} L' : '—'),
            const SizedBox(height: 16),

            // ── Cosecha ──
            Text('Cosecha', style: AppTextStyles.chartFilter.copyWith(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nº de plantas', style: AppTextStyles.chartFilter),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _plantCount > 1
                          ? () {
                              _plantCount--;
                              _changed();
                            }
                          : null,
                    ),
                    Text('$_plantCount', style: AppTextStyles.chartFilter.copyWith(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        _plantCount++;
                        _changed();
                      },
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _weightPerPlantKg.clamp(HarvestSimulatorSheet.minWeightKg, HarvestSimulatorSheet.maxWeightKg),
                    min: HarvestSimulatorSheet.minWeightKg,
                    max: HarvestSimulatorSheet.maxWeightKg,
                    divisions: 95,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.divider,
                    onChanged: (v) => _setWeight(v),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: _field(_weightController, 'Peso/planta', 'g', onChanged: (text) {
                    final g = _parse(text);
                    if (g != null && g > 0) _setWeight(g / 1000, updateField: false);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Resultado ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.darkOverlay,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text('Peso total: ${totalKg.toStringAsFixed(2)} kg', style: AppTextStyles.timeInfo),
                  const SizedBox(height: 8),
                  Text(wf == null ? '—' : wf.toStringAsFixed(1), style: AppTextStyles.sensorValue),
                  Text('L/kg · huella hídrica azul', style: AppTextStyles.sensorUnit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String suffix,
      {ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged ?? (_) => _changed(),
      style: AppTextStyles.chartFilter,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.chartLabel),
          Text(value, style: AppTextStyles.chartFilter.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _initialController.dispose();
    _finalController.dispose();
    _refilledController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}

double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

String _fmt(double? value) => value == null ? '' : value.toStringAsFixed(1);
