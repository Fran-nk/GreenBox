import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/crop_card.dart';

/// Horizontal scrollable list of crop cards (Figma top row).
///
/// Each card shows a crop image, a progress bar, and an optional alert icon.
class CropCarousel extends StatelessWidget {
  final List<CropCard> crops;
  final String? selectedCropId;
  final ValueChanged<CropCard>? onCropTap;
  final VoidCallback? onAddCrop;

  const CropCarousel({
    super.key,
    required this.crops,
    this.selectedCropId,
    this.onCropTap,
    this.onAddCrop,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: crops.length + 1, // +1 for "Add" button
        itemBuilder: (context, index) {
          if (index == crops.length) {
            return _buildAddButton();
          }
          return _buildCropItem(crops[index]);
        },
      ),
    );
  }

  Widget _buildCropItem(CropCard crop) {
    final isSelected = crop.id == selectedCropId;
    return GestureDetector(
      onTap: () => onCropTap?.call(crop),
      child: Container(
        width: 84,
        height: 113,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background color
              Container(
                color: crop.hasAlert
                    ? const Color(0xFFDDBFB6)
                    : const Color(0xFFDDDDDD),
              ),
              // Crop image
              Image.asset(
                crop.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => Container(
                  color: crop.hasAlert
                      ? const Color(0xFFDDBFB6)
                      : const Color(0xFF27C174),
                  child: const Icon(Icons.eco, color: Colors.white, size: 40),
                ),
              ),
              // Alert icon
              if (crop.hasAlert)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.error,
                    color: AppColors.alertRed,
                    size: 22,
                  ),
                ),
              // Progress bar at bottom
              Positioned(
                left: 7,
                right: 7,
                bottom: 10,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: crop.progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddCrop,
      child: Container(
        width: 84,
        height: 113,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.darkOverlay,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}
