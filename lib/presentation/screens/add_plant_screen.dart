import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/plant.dart';
import '../../domain/repositories/greenbox_repository.dart';

class AddPlantScreen extends StatefulWidget {
  final GreenBoxRepository repository;
  final String? editDeviceId;
  final String? editDeviceName;
  final double? editMinHumidity;
  final double? editMaxHumidity;
  final String? editPlantTemplateId;

  const AddPlantScreen({
    super.key,
    required this.repository,
    this.editDeviceId,
    this.editDeviceName,
    this.editMinHumidity,
    this.editMaxHumidity,
    this.editPlantTemplateId,
  });

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  late final TextEditingController _deviceIdController;
  late final TextEditingController _deviceNameController;
  List<Plant> _templates = [];
  String? _selectedTemplateId;
  double _minHumidity = 60.0;
  double _maxHumidity = 80.0;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditMode => widget.editDeviceId != null;

  @override
  void initState() {
    super.initState();
    _deviceIdController = TextEditingController(text: widget.editDeviceId ?? '');
    _deviceNameController = TextEditingController(text: widget.editDeviceName ?? '');
    _selectedTemplateId = widget.editPlantTemplateId;
    _minHumidity = widget.editMinHumidity ?? 60.0;
    _maxHumidity = widget.editMaxHumidity ?? 80.0;
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await widget.repository.getPlantTemplates();
      setState(() {
        _templates = templates;
        _isLoading = false;
        if (!_isEditMode && templates.isNotEmpty && _selectedTemplateId == null) {
          _selectedTemplateId = templates.first.id;
          _minHumidity = templates.first.recommendedMinHumidity;
          _maxHumidity = templates.first.recommendedMaxHumidity;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar plantas: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_deviceIdController.text.isEmpty || _deviceNameController.text.isEmpty || _selectedTemplateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        await widget.repository.updateDevice(
          widget.editDeviceId!,
          name: _deviceNameController.text,
          plantTemplateId: _selectedTemplateId!,
          thresholds: {
            'humidity_min': _minHumidity,
            'humidity_max': _maxHumidity,
          },
        );
      } else {
        await widget.repository.addDevice(
          deviceId: _deviceIdController.text,
          name: _deviceNameController.text,
          plantTemplateId: _selectedTemplateId!,
          thresholds: {
            'humidity_min': _minHumidity,
            'humidity_max': _maxHumidity,
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Editar Planta' : 'Nueva Planta',
          style: AppTextStyles.greeting.copyWith(fontSize: 22),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Selecciona el tipo de cultivo', style: AppTextStyles.alertSubtitle),
                  const SizedBox(height: 15),
                  _buildPlantSelector(),
                  const SizedBox(height: 30),
                  Text('2. Identificador del Dispositivo', style: AppTextStyles.alertSubtitle),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _deviceIdController,
                    hintText: 'Ingresa el UUID del ESP32',
                    enabled: !_isEditMode,
                  ),
                  const SizedBox(height: 30),
                  Text('3. Nombre del Dispositivo', style: AppTextStyles.alertSubtitle),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _deviceNameController,
                    hintText: 'Ej. Mi Huerto 01',
                  ),
                  const SizedBox(height: 30),
                  Text('4. Configurar Humedad (%)', style: AppTextStyles.alertSubtitle),
                  const SizedBox(height: 10),
                  _buildHumiditySlider(),
                  const SizedBox(height: 50),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildPlantSelector() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final plant = _templates[index];
          final isSelected = plant.id == _selectedTemplateId;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedTemplateId = plant.id;
              _minHumidity = plant.recommendedMinHumidity;
              _maxHumidity = plant.recommendedMaxHumidity;
            }),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      plant.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 40, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plant.commonName,
                    style: AppTextStyles.chartLabel.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
        ),
        style: AppTextStyles.chartFilter.copyWith(
          color: enabled ? AppColors.textPrimary : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildHumiditySlider() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_minHumidity.round()}%', style: AppTextStyles.chartLabel),
              Text('Rango Óptimo', style: AppTextStyles.chartFilter),
              Text('${_maxHumidity.round()}%', style: AppTextStyles.chartLabel),
            ],
          ),
          RangeSlider(
            values: RangeValues(_minHumidity, _maxHumidity),
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: AppColors.humedadTeal,
            inactiveColor: AppColors.divider,
            onChanged: (values) {
              setState(() {
                _minHumidity = values.start;
                _maxHumidity = values.end;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'GUARDAR CONFIGURACIÓN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }
}
