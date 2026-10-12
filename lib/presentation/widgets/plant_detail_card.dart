import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/plant.dart';

/// Large dark card showing the selected plant details.
///
/// Includes: image, scientific name, common name, growth timeline,
/// growth stages, and sensor metric tiles.
class PlantDetailCard extends StatelessWidget {
  final Plant plant;
  final String? deviceName;
  final Map<String, double> sensorValues; // {'ph': 6.5, 'ce': 1500, ...}
  final bool hasHumidityAlert;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlantDetailCard({
    super.key,
    required this.plant,
    this.deviceName,
    required this.sensorValues,
    this.hasHumidityAlert = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
      decoration: BoxDecoration(
        color: AppColors.darkOverlay,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildPlantInfo(),
          const SizedBox(height: 10),
          _buildGrowthTimeline(),
          const SizedBox(height: 10),
          _buildSensorTiles(),
        ],
      ),
    );
  }

  Widget _buildPlantInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Plant image with status badge
          SizedBox(
            width: 115,
            height: 127,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    plant.imageUrl,
                    width: 115,
                    height: 127,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Container(
                      width: 115,
                      height: 127,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27C174),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.eco, color: Colors.white, size: 50),
                    ),
                  ),
                ),
                if (plant.isHealthy)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Name and settings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          deviceName ?? plant.scientificName,
                          style: AppTextStyles.plantScientific,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.settings,
                        color: AppColors.textOnDark,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: AppColors.textPrimary, size: 18),
                              SizedBox(width: 8),
                              Text('Editar', style: TextStyle(color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    plant.commonName.toUpperCase(),
                    style: AppTextStyles.plantCommon,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          // Time indicator: "10dias de 30dias"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${plant.currentDay}dias',
                      style: AppTextStyles.timeInfoBold,
                    ),
                    TextSpan(
                      text: ' de ${plant.totalDays}dias',
                      style: AppTextStyles.timeInfo,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: plant.growthProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  // Stage dividers
                  ..._buildStageDividers(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Stage labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: plant.growthStages.map((stage) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      stage.isCurrent ? stage.name : stage.name,
                      style: stage.isCurrent
                          ? AppTextStyles.timeInfoBold
                          : AppTextStyles.timeInfo,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${stage.days}d',
                      style: AppTextStyles.timeInfo,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStageDividers() {
    if (plant.growthStages.length <= 1) return [];
    final totalDays = plant.growthStages.fold<int>(0, (sum, s) => sum + s.days);
    final dividers = <Widget>[];
    int accumulated = 0;
    for (int i = 0; i < plant.growthStages.length - 1; i++) {
      accumulated += plant.growthStages[i].days;
      final fraction = accumulated / totalDays;
      dividers.add(
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 1.5, color: AppColors.textPrimary),
            ),
          ),
        ),
      );
    }
    return dividers;
  }

  Widget _buildSensorTiles() {
    final allSensors = {
      'ph': _SensorTileData('PH', sensorValues['ph'], '', AppColors.phBlue),
      'ce': _SensorTileData('CE', sensorValues['ce'], 'µS/CM', AppColors.ceYellow),
      'luz': _SensorTileData('Luz', sensorValues['luz'], 'DLI', AppColors.luzGreen),
      'humedad': _SensorTileData(
        'Hº', 
        sensorValues['humedad'], 
        '%', 
        AppColors.humedadTeal,
        textColor: hasHumidityAlert ? AppColors.alertRed : null,
      ),
      'temperatura': _SensorTileData('Temp', sensorValues['temperatura'], '°C', const Color(0xFFE58043)),
      'presion': _SensorTileData('Pres', sensorValues['presion'], 'kPa', const Color(0xFF3B6FD8)),
    };

    final activeTiles = plant.activeSensors
        .where((key) => allSensors.containsKey(key))
        .map((key) => allSensors[key]!)
        .toList();

    if (activeTiles.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 8.0;
        final int columns = 3;
        final double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.start,
            children: activeTiles.map((s) {
              return SizedBox(
                width: itemWidth,
                height: 120, // slightly shorter for grid
                child: _buildSensorTile(s),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSensorTile(_SensorTileData data) {
    return Container(
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.label, 
            style: AppTextStyles.sensorLabel.copyWith(color: data.textColor),
          ),
          const SizedBox(height: 6),
          if (data.value == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Icon(Icons.hourglass_empty, color: data.textColor ?? AppColors.textOnDark, size: 24),
            )
          else ...[
            Text(
              data.value! == data.value!.roundToDouble()
                  ? data.value!.toInt().toString()
                  : data.value!.toStringAsFixed(1),
              style: AppTextStyles.sensorValue.copyWith(color: data.textColor),
            ),
            if (data.unit.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                data.unit,
                style: AppTextStyles.sensorUnit.copyWith(color: data.textColor),
              ),
            ],
          ]
        ],
      ),
    );
  }
}

class _SensorTileData {
  final String label;
  final double? value;
  final String unit;
  final Color color;
  final Color? textColor;

  const _SensorTileData(this.label, this.value, this.unit, this.color, {this.textColor});
}
