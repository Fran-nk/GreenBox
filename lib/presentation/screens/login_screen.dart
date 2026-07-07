import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/greenbox_repository.dart';

class LoginScreen extends StatefulWidget {
  final GreenBoxRepository repository;

  const LoginScreen({super.key, required this.repository});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  // Feature cards data for the carousel
  final List<_FeatureItem> _features = const [
    _FeatureItem(
      icon: Icons.sensors_rounded,
      title: 'Monitoreo en Tiempo Real',
      description: 'Controla pH, humedad y CE de tus cultivos al instante.',
    ),
    _FeatureItem(
      icon: Icons.notifications_active_rounded,
      title: 'Alertas Inteligentes',
      description: 'Recibe notificaciones cuando algo necesita tu atención.',
    ),
    _FeatureItem(
      icon: Icons.auto_graph_rounded,
      title: 'Analítica Avanzada',
      description: 'Visualiza tendencias y optimiza tus cultivos con datos.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _features.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.greenbox://login-callback',
      );
      // On mobile, this will open the browser.
      // After login, it should redirect back to the app if deep links are configured.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al iniciar sesión con Google'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // ── Hero Card with Logo ──
                      _buildHeroCard(),

                      const SizedBox(height: 24),

                      // ── Feature Carousel ──
                      SizedBox(
                        height: 130, // Reduced height
                        child: _buildFeatureCarousel(),
                      ),

                      // ── Page Indicator Dots ──
                      const SizedBox(height: 16),
                      _buildPageIndicator(),

                      const SizedBox(height: 24),

                      // ── Bottom Login Panel ──
                      Expanded(child: _buildLoginPanel()),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Green hero card at the top with logo and app name
  Widget _buildHeroCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2ECC71),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/greenbox_logo.png',
                  width: 64,
                  height: 64,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                // App name
                const Text(
                  'GREEN\nBOX',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'CORRECTO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carousel showcasing app features
  Widget _buildFeatureCarousel() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _features.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
      },
      itemBuilder: (context, index) {
        final feature = _features[index];
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double value = 1.0;
            if (_pageController.position.haveDimensions) {
              value = (_pageController.page ?? 0) - index;
              value = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
            }
            return Center(
              child: Transform.scale(scale: value, child: child),
            );
          },
          child: _buildFeatureCard(feature),
        );
      },
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(feature.icon, color: const Color(0xFF2ECC71), size: 28),
          const SizedBox(height: 8),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            feature.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Page indicator dots
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_features.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2ECC71)
                : Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  /// Bottom panel with login buttons
  Widget _buildLoginPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 48),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Google Sign-In Button
          _buildSocialButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            iconWidget: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Image.asset(
                    'assets/images/google_icon.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
            label: 'Continuar con Google',
          ),

          const SizedBox(height: 16),

          // Facebook Sign-In Button
          _buildSocialButton(
            onPressed: () {}, // Not active
            iconData: Icons.facebook,
            label: 'Continuar con Facebook',
          ),

          const SizedBox(height: 16),

          // Apple Sign-In Button
          _buildSocialButton(
            onPressed: () {}, // Not active
            iconData: Icons.apple,
            label: 'Continuar con Apple',
          ),
        ],
      ),
    );
  }

  /// Reusable social login button
  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    Widget? iconWidget,
    IconData? iconData,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconWidget != null)
              iconWidget
            else if (iconData != null)
              Icon(iconData, size: 24, color: Colors.black),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

/// Data model for feature carousel items
class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
