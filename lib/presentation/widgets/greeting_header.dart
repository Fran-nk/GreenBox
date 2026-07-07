import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Top greeting bar: "Hola 👇 Frank" with notification bell.
class GreetingHeader extends StatelessWidget {
  final String userName;
  final String? alertMessage;
  final String? alertContext;
  final Color? alertColor;
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  const GreetingHeader({
    super.key,
    required this.userName,
    this.alertMessage,
    this.alertContext,
    this.alertColor,
    this.notificationCount = 0,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Hola 👇 $userName',
                  style: AppTextStyles.greeting,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildNotificationBell(),
            ],
          ),
          if (alertMessage != null) ...[
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: alertMessage!,
                    style: AppTextStyles.alertBold.copyWith(
                      color: alertColor ?? AppColors.alertRed,
                    ),
                  ),
                  if (alertContext != null)
                    TextSpan(
                      text: ' $alertContext',
                      style: AppTextStyles.alertSubtitle,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return GestureDetector(
      onTap: onNotificationTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          children: [
            const Icon(
              Icons.notifications_outlined,
              size: 26,
              color: AppColors.textPrimary,
            ),
            if (notificationCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.alertRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
