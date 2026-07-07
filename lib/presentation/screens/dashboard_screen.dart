import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Enforce hiding bottom system navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
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

      final initialId = crops.first.id;
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

    final plant = await widget.repository.getActivePlant(plantId);
    final readings = await widget.repository.getSensorReadings(plantId);
    final chartData = await widget.repository.getChartData(
      plantId: plantId,
      sensorType: _selectedSensorTab.toLowerCase(),
      timeRange: _chartRange,
    );

    final sensorMap = <String, double>{};
    for (final r in readings) {
      sensorMap[r.sensorType] = r.value;
    }

    setState(() {
      _activePlant = plant;
      _sensorValues = sensorMap;
      _chartData = chartData;
      _selectedCropId = plantId;
    });

    _checkAlerts();

    // Start real-time subscription
    _sensorSubscription = widget.repository.watchSensorReadings(plantId).listen((readings) {
      if (readings.isNotEmpty) {
        final newSensorMap = Map<String, double>.from(_sensorValues);
        for (final r in readings) {
          newSensorMap[r.sensorType] = r.value;
        }
        setState(() {
          _sensorValues = newSensorMap;
        });
        _checkAlerts();
      }
    });
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
      sensorType: type == 'CE' ? 'ce' : type == 'Hº' ? 'humedad' : type.toLowerCase(),
      timeRange: _chartRange,
    );
    setState(() => _chartData = chartData);
  }

  Future<void> _onChartRangeChanged(ChartTimeRange range) async {
    setState(() => _chartRange = range);
    if (_activePlant == null) return;
    final chartData = await widget.repository.getChartData(
      plantId: _activePlant!.id,
      sensorType: _selectedSensorTab == 'CE' ? 'ce' : _selectedSensorTab == 'Hº' ? 'humedad' : _selectedSensorTab.toLowerCase(),
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
                  const Center(child: Text('Sección de Dispositivos (Próximamente)')),
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

  Widget _buildDashboardBody() {
    final bool hasNoData = _crops.isEmpty || _activePlant == null || _sensorValues.isEmpty;
    
    String? statusMessage;
    String? statusContext;
    Color? statusColor;
    
    if (hasNoData) {
      statusMessage = 'hay un problema con la obtencion de datos';
      statusColor = AppColors.alertRed;
    } else if (_hasHumidityAlert) {
      statusMessage = 'Cuidado';
      statusContext = 'con tu cultivo de ${_activePlant!.commonName} | ${_crops.firstWhere((c) => c.id == _selectedCropId, orElse: () => CropCard(id: '', name: '', imageUrl: '', progress: 0)).name}';
      statusColor = AppColors.alertRed;
    } else {
      statusMessage = 'Tus plantas estás sanas y salvas💪';
      statusColor = AppColors.statusGood;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Greeting + alert
          GreetingHeader(
            userName: 'Frank',
            alertMessage: statusMessage,
            alertContext: statusContext,
            alertColor: statusColor,
            notificationCount: _hasHumidityAlert ? 1 : 0,
          ),

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
              sensorValues: _sensorValues,
              hasHumidityAlert: _hasHumidityAlert,
              onEdit: () => _onEditPlant(_activePlant!),
              onDelete: () => _onDeletePlant(_activePlant!),
            ),

          const SizedBox(height: 10),

          // 4. Sensor filter tabs
          SensorFilterTabs(
            sensorTypes: const ['PH', 'CE', 'Hº', 'Luz'],
            activeType: _selectedSensorTab,
            onChanged: _onSensorTabChanged,
          ),

          // 5. Chart with time-range dropdown
          SensorChart(
            dataPoints: _chartData,
            selectedRange: _chartRange,
            onRangeChanged: _onChartRangeChanged,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensorSubscription?.cancel();
    widget.repository.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Re-enforce hiding bottom system navigation bar when keyboard/system overlays change
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
  }
}

