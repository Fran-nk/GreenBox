import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_constants.dart';
import 'data/repositories/supabase_greenbox_repository.dart';
import 'domain/repositories/greenbox_repository.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local notifications
  await NotificationService().init();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  // Lock to portrait mode for mobile-first design
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable edge-to-edge system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set status bar & system navigation bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final GreenBoxRepository repository = SupabaseGreenBoxRepository();

  runApp(GreenBoxApp(repository: repository));
}

class GreenBoxApp extends StatefulWidget {
  final GreenBoxRepository repository;

  const GreenBoxApp({super.key, required this.repository});

  @override
  State<GreenBoxApp> createState() => _GreenBoxAppState();
}

class _GreenBoxAppState extends State<GreenBoxApp> {
  late final StreamSubscription<AuthState> _authSubscription;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    
    // Set initial screen based on current session
    final session = Supabase.instance.client.auth.currentSession;
    _initialScreen = session != null 
        ? DashboardScreen(repository: widget.repository)
        : LoginScreen(repository: widget.repository);

    // Listen for auth state changes (important for OAuth/Google login)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        if (mounted) {
          setState(() {
            _initialScreen = DashboardScreen(repository: widget.repository);
          });
        }
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) {
          setState(() {
            _initialScreen = LoginScreen(repository: widget.repository);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: MaterialApp(
        title: 'GreenBox',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: _initialScreen ?? const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}
