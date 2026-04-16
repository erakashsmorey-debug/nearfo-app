import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../services/push_notification_service.dart';
import '../main.dart';
import '../l10n/l10n_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.elasticOut)),
    );
    _controller.forward();
    // Defer heavy init until after first frame renders — splash UI appears instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<bool> _checkAllPermissionsGranted() async {
    try {
      final loc = await Geolocator.checkPermission();
      final locGranted = loc == LocationPermission.whileInUse || loc == LocationPermission.always;
      final notifGranted = await Permission.notification.isGranted;
      final camGranted = await Permission.camera.isGranted;
      final storageGranted = await Permission.photos.isGranted || await Permission.storage.isGranted;
      return locGranted && notifGranted && camGranted && storageGranted;
    } catch (e) {
      return false; // If check fails, show permissions screen
    }
  }

  Future<void> _initApp() async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.init();
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      if (authProvider.isLoggedIn && !authProvider.needsProfileSetup) {
        // Only show permissions screen ONCE after first login/install
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final permissionsShown = prefs.getBool('permissions_screen_shown') ?? false;
        final allGranted = await _checkAllPermissionsGranted();
        if (!mounted) return;
        if (permissionsShown || allGranted) {
          // Mark as shown if permissions are already granted (e.g. re-login)
          if (!permissionsShown && allGranted) {
            await prefs.setBool('permissions_screen_shown', true);
          }
          // Await push notification init BEFORE navigating to home —
          // prevents race condition where notification + location permission
          // dialogs appear simultaneously and freeze on Android 13+
          try {
            await PushNotificationService.initialize(navKey: NearfoApp.navigatorKey);
          } catch (e) {
            debugPrint('[Splash] Push notification init error (non-fatal): $e');
          }
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, NearfoRoutes.home);
        } else {
          // Don't initialize push here — PermissionsScreen handles notification
          // permission first, then initializes push after grant
          Navigator.pushReplacementNamed(context, NearfoRoutes.permissions, arguments: {'nextRoute': NearfoRoutes.home});
        }
      } else if (authProvider.isLoggedIn && authProvider.needsProfileSetup) {
        Navigator.pushReplacementNamed(context, NearfoRoutes.permissions, arguments: {'nextRoute': NearfoRoutes.setupProfile});
      } else {
        Navigator.pushReplacementNamed(context, NearfoRoutes.onboarding);
      }
    } catch (e) {
      // Graceful fail: if anything crashes during init, go to onboarding
      // so user isn't stuck on splash screen forever
      debugPrint('[Splash] Init error — falling back to onboarding: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, NearfoRoutes.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: Center(
        child: _AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: NearfoColors.primaryGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: NearfoColors.primary.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(context.l10n.splashLogoLetter, style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      )),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ShaderMask(
                    shaderCallback: (bounds) => NearfoColors.primaryGradient.createShader(bounds),
                    child: Text(
                      context.l10n.splashAppName,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NearfoConfig.tagline,
                    style: TextStyle(fontSize: 14, color: NearfoColors.textMuted, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const _AnimatedBuilder({super.key, required Animation<double> animation, required this.builder})
      : super(listenable: animation);
  @override
  Widget build(BuildContext context) => builder(context, null);
}
