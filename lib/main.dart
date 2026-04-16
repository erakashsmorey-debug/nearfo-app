import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// google_fonts removed — causes AOT compilation crash with FontWeight const map keys
import 'utils/constants.dart';
import 'package:nearfo_app/utils/json_helpers.dart';
import 'providers/auth_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'l10n/l10n_helper.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/setup_profile_screen.dart';
import 'screens/home_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/compose_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/chat_detail_screen.dart';
import 'screens/saved_posts_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/my_circle_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/reels_screen.dart';
import 'screens/create_reel_screen.dart';
import 'screens/saved_reels_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/nearfo_score_screen.dart';
import 'screens/create_story_screen.dart';
import 'screens/hashtag_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/live_screen.dart';
import 'screens/copyright_report_screen.dart';
import 'screens/moderation_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/boss_command_screen.dart';
import 'services/socket_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'dart:async';
import 'services/push_notification_service.dart';
import 'services/callkit_service.dart';
import 'services/ad_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_chat_storage.dart';
import 'services/offline_message_queue.dart';
import 'screens/call_screen.dart';
import 'screens/monetization_dashboard_screen.dart';
import 'screens/language_screen.dart';
import 'widgets/glass_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create LanguageProvider early so it's ready before runApp
  final languageProvider = LanguageProvider();

  // Run all startup tasks in parallel for faster cold start
  await Future.wait<void>([
    // Initialize Firebase (required for FCM)
    Firebase.initializeApp().then((_) {}).catchError((e) {
      debugPrint('Firebase init error: $e');
    }),
    // Load user's saved radius preference (default 500km)
    LocationService.loadSavedRadius(),
    // Initialize CallKit for native call screen
    CallKitService.instance.initialize(),
    // Load user's saved language preference
    languageProvider.loadSavedLocale(),
  ]);

  // Register background FCM handler (must be after Firebase init)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize offline-first services (Hive, connectivity, message queue)
  // Graceful fail: if any service fails, app still launches — just without offline support
  try {
    await ConnectivityService.instance.init();
  } catch (e) {
    debugPrint('[Main] ConnectivityService init error (non-fatal): $e');
  }
  try {
    await LocalChatStorage.instance.init();
  } catch (e) {
    debugPrint('[Main] LocalChatStorage init error (non-fatal): $e');
  }
  try {
    await OfflineMessageQueue.instance.init();
  } catch (e) {
    debugPrint('[Main] OfflineMessageQueue init error (non-fatal): $e');
  }

  // Initialize Google AdMob (non-blocking — don't let ad failure crash app)
  try {
    unawaited(AdService.instance.initialize()); // Fire-and-forget, no await
  } catch (e) {
    debugPrint('[Main] AdMob init error (non-fatal): $e');
  }

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: NearfoColors.bg,
  ));

  // Global error handling — catch all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
  };

  // Custom error widget — show friendly UI instead of red screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0A0A10),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFF7C3AED), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString().length > 100
                    ? '${details.exceptionAsString().substring(0, 100)}...'
                    : details.exceptionAsString(),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(NearfoApp(languageProvider: languageProvider));
}

class NearfoApp extends StatelessWidget {
  final LanguageProvider languageProvider;
  const NearfoApp({super.key, required this.languageProvider});

  /// Global navigator key — shared with PushNotificationService for deep linking
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, _) {
          // Wire up NearfoColors to read from ThemeProvider
          NearfoColors.setProvider(themeProvider);
          final isLight = themeProvider.currentId == 'arctic_white';

          return MaterialApp(
        navigatorKey: navigatorKey,
        title: NearfoConfig.appName,
        debugShowCheckedModeBanner: false,
        // Internationalization (i18n) support
        locale: langProvider.locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: ThemeData(
          scaffoldBackgroundColor: NearfoColors.bg,
          brightness: isLight ? Brightness.light : Brightness.dark,
          primaryColor: NearfoColors.primary,
          colorScheme: ColorScheme(
            brightness: isLight ? Brightness.light : Brightness.dark,
            primary: NearfoColors.primary,
            secondary: NearfoColors.accent,
            surface: NearfoColors.card,
            error: NearfoColors.danger,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: NearfoColors.text,
            onError: Colors.white,
          ),
          textTheme: (isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme).apply(
            fontFamily: 'SpaceGrotesk',
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: NearfoColors.bg,
            elevation: 0,
            centerTitle: false,
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        initialRoute: NearfoRoutes.splash,
        routes: {
          NearfoRoutes.splash: (_) => const SplashScreen(),
          NearfoRoutes.onboarding: (_) => const OnboardingScreen(),
          NearfoRoutes.login: (_) => const LoginScreen(),
          NearfoRoutes.otpVerify: (_) => const OtpScreen(),
          NearfoRoutes.setupProfile: (_) => const SetupProfileScreen(),
          NearfoRoutes.home: (_) => const MainScreen(),
          NearfoRoutes.compose: (_) => const ComposeScreen(),
          NearfoRoutes.settings: (_) => const SettingsScreen(),
          NearfoRoutes.editProfile: (_) => const EditProfileScreen(),
          NearfoRoutes.savedPosts: (_) => const SavedPostsScreen(),
          NearfoRoutes.analytics: (_) => const AnalyticsScreen(),
          NearfoRoutes.myCircle: (_) => const MyCircleScreen(),
          NearfoRoutes.premium: (_) => const PremiumScreen(),
          NearfoRoutes.permissions: (_) => const PermissionsScreen(),
          NearfoRoutes.notifications: (_) => const NotificationsScreen(),
          NearfoRoutes.savedReels: (_) => const SavedReelsScreen(),
          '/createReel': (_) => const CreateReelScreen(),
          '/collections': (_) => const CollectionsScreen(),
          '/live': (_) => const LiveScreen(),
          NearfoRoutes.nearfoScore: (_) => const NearfoScoreScreen(),
          NearfoRoutes.createStory: (_) => const CreateStoryScreen(),
          '/create-group': (_) => const CreateGroupScreen(),
          '/copyright-report': (_) => const CopyrightReportScreen(),
          '/moderation': (_) => const ModerationScreen(),
          NearfoRoutes.adminPanel: (_) => const AdminPanelScreen(),
          NearfoRoutes.monetization: (_) => const MonetizationDashboardScreen(),
          '/language': (_) => const LanguageScreen(),
          NearfoRoutes.bossCommand: (_) => const Scaffold(
            backgroundColor: Color(0xFF0A0A10),
            body: SafeArea(child: BossCommandScreen()),
          ),
        },
        onGenerateRoute: (settings) {
          // Handle routes that need arguments
          final name = settings.name ?? '';

          // Handle /user-profile or /user-profile/userId patterns
          if (name == NearfoRoutes.userProfile || name.startsWith('/user-profile/')) {
            final args = settings.arguments is Map<String, dynamic> ? settings.arguments as Map<String, dynamic> : <String, dynamic>{};
            // Extract userId from path if present (e.g., /user-profile/abc123)
            String? pathUserId;
            if (name.startsWith('/user-profile/') && name.length > '/user-profile/'.length) {
              pathUserId = name.substring('/user-profile/'.length);
            }
            return MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                handle: args.asString('handle'),
                userId: args.asStringOrNull('userId') ?? pathUserId,
              ),
            );
          }
          if (settings.name == NearfoRoutes.chatDetail) {
            final args = settings.arguments is Map<String, dynamic> ? settings.arguments as Map<String, dynamic> : <String, dynamic>{};
            return MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                recipientId: args.asString('recipientId'),
                recipientName: args.asString('recipientName', 'Chat'),
                recipientHandle: args.asStringOrNull('recipientHandle'),
                recipientAvatar: args.asStringOrNull('recipientAvatar'),
                isOnline: args.asBool('isOnline'),
                lastSeenText: args.asString('lastSeenText'),
                existingChatId: args.asStringOrNull('existingChatId'),
                isGroup: args.asBool('isGroup'),
              ),
            );
          }
          if (settings.name == '/hashtag') {
            final tag = settings.arguments is String ? settings.arguments as String : '';
            return MaterialPageRoute(
              builder: (_) => HashtagScreen(hashtag: tag),
            );
          }
          return null;
        },
      );
        },
      ),
    );
  }
}

// ===== MAIN SCREEN WITH BOTTOM NAV =====
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _unreadChatCount = 0;
  StreamSubscription? _incomingCallSub;
  StreamSubscription? _iceBufferSub;
  StreamSubscription? _chatUpdateSub;
  StreamSubscription? _newMessageSub;
  final GlobalKey<ReelsScreenState> _reelsKey = GlobalKey<ReelsScreenState>();

  late final List<Widget> _screens = [
    const HomeScreen(),
    ReelsScreen(key: _reelsKey),
    const DiscoverScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Connect Socket.io when main screen loads (user is authenticated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        try {
          SocketService.instance.connect(userId, authToken: ApiService.accessToken);
        } catch (e) {
          debugPrint('[Socket] Connect error: $e');
        }
        _listenForIncomingCalls();
        unawaited(_updateLocation());
        unawaited(_loadUnreadChatCount());
        // Listen for chat updates (message received while not in chat) to update badge
        _chatUpdateSub = SocketService.instance.onChatUpdate.listen((_) {
          if (mounted) unawaited(_loadUnreadChatCount());
        });
        // Also listen for new_message (when user might be in a different chat or just returned)
        _newMessageSub = SocketService.instance.onNewMessage.listen((_) {
          // Delay slightly to allow readBy to update on server
          unawaited(Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) unawaited(_loadUnreadChatCount());
          }));
        });
      }
    });
  }

  Future<void> _loadUnreadChatCount() async {
    final res = await ApiService.getChats(limit: 100);
    if (res.isSuccess && res.data != null && mounted) {
      int total = 0;
      for (final chat in res.data!) {
        total += (chat['unreadCount'] as int?) ?? 0;
      }
      if (_unreadChatCount != total) {
        setState(() => _unreadChatCount = total);
      }
    }
  }

  /// Auto-update location on every app open
  Future<void> _updateLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        await context.read<AuthProvider>().updateLocation(pos.latitude, pos.longitude);
        debugPrint('[Location] Updated: ${pos.latitude}, ${pos.longitude}');
      }
    } catch (e) {
      debugPrint('[Location] Update failed: $e');
    }
  }

  void _listenForIncomingCalls() {
    // Listen for socket-based incoming calls (when app is in foreground)
    // Show native call screen via CallKit and store the SDP offer
    _incomingCallSub = SocketService.instance.onIncomingCall.listen((data) {
      if (!mounted) return;
      final callerId = data['callerId']?.toString() ?? '';
      debugPrint('[Main] Socket incoming_call from $callerId');

      // Store the WebRTC offer so we can use it when user accepts
      _pendingCallOffer = data['offer'] is Map ? Map<String, dynamic>.from(data['offer'] as Map) : null;
      _pendingCallerId = callerId;
      _pendingIceCandidates.clear(); // Clear any stale candidates

      // Start buffering ICE candidates from caller IMMEDIATELY
      // These arrive before CallScreen opens (while CallKit is showing)
      // Without buffering, broadcast StreamController drops them silently!
      _iceBufferSub?.cancel();
      _iceBufferSub = SocketService.instance.onIceCandidate.listen((iceData) {
        if (_pendingCallerId != null) {
          _pendingIceCandidates.add(iceData);
          debugPrint('[Main] Buffered ICE candidate #${_pendingIceCandidates.length} (CallScreen not open yet)');
        }
      });

      unawaited(CallKitService.instance.showIncomingCall(
        callerId: callerId,
        callerName: data['callerName']?.toString() ?? 'Unknown',
        callerAvatar: data['callerAvatar']?.toString(),
        isVideo: data['isVideo'] == true || data['isVideo'] == 'true',
      ));
    });

    // Handle CallKit accept — navigate to CallScreen
    CallKitService.instance.onCallAccepted = (callData) {
      try {
        if (!mounted) return;
        final myUser = context.read<AuthProvider>().user;
        if (myUser == null) return;
        final callerId = (callData['callerId']?.toString() ?? '').trim();
        if (callerId.isEmpty) {
          debugPrint('[Main] Ignoring CallKit accept with empty callerId');
          return;
        }
        final callerName = callData['callerName']?.toString() ?? 'Unknown';
        final callerAvatar = callData['callerAvatar']?.toString();
        // CallKit extra stores isVideo as String ("true"/"false"), not bool
        final isVideoRaw = callData['isVideo'];
        final isVideo = isVideoRaw == true || isVideoRaw == 'true';

        // Use stored offer if it matches the caller, otherwise pass null (CallScreen will fetch from backend)
        final offer = (_pendingCallerId == callerId) ? _pendingCallOffer : null;
        debugPrint('[Main] CallKit accepted — caller: $callerName, isVideo: $isVideo, offer: ${offer != null}, bufferedICE: ${_pendingIceCandidates.length}');

        // Stop buffering ICE candidates — CallScreen will take over with its own listener
        _iceBufferSub?.cancel();
        _iceBufferSub = null;

        // Snapshot the buffered candidates to pass to CallScreen
        final bufferedCandidates = List<Map<String, dynamic>>.from(_pendingIceCandidates);

        // Ensure all CallKit notifications are dismissed before opening CallScreen
        unawaited(CallKitService.instance.endAllCalls());

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              recipientId: callerId,
              recipientName: callerName,
              recipientAvatar: callerAvatar?.isNotEmpty == true ? callerAvatar : null,
              callerId: myUser.id,
              callerName: myUser.name,
              isVideo: isVideo,
              isIncoming: true,
              incomingOffer: offer,
              bufferedIceCandidates: bufferedCandidates,
            ),
          ),
        );
      } catch (e) {
        debugPrint('[Main] CallKit accept handler error: $e');
      }
      _pendingCallOffer = null;
      _pendingCallerId = null;
      _pendingIceCandidates.clear();
    };

    // Handle CallKit decline — reject via socket
    CallKitService.instance.onCallDeclined = (callData) {
      final callerId = (callData['callerId'] as String?) ?? '';
      if (callerId.isNotEmpty) {
        SocketService.instance.rejectCall(callerId: callerId);
      }
      _iceBufferSub?.cancel();
      _iceBufferSub = null;
      _pendingCallOffer = null;
      _pendingCallerId = null;
      _pendingIceCandidates.clear();
    };
  }

  Map<String, dynamic>? _pendingCallOffer;
  String? _pendingCallerId;
  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _iceBufferSub?.cancel();
    _chatUpdateSub?.cancel();
    _newMessageSub?.cancel();
    SocketService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Screen Content ──
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // ── FABs (hidden on Reels tab) ──
          if (_currentIndex != 1)
            Positioned(
              bottom: 96,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Go Live FAB — premium pulsing red button
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/live'),
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: NearfoColors.gradientDanger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Compose FAB — gradient with glow
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, NearfoRoutes.compose),
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.5), blurRadius: 16, spreadRadius: 2, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

          // ── Glass Bottom Nav (BackdropFilter) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GlassBottomNav(
              currentIndex: _currentIndex,
              unreadChatCount: _unreadChatCount,
              onTap: (i) {
                // Pause reels when leaving Reels tab, resume when entering
                if (_currentIndex == 1 && i != 1) {
                  _reelsKey.currentState?.pauseAll();
                } else if (_currentIndex != 1 && i == 1) {
                  _reelsKey.currentState?.resumeCurrent();
                }
                setState(() => _currentIndex = i);
                unawaited(_loadUnreadChatCount()); // Refresh badge on every tab switch
              },
            ),
          ),
        ],
      ),
    );
  }
}
