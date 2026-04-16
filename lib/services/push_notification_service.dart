import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import 'callkit_service.dart';
import 'socket_service.dart';

/// Top-level background FCM handler — MUST be top-level (not a class method).
/// This runs in a separate isolate when the app is killed/background.
/// It shows the native phone-like call screen via flutter_callkit_incoming.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM BG] Received: ${message.data}');
  final type = ((message.data['type'] as String?) ?? '');

  if (type == 'incoming_call') {
    await CallKitService.instance.showIncomingCall(
      callerId: ((message.data['callerId'] as String?) ?? ''),
      callerName: ((message.data['callerName'] as String?) ?? 'Incoming Call'),
      callerAvatar: message.data['callerAvatar'] as String?,
      isVideo: (message.data['isVideo'] as String?) == 'true',
    );
  }
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Guard against duplicate initialization
  static bool _initialized = false;

  /// Track stream subscriptions to prevent memory leaks
  static final List<StreamSubscription> _subscriptions = [];

  /// Notification ID counter
  static int _notifId = 0;

  /// Track grouped message counts per sender for inbox-style notifications
  static final Map<String, int> _messageGroupCounts = {};
  static final Map<String, List<String>> _messageGroupLines = {};

  /// Flutter Local Notifications plugin
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ═══════════ NOTIFICATION CHANNELS ═══════════
  // Multiple channels for different notification categories with different priorities

  /// Messages channel — highest priority, custom vibration
  static final AndroidNotificationChannel _messagesChannel = AndroidNotificationChannel(
    'nearfo_messages',
    'Messages',
    description: 'Chat messages and voice messages',
    importance: Importance.max,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 250, 100, 250]),
    playSound: true,
    enableLights: true,
    ledColor: Color(0xFF7C3AED),
  );

  /// Social channel — likes, comments, follows
  static final AndroidNotificationChannel _socialChannel = AndroidNotificationChannel(
    'nearfo_social',
    'Social',
    description: 'Likes, comments, follows, and mentions',
    importance: Importance.high,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 200]),
    playSound: true,
    enableLights: true,
    ledColor: Color(0xFF06B6D4),
  );

  /// General channel — system, updates, misc
  static final AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    'nearfo_notifications',
    'Nearfo Notifications',
    description: 'General notifications from Nearfo',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  /// Calls channel — critical priority for incoming calls
  static final AndroidNotificationChannel _callsChannel = AndroidNotificationChannel(
    'nearfo_calls',
    'Calls',
    description: 'Incoming call notifications',
    importance: Importance.max,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    playSound: true,
    enableLights: true,
    ledColor: Color(0xFF00B894),
  );

  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (navKey != null) navigatorKey = navKey;

    if (_initialized) {
      debugPrint('[FCM] Already initialized, skipping duplicate init');
      return;
    }
    _initialized = true;

    // ===== CREATE ALL ANDROID NOTIFICATION CHANNELS =====
    if (Platform.isAndroid) {
      const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null) {
            // Parse action from payload
            final parts = payload.split('|');
            final type = parts.isNotEmpty ? parts[0] : '';
            final actionId = response.actionId;

            if (actionId == 'reply_action' && response.input != null && parts.length > 1) {
              // Direct reply from notification
              _handleDirectReply(parts[1], response.input!);
            } else if (actionId == 'mark_read_action' && parts.length > 1) {
              _handleMarkRead(parts[1]);
            } else {
              _navigateFromData({'type': type, if (parts.length > 1) 'id': parts[1]});
            }
          }
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Create all channels
      await androidPlugin?.createNotificationChannel(_messagesChannel);
      await androidPlugin?.createNotificationChannel(_socialChannel);
      await androidPlugin?.createNotificationChannel(_generalChannel);
      await androidPlugin?.createNotificationChannel(_callsChannel);
      debugPrint('[FCM] All 4 Android notification channels created');
    }

    // ===== REQUEST PERMISSION & REGISTER =====
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
      criticalAlert: true, // For calls
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerToken();
      _subscriptions.add(_fcm.onTokenRefresh.listen((t) => _registerToken(token: t)));
      _subscriptions.add(FirebaseMessaging.onMessage.listen(_handleForeground));
      _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen(_handleTap));
      final init = await _fcm.getInitialMessage();
      if (init != null) _handleTap(init);
    }

    // ===== SET FOREGROUND NOTIFICATION PRESENTATION (iOS) =====
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
  }

  static Future<void> _registerToken({String? token, int retryCount = 0}) async {
    try {
      final t = token ?? await _fcm.getToken();
      if (t != null) {
        debugPrint('FCM Token: ${t.substring(0, 20)}...');
        await ApiService.registerFcmToken(t);
      }
    } catch (e) {
      debugPrint('FCM reg error (attempt ${retryCount + 1}): $e');
      if (retryCount < 3) {
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return _registerToken(token: token, retryCount: retryCount + 1);
      }
    }
  }

  /// Cancel all listeners to prevent memory leaks
  static Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
    _messageGroupCounts.clear();
    _messageGroupLines.clear();
    // Clean up notification banner
    _bannerDismissTimer?.cancel();
    _bannerDismissTimer = null;
    if (_currentBannerEntry != null && !_currentBannerRemoved) {
      try { _currentBannerEntry!.remove(); } catch (_) {}
    }
    _currentBannerEntry = null;
    _currentBannerRemoved = false;
  }

  /// Callback for incoming call push notifications (set by main.dart)
  static void Function(Map<String, dynamic> data)? onIncomingCallPush;

  /// Check if socket is connected
  static bool get _isSocketConnected {
    try {
      return SocketService.instance.isConnected;
    } catch (_) {
      return false;
    }
  }

  // ═══════════ FOREGROUND HANDLER — RICH NOTIFICATIONS ═══════════

  static Future<void> _handleForeground(RemoteMessage m) async {
    debugPrint('[FCM fg] ${m.notification?.title} | data: ${m.data}');
    final type = ((m.data['type'] as String?) ?? '');

    // ── INCOMING CALL ──
    // Always show CallKit for incoming calls from push — don't skip based on socket state.
    // There's a race condition: backend may use push path when it thinks user is offline,
    // but socket IS connected (stale onlineUsers). If we skip here, user gets no call screen.
    // CallKit internally deduplicates — showing twice for same caller is safe.
    if (type == 'incoming_call') {
      debugPrint('[FCM] Incoming call push — showing CallKit (socketConnected: ${_isSocketConnected})');
      await CallKitService.instance.showIncomingCall(
        callerId: ((m.data['callerId'] as String?) ?? ''),
        callerName: ((m.data['callerName'] as String?) ?? 'Incoming Call'),
        callerAvatar: m.data['callerAvatar'] as String?,
        isVideo: (m.data['isVideo'] as String?) == 'true',
      );
      return;
    }

    // ── MESSAGE NOTIFICATION — Rich with inline reply ──
    if (type == 'message' || type == 'message_request') {
      await _showMessageNotification(m);
      return;
    }

    // ── SOCIAL NOTIFICATION — With big picture if available ──
    if (type == 'like' || type == 'comment' || type == 'follow' || type == 'mention' || type == 'story_like') {
      await _showSocialNotification(m);
      return;
    }

    // ── FALLBACK: Generic rich notification ──
    await _showGenericNotification(m);
  }

  // ═══════════ MESSAGE NOTIFICATIONS (Inbox + Reply) ═══════════

  static Future<void> _showMessageNotification(RemoteMessage m) async {
    final senderName = (m.data['senderName'] as String?) ?? m.notification?.title ?? 'Someone';
    final senderId = (m.data['senderId'] as String?) ?? (m.data['chatId'] as String?) ?? '';
    final messageText = (m.data['messageText'] as String?) ?? m.notification?.body ?? 'Sent a message';
    final senderAvatar = m.data['senderAvatar'] as String?;
    final msgType = (m.data['messageType'] as String?) ?? 'text';

    // Format message body based on type
    String body = messageText;
    if (msgType == 'image') body = '📷 Photo';
    if (msgType == 'video') body = '🎬 Video';
    if (msgType == 'voice') body = '🎤 Voice message';

    // Track for inbox-style grouping
    _messageGroupCounts[senderId] = (_messageGroupCounts[senderId] ?? 0) + 1;
    _messageGroupLines.putIfAbsent(senderId, () => []);
    if (_messageGroupLines[senderId]!.length >= 6) {
      _messageGroupLines[senderId]!.removeAt(0); // Keep last 6
    }
    _messageGroupLines[senderId]!.add(body);

    // Download sender avatar for BigPicture
    AndroidBitmap<Object>? largeIcon;
    if (senderAvatar != null && senderAvatar.isNotEmpty) {
      largeIcon = await _downloadAndCacheBitmap(senderAvatar, 'avatar_$senderId');
    }

    // Build inbox-style if multiple messages from same person
    final count = _messageGroupCounts[senderId] ?? 1;
    final lines = _messageGroupLines[senderId] ?? [body];

    InboxStyleInformation? inboxStyle;
    if (count > 1) {
      inboxStyle = InboxStyleInformation(
        lines,
        contentTitle: '$senderName ($count messages)',
        summaryText: '$count new messages',
      );
    }

    // Action: Inline Reply
    const replyAction = AndroidNotificationAction(
      'reply_action',
      'Reply',
      icon: DrawableResourceAndroidBitmap('@drawable/ic_notification'),
      inputs: [AndroidNotificationActionInput(label: 'Type a message...')],
    );

    // Action: Mark as Read
    const markReadAction = AndroidNotificationAction(
      'mark_read_action',
      'Mark as Read',
      icon: DrawableResourceAndroidBitmap('@drawable/ic_notification'),
    );

    final androidDetails = AndroidNotificationDetails(
      _messagesChannel.id,
      _messagesChannel.name,
      channelDescription: _messagesChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.private,
      largeIcon: largeIcon,
      styleInformation: inboxStyle ?? BigTextStyleInformation(
        body,
        contentTitle: senderName,
        summaryText: 'Nearfo Message',
      ),
      actions: [replyAction, markReadAction],
      groupKey: 'nearfo_messages_group',
      setAsGroupSummary: false,
      colorized: true,
      color: const Color(0xFF7C3AED),
      ticker: '$senderName: $body',
      autoCancel: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
    );

    await _localNotifications.show(
      senderId.hashCode, // Same ID per sender = updates existing
      senderName,
      body,
      NotificationDetails(android: androidDetails),
      payload: 'message|$senderId',
    );

    // Also show group summary notification
    if (_messageGroupCounts.values.fold<int>(0, (a, b) => a + b) > 1) {
      final totalCount = _messageGroupCounts.values.fold<int>(0, (a, b) => a + b);
      final senderCount = _messageGroupCounts.length;
      await _localNotifications.show(
        0, // ID 0 = group summary
        'Nearfo',
        '$totalCount messages from $senderCount ${senderCount == 1 ? 'chat' : 'chats'}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _messagesChannel.id,
            _messagesChannel.name,
            channelDescription: _messagesChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            groupKey: 'nearfo_messages_group',
            setAsGroupSummary: true,
            color: const Color(0xFF7C3AED),
            styleInformation: InboxStyleInformation(
              _messageGroupCounts.entries.map((e) => '${e.value} new messages').toList(),
              contentTitle: '$totalCount new messages',
              summaryText: 'Nearfo',
            ),
          ),
        ),
      );
    }

    // Also show in-app banner
    _showInAppBanner(m.notification?.title ?? senderName, body, m.data);
  }

  // ═══════════ SOCIAL NOTIFICATIONS (BigPicture) ═══════════

  static Future<void> _showSocialNotification(RemoteMessage m) async {
    final title = m.notification?.title ?? 'Nearfo';
    final body = m.notification?.body ?? '';
    final type = (m.data['type'] as String?) ?? '';
    final senderAvatar = m.data['senderAvatar'] as String?;
    final postImage = m.data['postImage'] as String?;

    // Get emoji for notification type
    String emoji = '';
    switch (type) {
      case 'like': emoji = '❤️'; break;
      case 'comment': emoji = '💬'; break;
      case 'follow': emoji = '👤'; break;
      case 'mention': emoji = '@'; break;
      case 'story_like': emoji = '⭐'; break;
    }

    // Download avatar as large icon
    AndroidBitmap<Object>? largeIcon;
    if (senderAvatar != null && senderAvatar.isNotEmpty) {
      largeIcon = await _downloadAndCacheBitmap(senderAvatar, 'social_${m.messageId}');
    }

    // Download post image for BigPicture style
    BigPictureStyleInformation? bigPicStyle;
    if (postImage != null && postImage.isNotEmpty) {
      final picBitmap = await _downloadAndCacheBitmap(postImage, 'post_${m.messageId}');
      if (picBitmap != null) {
        bigPicStyle = BigPictureStyleInformation(
          picBitmap,
          contentTitle: '$emoji $title',
          summaryText: body,
          largeIcon: largeIcon,
          hideExpandedLargeIcon: false,
        );
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _socialChannel.id,
      _socialChannel.name,
      channelDescription: _socialChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.social,
      largeIcon: largeIcon,
      styleInformation: bigPicStyle ?? BigTextStyleInformation(
        body,
        contentTitle: '$emoji $title',
        summaryText: 'Nearfo',
      ),
      groupKey: 'nearfo_social_group',
      colorized: true,
      color: const Color(0xFF06B6D4),
      ticker: '$emoji $title',
      autoCancel: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
    );

    await _localNotifications.show(
      _notifId++,
      '$emoji $title',
      body,
      NotificationDetails(android: androidDetails),
      payload: type,
    );

    _showInAppBanner(title, body, m.data);
  }

  // ═══════════ GENERIC NOTIFICATION ═══════════

  static Future<void> _showGenericNotification(RemoteMessage m) async {
    final title = m.notification?.title ?? 'Nearfo';
    final body = m.notification?.body ?? '';
    final imageUrl = m.data['imageUrl'] as String? ?? m.notification?.android?.imageUrl;

    BigPictureStyleInformation? bigPicStyle;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final picBitmap = await _downloadAndCacheBitmap(imageUrl, 'gen_${m.messageId}');
      if (picBitmap != null) {
        bigPicStyle = BigPictureStyleInformation(
          picBitmap,
          contentTitle: title,
          summaryText: body,
        );
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _generalChannel.id,
      _generalChannel.name,
      channelDescription: _generalChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: bigPicStyle ?? BigTextStyleInformation(body, contentTitle: title),
      colorized: true,
      color: const Color(0xFF7C3AED),
      autoCancel: true,
      showWhen: true,
    );

    await _localNotifications.show(
      _notifId++,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: ((m.data['type'] as String?) ?? ''),
    );

    _showInAppBanner(title, body, m.data);
  }

  // ═══════════ IN-APP NOTIFICATION BANNER (Premium overlay) ═══════════

  static OverlayEntry? _currentBannerEntry;
  static bool _currentBannerRemoved = false;
  static Timer? _bannerDismissTimer;

  static void _showInAppBanner(String title, String body, Map<String, dynamic> data) {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;

    // Remove any existing banner first (prevent stacking)
    _bannerDismissTimer?.cancel();
    _bannerDismissTimer = null;
    if (_currentBannerEntry != null && !_currentBannerRemoved) {
      try { _currentBannerEntry!.remove(); } catch (_) {}
    }
    _currentBannerEntry = null;
    _currentBannerRemoved = false;

    void _safeRemoveEntry(OverlayEntry entry) {
      if (_currentBannerEntry == entry && !_currentBannerRemoved) {
        _currentBannerRemoved = true;
        try { entry.remove(); } catch (_) {}
      }
    }

    try {
      final overlay = Overlay.of(ctx);
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) => _NotificationBanner(
          title: title,
          body: body,
          onTap: () {
            _safeRemoveEntry(entry);
            _navigateFromData(data);
          },
          onDismiss: () => _safeRemoveEntry(entry),
        ),
      );

      _currentBannerEntry = entry;
      overlay.insert(entry);

      // Auto-dismiss after 4 seconds (tracked timer so it can be cancelled)
      _bannerDismissTimer = Timer(const Duration(seconds: 4), () {
        _safeRemoveEntry(entry);
      });
    } catch (e) {
      debugPrint('[FCM] Banner error: $e');
      // Fallback to SnackBar (dismissible on tap)
      try {
        final messenger = ScaffoldMessenger.of(ctx);
        messenger.clearSnackBars(); // Remove any stuck snackbars
        messenger.showSnackBar(
          SnackBar(
            content: GestureDetector(
              onTap: () {
                messenger.hideCurrentSnackBar();
                _navigateFromData(data);
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (body.isNotEmpty)
                    Text(body, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            backgroundColor: const Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            dismissDirection: DismissDirection.horizontal,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _navigateFromData(data),
            ),
          ),
        );
      } catch (_) {}
    }
  }

  // ═══════════ DIRECT REPLY FROM NOTIFICATION ═══════════

  static Future<void> _handleDirectReply(String chatId, String replyText) async {
    if (replyText.trim().isEmpty) return;
    debugPrint('[FCM] Direct reply to $chatId: $replyText');
    try {
      await ApiService.sendMessage(chatId: chatId, content: replyText.trim());
      // Clear message group for this chat after reply
      _messageGroupCounts.remove(chatId);
      _messageGroupLines.remove(chatId);
    } catch (e) {
      debugPrint('[FCM] Direct reply error: $e');
    }
  }

  /// Mark chat as read from notification action
  static Future<void> _handleMarkRead(String chatId) async {
    debugPrint('[FCM] Mark read: $chatId');
    _messageGroupCounts.remove(chatId);
    _messageGroupLines.remove(chatId);
    // Cancel notification for this chat
    await _localNotifications.cancel(chatId.hashCode);
  }

  // ═══════════ HELPER: Download image for notification ═══════════

  static Future<FilePathAndroidBitmap?> _downloadAndCacheBitmap(String url, String cacheKey) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/notif_$cacheKey.jpg');

      // Use cached version if fresh (< 1 hour)
      if (await file.exists()) {
        final modified = await file.lastModified();
        if (DateTime.now().difference(modified).inHours < 1) {
          return FilePathAndroidBitmap(file.path);
        }
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return FilePathAndroidBitmap(file.path);
      }
    } catch (e) {
      debugPrint('[FCM] Bitmap download error: $e');
    }
    return null;
  }

  /// Clear all message notification groups (call when user opens chat screen)
  static Future<void> clearMessageNotifications([String? chatId]) async {
    if (chatId != null) {
      _messageGroupCounts.remove(chatId);
      _messageGroupLines.remove(chatId);
      await _localNotifications.cancel(chatId.hashCode);
    } else {
      _messageGroupCounts.clear();
      _messageGroupLines.clear();
      await _localNotifications.cancelAll();
    }
  }

  static void _handleTap(RemoteMessage m) {
    debugPrint('FCM tap: ${m.data}');
    _navigateFromData(m.data);
  }

  /// Deep link navigation based on notification data payload
  static void _navigateFromData(Map<String, dynamic> data) {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('[FCM] NavigatorKey is null — cannot navigate.');
      return;
    }

    final type = ((data['type'] as String?) ?? '');
    final id = (((data['id'] as String?) ?? (data['senderId'] as String?)) ?? '');

    switch (type) {
      case 'incoming_call':
        break;
      case 'like':
      case 'comment':
      case 'mention':
        nav.pushNamed('/notifications');
        break;
      case 'follow':
        if (id.isNotEmpty) {
          nav.pushNamed('/user-profile', arguments: {'handle': id});
        } else {
          nav.pushNamed('/notifications');
        }
        break;
      case 'message':
      case 'message_request':
        final senderId = data['senderId'] as String? ?? '';
        final chatId = data['chatId'] as String? ?? '';
        final senderName = data['senderName'] as String? ?? 'Chat';
        final senderAvatar = data['senderAvatar'] as String?;
        if (senderId.isNotEmpty || chatId.isNotEmpty) {
          nav.pushNamed('/chat-detail', arguments: {
            'recipientId': senderId.isNotEmpty ? senderId : chatId,
            'recipientName': senderName,
            'recipientAvatar': senderAvatar,
          });
        } else {
          nav.pushNamed('/chat');
        }
        break;
      case 'story_like':
        nav.pushNamed('/home');
        break;
      default:
        nav.pushNamed('/notifications');
    }
  }

  static Future<void> unregister() async {
    try { await _fcm.deleteToken(); } catch (e) { debugPrint('FCM unreg: $e'); }
  }
}

// ═══════════ PREMIUM IN-APP NOTIFICATION BANNER ═══════════

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              if (details.velocity.pixelsPerSecond.dy < -100) _dismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1E2E), Color(0xFF252540)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // App icon
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('N', style: TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900,
                        )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.body,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Time indicator
                    Text(
                      'now',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
