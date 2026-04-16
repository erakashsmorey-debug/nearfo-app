import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

/// Service to show native phone-like incoming call UI using flutter_callkit_incoming.
/// Works even when the app is killed / in background / screen locked.
class CallKitService {
  static final CallKitService _instance = CallKitService._();
  static CallKitService get instance => _instance;
  CallKitService._();

  static const _uuid = Uuid();

  /// Callback when user accepts the call from native UI
  void Function(Map<String, dynamic> callData)? onCallAccepted;

  /// Callback when user declines the call from native UI
  void Function(Map<String, dynamic> callData)? onCallDeclined;

  /// Currently active call UUID (to end it later)
  String? _currentCallId;

  /// Track active caller ID for dedup (prevent duplicate CallKit for same caller)
  String? _activeCallerId;

  /// Timestamp of last incoming call shown (for dedup window)
  DateTime? _lastIncomingCallTime;

  /// Track subscription to prevent memory leaks
  StreamSubscription? _eventSubscription;

  /// Initialize listeners for CallKit events
  Future<void> initialize() async {
    // Cancel previous subscription if re-initialized
    await _eventSubscription?.cancel();
    // Listen to call events from the native call screen
    _eventSubscription = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      debugPrint('[CallKit] Event: ${event.event} | body: ${event.body}');

      try {
        switch (event.event) {
          case Event.actionCallAccept:
            _handleAccept(event.body);
            break;
          case Event.actionCallDecline:
            _handleDecline(event.body);
            break;
          case Event.actionCallEnded:
            _handleEnded(event.body);
            break;
          case Event.actionCallTimeout:
            _handleDecline(event.body); // Treat timeout as decline
            break;
          default:
            break;
        }
      } catch (e) {
        debugPrint('[CallKit] Error handling event ${event.event}: $e');
      }
    });

    debugPrint('[CallKit] Initialized');
  }

  /// Show native incoming call screen
  /// Returns the call UUID so it can be ended later
  Future<String> showIncomingCall({
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required bool isVideo,
  }) async {
    // === DEDUP: Don't show duplicate CallKit for same caller within 15 seconds ===
    // This prevents double notification when both socket + push fire for the same call.
    if (_activeCallerId == callerId &&
        _lastIncomingCallTime != null &&
        DateTime.now().difference(_lastIncomingCallTime!).inSeconds < 15) {
      debugPrint('[CallKit] DEDUP — skipping duplicate for $callerName (already showing)');
      return _currentCallId ?? '';
    }

    // If a different caller, end the previous call first
    if (_currentCallId != null && _activeCallerId != callerId) {
      await endCurrentCall();
    }

    final callId = _uuid.v4();
    _currentCallId = callId;
    _activeCallerId = callerId;
    _lastIncomingCallTime = DateTime.now();

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Nearfo',
      avatar: callerAvatar,
      handle: callerName,
      type: isVideo ? 1 : 0, // 0 = audio, 1 = video
      duration: 45000, // Ring for 45 seconds
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar ?? '',
        'isVideo': isVideo.toString(),
      },
      headers: <String, dynamic>{},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#1a1a2e',
        backgroundUrl: '',
        actionColor: '#7C3AED',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Nearfo Calls',
        isShowCallID: false,
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    debugPrint('[CallKit] Showing incoming call: $callerName (id: $callId)');
    return callId;
  }

  /// End/dismiss the current call screen
  Future<void> endCurrentCall() async {
    if (_currentCallId != null) {
      await FlutterCallkitIncoming.endCall(_currentCallId!);
      _currentCallId = null;
      _activeCallerId = null;
      _lastIncomingCallTime = null;
    }
  }

  /// End a specific call by ID
  Future<void> endCall(String callId) async {
    await FlutterCallkitIncoming.endCall(callId);
    if (_currentCallId == callId) {
      _currentCallId = null;
      _activeCallerId = null;
      _lastIncomingCallTime = null;
    }
  }

  /// End all active calls
  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
    _currentCallId = null;
    _activeCallerId = null;
    _lastIncomingCallTime = null;
  }

  /// Safely convert body from native side (may be Map<Object?, Object?>) to Map<String, dynamic>
  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  void _handleAccept(dynamic body) {
    final typedBody = _safeMap(body);
    final extra = _safeMap(typedBody['extra']);
    debugPrint('[CallKit] Call accepted: $extra');
    // End ALL CallKit notifications (including duplicates from socket+push)
    unawaited(endAllCalls());
    onCallAccepted?.call(extra);
  }

  void _handleDecline(dynamic body) {
    final typedBody = _safeMap(body);
    final extra = _safeMap(typedBody['extra']);
    debugPrint('[CallKit] Call declined: $extra');
    // End ALL CallKit notifications
    unawaited(endAllCalls());
    onCallDeclined?.call(extra);
  }

  void _handleEnded(dynamic body) {
    debugPrint('[CallKit] Call ended');
    _currentCallId = null;
    _activeCallerId = null;
    _lastIncomingCallTime = null;
  }

  /// Check if there are any active calls (useful on app startup)
  Future<List<dynamic>> getActiveCalls() async {
    final result = await FlutterCallkitIncoming.activeCalls();
    return (result as List<dynamic>?) ?? [];
  }

  /// Dispose listener to prevent memory leaks
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
