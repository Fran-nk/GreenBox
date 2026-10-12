import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Bottom navigation bar matching Figma's "Menu" component.
/// Three items: Dashboard (chart icon), Water footprint (drop icon), Profile (avatar).
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 11.4,
            offset: const Offset(0, -2.3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: SizedBox(
          height: 60, // Reduced from 72
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.bar_chart_rounded,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.water_drop_rounded,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.account_circle,
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                isAvatar: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAvatar;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        child: isAvatar
            ? Container(
                width: 28, // Reduced from 35
                height: 28, // Reduced from 35
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.divider,
                  border: isSelected
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: const Icon(Icons.person, size: 18, color: AppColors.textSecondary), // Reduced from 22
              )
            : Icon(
                icon,
                size: 26, // Reduced from 35
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
      ),
    );
  }
}
