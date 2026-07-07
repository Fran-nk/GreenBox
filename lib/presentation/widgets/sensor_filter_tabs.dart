import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Row of filter tabs: PH ✓, CE ✓, Hº ✓, Luz ✓
/// Active tab is dark with white text, inactive is outlined.
class SensorFilterTabs extends StatelessWidget {
  final List<String> sensorTypes;
  final String activeType;
  final ValueChanged<String> onChanged;

  const SensorFilterTabs({
    super.key,
    required this.sensorTypes,
    required this.activeType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: sensorTypes.map((type) {
          final isActive = type == activeType;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: isActive
                      ? null
                      : Border.all(color: AppColors.textPrimary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      type,
                      style: isActive
                          ? AppTextStyles.tabActive
                          : AppTextStyles.tabInactive,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
