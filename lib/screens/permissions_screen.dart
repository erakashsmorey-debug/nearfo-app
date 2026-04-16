import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/push_notification_service.dart';
import '../main.dart';
import '../l10n/l10n_helper.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _cameraGranted = false;
  bool _storageGranted = false;
  bool _isRequesting = false;
  int _currentStep = 0; // 0=not started, 1=location, 2=notification, 3=camera, 4=storage, 5=done

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _checkExistingPermissions();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPermissions() async {
    final locStatus = await Permission.location.status;
    final notifStatus = await Permission.notification.status;
    final camStatus = await Permission.camera.status;
    final storageStatus = await Permission.photos.status;

    setState(() {
      _locationGranted = locStatus.isGranted;
      _notificationGranted = notifStatus.isGranted;
      _cameraGranted = camStatus.isGranted;
      _storageGranted = storageStatus.isGranted;
    });

    // If all already granted, skip to home
    if (_locationGranted && _notificationGranted && _cameraGranted && _storageGranted) {
      _goToNextScreen();
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);

    // Step 1: Location — graceful fail: if location permission crashes, skip it
    setState(() => _currentStep = 1);
    if (!_locationGranted) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission locPerm = await Geolocator.checkPermission();
          if (locPerm == LocationPermission.denied) {
            locPerm = await Geolocator.requestPermission();
          }
          setState(() => _locationGranted = locPerm == LocationPermission.whileInUse || locPerm == LocationPermission.always);
        }
      } catch (e) {
        debugPrint('[Permissions] Location request error (skipping): $e');
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 2: Notifications
    setState(() => _currentStep = 2);
    if (!_notificationGranted) {
      try {
        final status = await Permission.notification.request();
        setState(() => _notificationGranted = status.isGranted);
      } catch (e) {
        debugPrint('[Permissions] Notification request error (skipping): $e');
      }
    }
    // Initialize push notifications if granted (non-blocking)
    if (_notificationGranted) {
      try {
        unawaited(PushNotificationService.initialize(navKey: NearfoApp.navigatorKey));
      } catch (e) {
        debugPrint('[Permissions] Push init error (non-fatal): $e');
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 3: Camera
    setState(() => _currentStep = 3);
    if (!_cameraGranted) {
      try {
        final status = await Permission.camera.request();
        setState(() => _cameraGranted = status.isGranted);
      } catch (e) {
        debugPrint('[Permissions] Camera request error (skipping): $e');
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 4: Storage / Photos
    setState(() => _currentStep = 4);
    if (!_storageGranted) {
      try {
        final status = await Permission.photos.request();
        bool granted = status.isGranted;
        if (!granted) {
          final storageStatus = await Permission.storage.request();
          granted = storageStatus.isGranted;
        }
        setState(() => _storageGranted = granted);
      } catch (e) {
        debugPrint('[Permissions] Storage request error (skipping): $e');
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _currentStep = 5;
      _isRequesting = false;
    });

    // Small delay to show completion then navigate
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _goToNextScreen();
  }

  Future<void> _goToNextScreen() async {
    // Mark permissions screen as shown — won't show again on app restart
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_screen_shown', true);
    if (!mounted) return;
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
    final nextRoute = (((args?['nextRoute'] as String?) ?? NearfoRoutes.home));
    Navigator.pushNamedAndRemoveUntil(context, nextRoute, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 50),

                // Header icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: NearfoColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: NearfoColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),

                Text(
                  context.l10n.permissionsTitle,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: NearfoColors.text),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.permissionsSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: NearfoColors.textMuted, height: 1.6),
                ),
                SizedBox(height: 36),

                // Permission items
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _permissionTile(
                          icon: Icons.location_on_rounded,
                          title: context.l10n.permissionsLocationTitle,
                          subtitle: context.l10n.permissionsLocationSubtitle,
                          color: NearfoColors.accent,
                          isGranted: _locationGranted,
                          isActive: _currentStep == 1,
                        ),
                        const SizedBox(height: 12),
                        _permissionTile(
                          icon: Icons.notifications_active_rounded,
                          title: context.l10n.permissionsNotificationTitle,
                          subtitle: context.l10n.permissionsNotificationSubtitle,
                          color: NearfoColors.warning,
                          isGranted: _notificationGranted,
                          isActive: _currentStep == 2,
                        ),
                        const SizedBox(height: 12),
                        _permissionTile(
                          icon: Icons.camera_alt_rounded,
                          title: context.l10n.permissionsCameraTitle,
                          subtitle: context.l10n.permissionsCameraSubtitle,
                          color: NearfoColors.pink,
                          isGranted: _cameraGranted,
                          isActive: _currentStep == 3,
                        ),
                        const SizedBox(height: 12),
                        _permissionTile(
                          icon: Icons.photo_library_rounded,
                          title: context.l10n.permissionsStorageTitle,
                          subtitle: context.l10n.permissionsStorageSubtitle,
                          color: NearfoColors.success,
                          isGranted: _storageGranted,
                          isActive: _currentStep == 4,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      // Allow All button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: NearfoColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: NearfoColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isRequesting ? null : _requestAllPermissions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isRequesting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                      const SizedBox(width: 12),
                                      Text(
                                        _stepLabel(),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ],
                                  )
                                : Text(
                                    context.l10n.permissionsAllowAll,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Skip button
                      TextButton(
                        onPressed: _isRequesting ? null : _goToNextScreen,
                        child: Text(
                          context.l10n.permissionsSkip,
                          style: TextStyle(color: NearfoColors.textDim, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stepLabel() {
    switch (_currentStep) {
      case 1: return context.l10n.permissionsStepLocation;
      case 2: return context.l10n.permissionsStepNotification;
      case 3: return context.l10n.permissionsStepCamera;
      case 4: return context.l10n.permissionsStepMedia;
      case 5: return context.l10n.permissionsStepDone;
      default: return context.l10n.permissionsStepSetup;
    }
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isGranted,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? color.withOpacity(0.08)
            : isGranted
                ? NearfoColors.success.withOpacity(0.05)
                : NearfoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.withOpacity(0.4)
              : isGranted
                  ? NearfoColors.success.withOpacity(0.3)
                  : NearfoColors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: NearfoColors.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: NearfoColors.textMuted)),
              ],
            ),
          ),
          if (isActive)
            SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: NearfoColors.primaryLight),
            )
          else if (isGranted)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: NearfoColors.success.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: NearfoColors.success, size: 18),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: NearfoColors.textDim.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.circle_outlined, color: NearfoColors.textDim, size: 18),
            ),
        ],
      ),
    );
  }
}
