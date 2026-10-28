import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      // main.dart listener will handle the redirect to LoginScreen
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cerrar sesión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Usuario';
    final name = user?.userMetadata?['full_name'] ?? email.split('@').first;
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              // Avatar
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            // Decode at display size (120 px @3x) instead of full resolution.
                            cacheWidth: 360,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: AppColors.textSecondary,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Name and Email
              Text(
                name,
                style: AppTextStyles.greeting.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: AppTextStyles.alertSubtitle.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Profile Options
              _ProfileOption(
                icon: Icons.settings_outlined,
                title: 'Configuración',
                onTap: () {},
              ),
              _ProfileOption(
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                onTap: () {},
              ),
              _ProfileOption(
                icon: Icons.help_outline_rounded,
                title: 'Ayuda y Soporte',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.black, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.alertSubtitle.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
