import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/plant.dart';
import '../../domain/models/water_study.dart';
import '../../domain/repositories/greenbox_repository.dart';
import '../../domain/services/water_footprint_calculator.dart';
import '../widgets/harvest_simulator_sheet.dart';
import '../widgets/tank_3d_preview.dart';

/// Blue water footprint (WFN methodology) for the selected device.
///
/// Flow: configure tank → first reading (100 %) → register refills →
/// emulate (any time) → harvest (3 s confirmation).
///
/// The live pressure arrives through [pressure] so only the widgets that
/// depend on it rebuild on every sensor tick.
class WaterFootprintScreen extends StatefulWidget {
  final GreenBoxRepository repository;
  final String? deviceId;
  final String? deviceName;
  final Plant? plant;
  final ValueListenable<double?> pressure;
  final bool hasSensorData;
  final bool hasHumidityAlert;

  const WaterFootprintScreen({
    super.key,
    required this.repository,
    required this.deviceId,
    this.deviceName,
    this.plant,
    required this.pressure,
    this.hasSensorData = false,
    this.hasHumidityAlert = false,
  });

  @override
  State<WaterFootprintScreen> createState() => _WaterFootprintScreenState();
}

class _WaterFootprintScreenState extends State<WaterFootprintScreen> {
  static final TextStyle _title = AppTextStyles.sensorValue.copyWith(
    color: AppColors.textPrimary,
    fontSize: 26,
  );
  static final TextStyle _cardSmall = AppTextStyles.alertSubtitle.copyWith(
    color: AppColors.textOnDark,
    fontSize: 13,
  );
  static final TextStyle _cardTiny = AppTextStyles.alertSubtitle.copyWith(
    color: AppColors.textOnDark,
    fontSize: 10,
  );
  static final TextStyle _cardBig = AppTextStyles.greeting.copyWith(
    color: AppColors.textOnDark,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  TankDimensions? _tank;
  WaterStudy? _study;
  List<WaterRefill> _refills = [];
  List<WaterStudy> _history = [];
  bool _isLoading = true;
  bool _isBusy = false;

  // Last simulated values, reused to prefill the simulator and the finish dialog.
  HarvestSimulation? _sim;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WaterFootprintScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId) {
      _sim = null;
      _load();
    }
  }

  Future<void> _load() async {
    final deviceId = widget.deviceId;
    if (deviceId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Independent queries run in parallel.
      final results = await Future.wait([
        widget.repository.getTankDimensions(deviceId),
        widget.repository.getActiveStudy(deviceId),
        widget.repository.getStudyHistory(deviceId),
      ]);
      final study = results[1] as WaterStudy?;
      final refills = study != null ? await widget.repository.getRefills(study.id) : <WaterRefill>[];
      if (!mounted || deviceId != widget.deviceId) return;
      setState(() {
        _tank = results[0] as TankDimensions?;
        _study = study;
        _refills = refills;
        _history = results[2] as List<WaterStudy>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Error al cargar el estudio: $e');
    }
  }

  // ── Derived values ──

  double? _heightFor(double? pressureKpa) =>
      pressureKpa == null ? null : WaterFootprintCalculator.pressureToHeightCm(pressureKpa);

  double? _consumptionFor(double? pressureKpa) {
    if (_tank == null || _study == null || pressureKpa == null) return null;
    return WaterFootprintCalculator.totalConsumptionL(
      initialVolumeL: _study!.initialVolumeL,
      refills: _refills,
      currentVolumeL: WaterFootprintCalculator.pressureToVolumeL(_tank!, pressureKpa),
    );
  }

  double get _typicalWeightKg =>
      widget.plant?.typicalHarvestWeightKg ??
      Plant.defaultHarvestWeightFor(widget.plant?.commonName ?? '');

  // ── Actions ──

  Future<void> _editTank() async {
    final dims = await showModalBottomSheet<TankDimensions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TankSheet(initial: _tank, pressure: widget.pressure),
    );
    if (dims == null) return;
    await _run(() async {
      await widget.repository.saveTankDimensions(widget.deviceId!, dims);
      setState(() => _tank = dims);
    });
  }

  /// Makes sure the tank is configured; opens the tank sheet otherwise.
  Future<bool> _ensureTank() async {
    if (_tank == null) await _editTank();
    return _tank != null;
  }

  Future<void> _startStudy() async {
    if (!await _ensureTank() || !mounted) return;
    // First reading: taken from the sensor when available, otherwise typed by hand.
    final levelCm = await showDialog<double>(
      context: context,
      builder: (_) => _LevelDialog(
        title: 'Primera lectura (100 %)',
        description: 'Nivel de agua inicial del recipiente. Se toma del sensor si hay lectura; puedes escribirlo a mano.',
        pressure: widget.pressure,
        tank: _tank!,
      ),
    );
    if (levelCm == null) return;
    await _run(() async {
      final study = await widget.repository.startStudy(
        deviceId: widget.deviceId!,
        plantId: widget.plant?.id,
        initialPressureKpa: WaterFootprintCalculator.heightToPressureKpa(levelCm),
        initialVolumeL: WaterFootprintCalculator.heightToVolumeL(_tank!, levelCm),
      );
      setState(() {
        _study = study;
        _refills = [];
      });
    });
  }

  Future<void> _registerRefill() async {
    final result = await showDialog<(double, double)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RefillDialog(pressure: widget.pressure, tank: _tank!),
    );
    if (result == null) return;
    await _run(() async {
      final refill = await widget.repository.addRefill(
        studyId: _study!.id,
        volumeBeforeL: result.$1,
        volumeAfterL: result.$2,
      );
      setState(() => _refills = [..._refills, refill]);
    });
  }

  Future<void> _openSimulator() async {
    if (!await _ensureTank() || !mounted) return;
    final sensorCm = _heightFor(widget.pressure.value);
    // Prefill with the last simulation, else with the study / sensor data.
    final initial = _sim ??
        HarvestSimulation(
          initialLevelCm: _study != null
              ? WaterFootprintCalculator.volumeToHeightCm(_tank!, _study!.initialVolumeL)
              : sensorCm,
          finalLevelCm: sensorCm,
          refilledL: _refills.fold<double>(0, (sum, r) => sum + r.addedL),
          weightPerPlantKg: _typicalWeightKg,
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HarvestSimulatorSheet(
        cropName: widget.plant?.commonName ?? 'Cultivo',
        tank: _tank!,
        initial: initial,
        onChanged: (simulation) => _sim = simulation,
      ),
    );
  }

  Future<void> _finishHarvest() async {
    final plantCount = _sim?.plantCount ?? 1;
    final result = await showDialog<_FinishResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FinishHarvestDialog(
        tank: _tank!,
        study: _study!,
        refills: _refills,
        pressure: widget.pressure,
        initialFinalLevelCm: _heightFor(widget.pressure.value) ?? _sim?.finalLevelCm,
        initialPlantCount: plantCount,
        initialWeightKg: plantCount * (_sim?.weightPerPlantKg ?? _typicalWeightKg),
      ),
    );
    if (result == null) return;

    final finalVolume = WaterFootprintCalculator.heightToVolumeL(_tank!, result.finalLevelCm);
    final consumption = WaterFootprintCalculator.totalConsumptionL(
      initialVolumeL: _study!.initialVolumeL,
      refills: _refills,
      currentVolumeL: finalVolume,
    );
    final wf = WaterFootprintCalculator.waterFootprintLPerKg(consumption, result.weightKg)!;
    await _run(() async {
      await widget.repository.finishStudy(
        studyId: _study!.id,
        finalPressureKpa: WaterFootprintCalculator.heightToPressureKpa(result.finalLevelCm),
        finalVolumeL: finalVolume,
        totalConsumptionL: consumption,
        plantCount: result.plantCount,
        harvestWeightKg: result.weightKg,
        waterFootprintLPerKg: wf,
      );
      _sim = null;
      await _load();
      _showMessage('Cosecha finalizada: ${wf.toStringAsFixed(1)} L/kg');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisTabs(),
          const SizedBox(height: 18),
          Text('HUELLA HIDRICA', style: _title),
          Text('metodología Water Footprint Network (WFN)', style: AppTextStyles.alertSubtitle),
          const SizedBox(height: 20),
          if (widget.deviceId == null)
            Text('Agrega un dispositivo para iniciar un estudio', style: AppTextStyles.chartFilter)
          else if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else ...[
            _buildStudyCard(),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildHistory(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisTabs() {
    return Row(
      children: [
        Container(
          width: 74,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.phBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.water_drop_outlined, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Proximamente',
            style: AppTextStyles.alertSubtitle.copyWith(color: AppColors.textOnDark, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }

  Widget _buildStudyCard() {
    final plant = widget.plant;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.darkOverlay,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garden name + crop thumbnail
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nombre del huerto', style: _cardSmall),
                    Text(
                      (widget.deviceName?.isNotEmpty == true ? widget.deviceName! : plant?.commonName ?? '')
                          .toUpperCase(),
                      style: _cardSmall.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (plant != null)
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    plant.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, s) => const Icon(Icons.eco, color: AppColors.statusGood, size: 22),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          // Only this part depends on the live pressure.
          ValueListenableBuilder<double?>(
            valueListenable: widget.pressure,
            builder: (context, pressureKpa, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTankBox(pressureKpa),
                const SizedBox(width: 22),
                Expanded(child: _buildStudyInfo(pressureKpa)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTankBox(double? pressureKpa) {
    final tank = _tank;
    return GestureDetector(
      onTap: _isBusy ? null : _editTank,
      child: Container(
        width: 124,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Tank3DPreview(
                  widthCm: tank?.widthCm ?? 0,
                  lengthCm: tank?.lengthCm ?? 0,
                  heightCm: tank?.heightCm ?? 0,
                  waterHeightCm: _heightFor(pressureKpa),
                  showLabels: false,
                  padding: 18,
                  height: null,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Text(
                tank != null
                    ? '${_fmt(tank.widthCm)}×${_fmt(tank.lengthCm)}×${_fmt(tank.heightCm)} cm'
                    : 'Toca para configurar',
                textAlign: TextAlign.center,
                style: AppTextStyles.chartLabel.copyWith(fontSize: 10),
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyInfo(double? pressureKpa) {
    final tank = _tank;
    final consumption = _consumptionFor(pressureKpa);
    final hasStudy = _study != null;

    final comfort = !widget.hasSensorData
        ? 'SIN DATOS'
        : widget.hasHumidityAlert
            ? 'REVISAR'
            : 'BUENO';
    // Live sensor readings give a reliable footprint; manual levels are an estimate.
    final reliability = !hasStudy
        ? 'SIN ESTUDIO'
        : pressureKpa != null
            ? 'BUENO'
            : 'MANUAL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AGUA CONSUMIDA : Total ${tank != null ? '${tank.maxVolumeL.toStringAsFixed(1)}L' : '—'}',
          style: _cardSmall,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(consumption != null ? consumption.toStringAsFixed(1) : '—', style: _cardBig),
              ),
            ),
            const SizedBox(width: 6),
            Text('litros', style: _cardSmall.copyWith(fontSize: 15)),
          ],
        ),
        const SizedBox(height: 14),
        Text('Confort del invernadero:  $comfort', style: _cardTiny),
        const SizedBox(height: 6),
        Text('Fiabilidad de la H.Hídrica:  $reliability', style: _cardSmall),
        if (hasStudy) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _isBusy ? null : _registerRefill,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Recargas: ${_refills.length}   ', style: _cardTiny),
                TextSpan(
                  text: '+ Registrar',
                  style: _cardTiny.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _pillButton('Emular', _openSimulator),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _pillButton(hasStudy ? 'Cosechar' : 'Iniciar', hasStudy ? _finishHarvest : _startStudy),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pillButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: _isBusy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.statusGood,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.statusGood.withValues(alpha: 0.5),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: const StadiumBorder(),
        ),
        child: FittedBox(
          child: Text(label, style: AppTextStyles.alertSubtitle.copyWith(color: Colors.white, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HISTORIAL', style: _title.copyWith(fontSize: 18)),
        const SizedBox(height: 8),
        for (final s in _history)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_fmtDate(s.startedAt)} → ${s.finishedAt != null ? _fmtDate(s.finishedAt!) : ''}',
                        style: AppTextStyles.chartLabel,
                      ),
                      Text(
                        '${s.totalConsumptionL?.toStringAsFixed(2) ?? '—'} L · '
                        '${s.harvestWeightKg?.toStringAsFixed(2) ?? '—'} kg · '
                        '${s.plantCount ?? '—'} plantas',
                        style: AppTextStyles.chartFilter,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${s.waterFootprintLPerKg?.toStringAsFixed(1) ?? '—'} L/kg',
                  style: AppTextStyles.chartFilter.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet to edit the tank dimensions, with a live labelled 3D preview.
class _TankSheet extends StatefulWidget {
  final TankDimensions? initial;
  final ValueListenable<double?> pressure;

  const _TankSheet({this.initial, required this.pressure});

  @override
  State<_TankSheet> createState() => _TankSheetState();
}

class _TankSheetState extends State<_TankSheet> {
  late final TextEditingController _width;
  late final TextEditingController _length;
  late final TextEditingController _height;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _width = TextEditingController(text: t != null ? _fmt(t.widthCm) : '');
    _length = TextEditingController(text: t != null ? _fmt(t.lengthCm) : '');
    _height = TextEditingController(text: t != null ? _fmt(t.heightCm) : '');
  }

  TankDimensions get _dims => TankDimensions(
        widthCm: _parse(_width.text) ?? 0,
        lengthCm: _parse(_length.text) ?? 0,
        heightCm: _parse(_height.text) ?? 0,
      );

  @override
  Widget build(BuildContext context) {
    final dims = _dims;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recipiente', style: AppTextStyles.greeting.copyWith(fontSize: 22)),
            const SizedBox(height: 10),
            RepaintBoundary(
              child: ValueListenableBuilder<double?>(
                valueListenable: widget.pressure,
                builder: (context, p, _) => Tank3DPreview(
                  widthCm: dims.widthCm,
                  lengthCm: dims.lengthCm,
                  heightCm: dims.heightCm,
                  waterHeightCm: p != null ? WaterFootprintCalculator.pressureToHeightCm(p) : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field(_width, 'Ancho')),
                const SizedBox(width: 8),
                Expanded(child: _field(_length, 'Largo')),
                const SizedBox(width: 8),
                Expanded(child: _field(_height, 'Altura')),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Volumen máximo: ${dims.isValid ? dims.maxVolumeL.toStringAsFixed(2) : '—'} L',
              style: AppTextStyles.chartFilter,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: dims.isValid ? () => Navigator.pop(context, dims) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusGood,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      style: AppTextStyles.chartFilter,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'cm',
        filled: true,
        fillColor: AppColors.background,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _width.dispose();
    _length.dispose();
    _height.dispose();
    super.dispose();
  }
}

// ── Helpers ──

double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

String _fmt(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _fmtDate(DateTime date) {
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Two-step refill: capture the level before refilling, then after.
/// Captured litres stay editable in case the sensor reading is off.
class _RefillDialog extends StatefulWidget {
  final ValueListenable<double?> pressure;
  final TankDimensions tank;

  const _RefillDialog({required this.pressure, required this.tank});

  @override
  State<_RefillDialog> createState() => _RefillDialogState();
}

class _RefillDialogState extends State<_RefillDialog> {
  final _beforeController = TextEditingController();
  final _afterController = TextEditingController();
  bool _beforeCaptured = false;

  void _capture(TextEditingController controller) {
    final p = widget.pressure.value;
    if (p == null) return;
    final volume = WaterFootprintCalculator.pressureToVolumeL(widget.tank, p);
    controller.text = volume.toStringAsFixed(2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final before = _parse(_beforeController.text);
    final after = _parse(_afterController.text);
    final canSave = before != null && after != null && after > before;

    return AlertDialog(
      title: const Text('Registrar recarga'),
      content: ValueListenableBuilder<double?>(
        valueListenable: widget.pressure,
        builder: (context, p, _) {
          final liveVolume = p != null ? WaterFootprintCalculator.pressureToVolumeL(widget.tank, p) : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Volumen actual: ${liveVolume != null ? '${liveVolume.toStringAsFixed(2)} L' : 'sin lectura'}',
                style: AppTextStyles.chartLabel,
              ),
              const SizedBox(height: 12),
              Text('1. Antes de rellenar', style: AppTextStyles.chartFilter),
              Row(
                children: [
                  Expanded(child: _litresField(_beforeController)),
                  TextButton(
                    onPressed: p == null
                        ? null
                        : () {
                            _capture(_beforeController);
                            setState(() => _beforeCaptured = true);
                          },
                    child: const Text('CAPTURAR'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('2. Después de rellenar', style: AppTextStyles.chartFilter),
              Row(
                children: [
                  Expanded(child: _litresField(_afterController)),
                  TextButton(
                    onPressed: p == null || !_beforeCaptured ? null : () => _capture(_afterController),
                    child: const Text('CAPTURAR'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: canSave ? () => Navigator.pop(context, (before, after)) : null,
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }

  Widget _litresField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(suffixText: 'L', isDense: true),
    );
  }

  @override
  void dispose() {
    _beforeController.dispose();
    _afterController.dispose();
    super.dispose();
  }
}

/// Water level input (cm): prefilled from the sensor when there is a reading,
/// always editable so the study also works without the sensor.
class _LevelField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueListenable<double?> pressure;
  final VoidCallback onChanged;

  const _LevelField({
    required this.controller,
    required this.label,
    required this.pressure,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(labelText: label, suffixText: 'cm', isDense: true),
          ),
        ),
        ValueListenableBuilder<double?>(
          valueListenable: pressure,
          builder: (context, p, _) => TextButton(
            onPressed: p == null
                ? null
                : () {
                    controller.text = WaterFootprintCalculator.pressureToHeightCm(p).toStringAsFixed(1);
                    onChanged();
                  },
            child: const Text('SENSOR'),
          ),
        ),
      ],
    );
  }
}

/// Asks for a water level in cm and returns it.
class _LevelDialog extends StatefulWidget {
  final String title;
  final String description;
  final ValueListenable<double?> pressure;
  final TankDimensions tank;

  const _LevelDialog({
    required this.title,
    required this.description,
    required this.pressure,
    required this.tank,
  });

  @override
  State<_LevelDialog> createState() => _LevelDialogState();
}

class _LevelDialogState extends State<_LevelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final p = widget.pressure.value;
    _controller = TextEditingController(
      text: p != null ? WaterFootprintCalculator.pressureToHeightCm(p).toStringAsFixed(1) : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = _parse(_controller.text);
    final valid = level != null && level > 0;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description, style: AppTextStyles.chartLabel),
          const SizedBox(height: 12),
          _LevelField(
            controller: _controller,
            label: 'Nivel de agua',
            pressure: widget.pressure,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Volumen: ${valid ? '${WaterFootprintCalculator.heightToVolumeL(widget.tank, level).toStringAsFixed(2)} L' : '—'}',
            style: AppTextStyles.chartFilter,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: valid ? () => Navigator.pop(context, level) : null,
          child: const Text('INICIAR'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _FinishResult {
  final double finalLevelCm;
  final int plantCount;
  final double weightKg;

  const _FinishResult(this.finalLevelCm, this.plantCount, this.weightKg);
}

/// Finish-harvest confirmation. All values are editable (final water level,
/// plants, weight). The confirm button unlocks after a 3 second countdown
/// to avoid closing a study by accident.
class _FinishHarvestDialog extends StatefulWidget {
  final TankDimensions tank;
  final WaterStudy study;
  final List<WaterRefill> refills;
  final ValueListenable<double?> pressure;
  final double? initialFinalLevelCm;
  final int initialPlantCount;
  final double initialWeightKg;

  const _FinishHarvestDialog({
    required this.tank,
    required this.study,
    required this.refills,
    required this.pressure,
    this.initialFinalLevelCm,
    required this.initialPlantCount,
    required this.initialWeightKg,
  });

  @override
  State<_FinishHarvestDialog> createState() => _FinishHarvestDialogState();
}

class _FinishHarvestDialogState extends State<_FinishHarvestDialog> {
  late final TextEditingController _levelController;
  late final TextEditingController _plantsController;
  late final TextEditingController _weightController;
  Timer? _timer;
  int _secondsLeft = 3;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController(
      text: widget.initialFinalLevelCm?.toStringAsFixed(1) ?? '',
    );
    _plantsController = TextEditingController(text: widget.initialPlantCount.toString());
    _weightController = TextEditingController(text: widget.initialWeightKg.toStringAsFixed(2));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = _parse(_levelController.text);
    final plants = int.tryParse(_plantsController.text.trim());
    final weight = _parse(_weightController.text);
    final valid = level != null && level >= 0 &&
        plants != null && plants > 0 &&
        weight != null && weight > 0;

    final consumption = level != null
        ? WaterFootprintCalculator.totalConsumptionL(
            initialVolumeL: widget.study.initialVolumeL,
            refills: widget.refills,
            currentVolumeL: WaterFootprintCalculator.heightToVolumeL(widget.tank, level),
          )
        : null;
    final wf = valid && consumption != null
        ? WaterFootprintCalculator.waterFootprintLPerKg(consumption, weight)
        : null;

    return AlertDialog(
      title: const Text('¿Finalizar cosecha?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esto cierra el estudio y guarda el resultado. No se puede deshacer.',
              style: AppTextStyles.chartLabel,
            ),
            const SizedBox(height: 12),
            _LevelField(
              controller: _levelController,
              label: 'Nivel final de agua',
              pressure: widget.pressure,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Agua consumida: ${consumption != null ? '${consumption.toStringAsFixed(2)} L' : '—'}',
              style: AppTextStyles.chartFilter,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _plantsController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nº de plantas', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Peso real cosechado', suffixText: 'kg', isDense: true),
            ),
            const SizedBox(height: 12),
            Text(
              'Huella hídrica azul: ${wf != null ? '${wf.toStringAsFixed(1)} L/kg' : '—'}',
              style: AppTextStyles.chartFilter.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: _secondsLeft > 0 || !valid
              ? null
              : () => Navigator.pop(context, _FinishResult(level, plants, weight)),
          child: Text(
            _secondsLeft > 0 ? 'CONFIRMAR ($_secondsLeft)' : 'CONFIRMAR',
            style: TextStyle(
              color: _secondsLeft > 0 || !valid ? null : AppColors.alertRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levelController.dispose();
    _plantsController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}

