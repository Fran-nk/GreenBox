import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/chart_data_point.dart';
import '../../domain/models/crop_card.dart';
import '../../domain/models/plant.dart';
import '../../domain/models/sensor_reading.dart';
import '../../domain/repositories/greenbox_repository.dart';
import '../widgets/greeting_header.dart';
import '../widgets/crop_carousel.dart';
import '../widgets/plant_detail_card.dart';
import '../widgets/sensor_filter_tabs.dart';
import '../widgets/sensor_chart.dart';
import '../widgets/app_bottom_nav.dart';
import 'add_plant_screen.dart';
import 'profile_screen.dart';
import 'water_footprint_screen.dart';
import '../../core/services/notification_service.dart';

/// Main Dashboard screen — assembles all widgets from the Figma design.
///
/// The repository is injected, so swapping from Mock → HTTP → MQTT
/// requires zero changes to this screen.
class DashboardScreen extends StatefulWidget {
  final GreenBoxRepository repository;

  const DashboardScreen({super.key, required this.repository});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── State ──
  List<CropCard> _crops = [];
  Plant? _activePlant;
  Map<String, double> _sensorValues = {};
  List<ChartDataPoint> _chartData = [];
  String _selectedSensorTab = 'PH';
  ChartTimeRange _chartRange = ChartTimeRange.monthly;
  String? _selectedCropId;
  int _bottomNavIndex = 0;
  bool _isLoading = true;
  bool _hasHumidityAlert = false;

  StreamSubscription<List<SensorReading>>? _sensorSubscription;

  /// Live hydrostatic pressure (kPa), listened to only by the water footprint tab.
  final ValueNotifier<double?> _pressure = ValueNotifier(null);

  String get _selectedCropName {
    for (final c in _crops) {
      if (c.id == _selectedCropId) return c.name;
    }
    return _activePlant?.commonName ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final crops = await widget.repository.getCrops();
      if (crops.isEmpty) {
        setState(() {
          _crops = [];
          _activePlant = null;
          _selectedCropId = null;
          _sensorValues = {};
          _chartData = [];
          _isLoading = false;
        });
        return;
      }

      String initialId = crops.first.id;
      if (_selectedCropId != null && crops.any((c) => c.id == _selectedCropId)) {
        initialId = _selectedCropId!;
      }
      await _selectPlant(initialId);

      setState(() {
        _crops = crops;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _selectPlant(String plantId) async {
    // Cancel previous subscription
    await _sensorSubscription?.cancel();

    // Independent requests run in parallel.
    final results = await Future.wait([
      widget.repository.getActivePlant(plantId),
      widget.repository.getSensorReadings(plantId),
      widget.repository.getChartData(
        plantId: plantId,
        sensorType: _selectedSensorTab.toLowerCase(),
        timeRange: _chartRange,
      ),
    ]);
    final plant = results[0] as Plant;
    final readings = results[1] as List<SensorReading>;
    final chartData = results[2] as List<ChartDataPoint>;

    _pressure.value = null;
    final sensorMap = _mergeReadings(const {}, readings, plant);

    setState(() {
      _activePlant = plant;
      _sensorValues = sensorMap;
      _chartData = chartData;
      _selectedCropId = plantId;
    });

    _checkAlerts();

    // Start real-time subscription
    _sensorSubscription = widget.repository.watchSensorReadings(plantId).listen((readings) {
      if (readings.isEmpty || _activePlant == null) return;
      final newSensorMap = _mergeReadings(_sensorValues, readings, _activePlant!);
      // Rebuild the dashboard only when a displayed value actually changed.
      if (mapEquals(newSensorMap, _sensorValues)) return;
      setState(() => _sensorValues = newSensorMap);
      _checkAlerts();
    });
  }

  /// Merges new readings into the displayed sensor values. The hydrostatic
  /// pressure goes to [_pressure] (only the water footprint tab listens to it)
  /// and is kept in the map only when its tile is active on the plant card.
  Map<String, double> _mergeReadings(Map<String, double> current, List<SensorReading> readings, Plant plant) {
    final map = Map<String, double>.from(current);
    for (final r in readings) {
      if (r.sensorType == 'presion') {
        _pressure.value = r.value;
        if (!plant.activeSensors.contains('presion')) continue;
      }
      map[r.sensorType] = r.value;
    }
    return map;
  }

  void _checkAlerts() {
    if (_activePlant == null) return;
    final humidity = _sensorValues['humedad'];
    if (humidity == null) return;

    bool isAlertNow = humidity < _activePlant!.recommendedMinHumidity || 
                      humidity > _activePlant!.recommendedMaxHumidity;

    if (isAlertNow && !_hasHumidityAlert) {
      final cropCard = _crops.firstWhere(
        (c) => c.id == _selectedCropId, 
        orElse: () => CropCard(id: '', name: _activePlant!.commonName, imageUrl: '', progress: 0)
      );
      NotificationService().showHumidityAlert(
        plantName: _activePlant!.commonName,
        deviceName: cropCard.name,
      );
    }

    if (isAlertNow != _hasHumidityAlert) {
      setState(() {
        _hasHumidityAlert = isAlertNow;
      });
    }
  }

  Future<void> _onSensorTabChanged(String type) async {
    setState(() => _selectedSensorTab = type);
    if (_activePlant == null) return;
    final chartData = await widget.repository.getChartData(
      plantId: _activePlant!.id,
      sensorType: type == 'CE' ? 'ce' : type == 'Hº' ? 'humedad' : type == 'Temp' ? 'temperatura' : type.toLowerCase(),
      timeRange: _chartRange,
    );
    setState(() => _chartData = chartData);
  }

  Future<void> _onChartRangeChanged(ChartTimeRange range) async {
    setState(() => _chartRange = range);
    if (_activePlant == null) return;
    final chartData = await widget.repository.getChartData(
      plantId: _activePlant!.id,
      sensorType: _selectedSensorTab == 'CE' ? 'ce' : _selectedSensorTab == 'Hº' ? 'humedad' : _selectedSensorTab == 'Temp' ? 'temperatura' : _selectedSensorTab.toLowerCase(),
      timeRange: range,
    );
    setState(() => _chartData = chartData);
  }

  Future<void> _onAddPlant() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPlantScreen(repository: widget.repository),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _onEditPlant(Plant plant) async {
    if (_selectedCropId == null) return;

    final activeCropCard = _crops.firstWhere(
      (c) => c.id == _selectedCropId,
      orElse: () => CropCard(id: '', name: plant.commonName, imageUrl: plant.imageUrl, progress: 0),
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPlantScreen(
          repository: widget.repository,
          editDeviceId: _selectedCropId,
          editDeviceName: activeCropCard.name,
          editMinHumidity: plant.recommendedMinHumidity,
          editMaxHumidity: plant.recommendedMaxHumidity,
          editPlantTemplateId: plant.id,
          editActiveSensors: plant.activeSensors,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _onDeletePlant(Plant plant) async {
    if (_selectedCropId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '¿Eliminar planta?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Esta acción eliminará el dispositivo y todo su historial de sensores de forma permanente. ¿Estás seguro?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await widget.repository.deleteDevice(_selectedCropId!);
        setState(() {
          _activePlant = null;
          _selectedCropId = null;
        });
        await _loadData();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : IndexedStack(
                index: _bottomNavIndex,
                children: [
                  _buildDashboardBody(),
                  _buildWaterFootprintTab(),
                  const ProfileScreen(),
                ],
              ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
      ),
    );
  }

  bool get _hasNoData => _crops.isEmpty || _activePlant == null || _sensorValues.isEmpty;

  /// Health status line shown under the greeting: (message, context, color).
  (String, String?, Color) get _status {
    if (_hasNoData) {
      return ('hay un problema con la obtencion de datos', null, AppColors.alertRed);
    }
    if (_hasHumidityAlert) {
      return ('Cuidado', 'con tu cultivo de ${_activePlant!.commonName} | $_selectedCropName', AppColors.alertRed);
    }
    return ('Tus plantas estás sanas y salvas💪', null, AppColors.statusGood);
  }

  GreetingHeader _buildHeader({bool showGreeting = true}) {
    final (message, contextText, color) = _status;
    return GreetingHeader(
      userName: 'Frank',
      alertMessage: message,
      alertContext: contextText,
      alertColor: color,
      notificationCount: _hasHumidityAlert ? 1 : 0,
      showGreeting: showGreeting,
    );
  }

  Widget _buildWaterFootprintTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(showGreeting: false),
        Expanded(
          child: WaterFootprintScreen(
            repository: widget.repository,
            deviceId: _selectedCropId,
            deviceName: _selectedCropName,
            plant: _activePlant,
            pressure: _pressure,
            hasSensorData: !_hasNoData,
            hasHumidityAlert: _hasHumidityAlert,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Greeting + alert
          _buildHeader(),

          // 2. Crop carousel
          CropCarousel(
            crops: _crops.map((c) => c.id == _selectedCropId ? c.copyWith(hasAlert: _hasHumidityAlert) : c).toList(),
            selectedCropId: _selectedCropId,
            onCropTap: (crop) {
              _selectPlant(crop.id);
            },
            onAddCrop: _onAddPlant,
          ),

          const SizedBox(height: 10),

          // 3. Plant detail card with sensors
          if (_activePlant != null)
            PlantDetailCard(
              plant: _activePlant!,
              deviceName: _selectedCropName,
              sensorValues: _sensorValues,
              hasHumidityAlert: _hasHumidityAlert,
              onEdit: () => _onEditPlant(_activePlant!),
              onDelete: () => _onDeletePlant(_activePlant!),
            ),

          const SizedBox(height: 10),

          // 4. Sensor filter tabs
          SensorFilterTabs(
            sensorTypes: const ['PH', 'CE', 'Hº', 'Luz', 'Temp'],
            activeType: _selectedSensorTab,
            onChanged: _onSensorTabChanged,
          ),

          // 5. Chart with time-range dropdown
          RepaintBoundary(
            child: SensorChart(
              dataPoints: _chartData,
              selectedRange: _chartRange,
              onRangeChanged: _onChartRangeChanged,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _pressure.dispose();
    widget.repository.dispose();
    super.dispose();
  }
}

