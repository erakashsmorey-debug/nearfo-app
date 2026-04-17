import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import 'offline_message_queue.dart';

class SocketService with WidgetsBindingObserver {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();
  SocketService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;
  bool _disposed = false;
  bool _isInBackground = false;
  Timer? _backgroundDisconnectTimer;
  Timer? _reconnectTimer;
  int _manualReconnectAttempts = 0;
  static const _maxManualReconnects = 10;
  static const _backgroundGracePeriod = Duration(seconds: 30);

  // Track active chat rooms to re-join on reconnect
  final Set<String> _activeChats = {};

  // Stream controllers for real-time events
  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _stopTypingController = StreamController<Map<String, dynamic>>.broadcast();
  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesDeliveredController = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _newNotificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageEditedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageReactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageReactionRemovedController = StreamController<Map<String, dynamic>>.broadcast();
  final _screenshotTakenController = StreamController<Map<String, dynamic>>.broadcast();
  final _userBlockedController = StreamController<Map<String, dynamic>>.broadcast();
  final _userRestrictedController = StreamController<Map<String, dynamic>>.broadcast();

  // Reconnection stream — fires every time socket (re)connects
  final _reconnectedController = StreamController<void>.broadcast();

  // Live streaming streams
  final _liveCommentController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveLikeController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveViewerJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveViewerLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveOfferController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveAnswerController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveIceController = StreamController<Map<String, dynamic>>.broadcast();

  // Call signaling streams
  final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
  final _callAnsweredController = StreamController<Map<String, dynamic>>.broadcast();
  final _callRejectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _iceCandidateController = StreamController<Map<String, dynamic>>.broadcast();
  final _callUnavailableController = StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onStopTyping => _stopTypingController.stream;
  Stream<Map<String, dynamic>> get onUserStatus => _userStatusController.stream;
  Stream<Map<String, dynamic>> get onChatUpdate => _chatUpdateController.stream;
  Stream<Map<String, dynamic>> get onMessagesDelivered => _messagesDeliveredController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _messagesReadController.stream;
  Stream<Map<String, dynamic>> get onNewNotification => _newNotificationController.stream;
  Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessageReaction => _messageReactionController.stream;
  Stream<Map<String, dynamic>> get onMessageReactionRemoved => _messageReactionRemovedController.stream;
  Stream<Map<String, dynamic>> get onScreenshotTaken => _screenshotTakenController.stream;
  Stream<Map<String, dynamic>> get onUserBlocked => _userBlockedController.stream;
  Stream<Map<String, dynamic>> get onUserRestricted => _userRestrictedController.stream;

  // Live streaming public streams
  Stream<Map<String, dynamic>> get onLiveComment => _liveCommentController.stream;
  Stream<Map<String, dynamic>> get onLiveLike => _liveLikeController.stream;
  Stream<Map<String, dynamic>> get onLiveViewerJoined => _liveViewerJoinedController.stream;
  Stream<Map<String, dynamic>> get onLiveViewerLeft => _liveViewerLeftController.stream;
  Stream<Map<String, dynamic>> get onLiveEnded => _liveEndedController.stream;
  Stream<Map<String, dynamic>> get onLiveStarted => _liveStartedController.stream;
  Stream<Map<String, dynamic>> get onLiveOffer => _liveOfferController.stream;
  Stream<Map<String, dynamic>> get onLiveAnswer => _liveAnswerController.stream;
  Stream<Map<String, dynamic>> get onLiveIce => _liveIceController.stream;

  // Call signaling public streams
  Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;
  Stream<Map<String, dynamic>> get onCallAnswered => _callAnsweredController.stream;
  Stream<Map<String, dynamic>> get onCallRejected => _callRejectedController.stream;
  Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  Stream<Map<String, dynamic>> get onIceCandidate => _iceCandidateController.stream;
  Stream<Map<String, dynamic>> get onCallUnavailable => _callUnavailableController.stream;
  Stream<void> get onReconnected => _reconnectedController.stream;

  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;

  /// App lifecycle handler — pause socket in background, resume in foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _currentUserId == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isInBackground = true;
        // Grace period before disconnecting — saves battery on quick app switches
        _backgroundDisconnectTimer?.cancel();
        _backgroundDisconnectTimer = Timer(_backgroundGracePeriod, () {
          if (_isInBackground && _socket != null) {
            debugPrint('[Socket] App in background for ${_backgroundGracePeriod.inSeconds}s — disconnecting to save battery');
            _socket?.disconnect();
          }
        });
        break;
      case AppLifecycleState.resumed:
        _isInBackground = false;
        _backgroundDisconnectTimer?.cancel();
        // Reconnect immediately when app comes to foreground
        if (_socket != null && !_isConnected && _currentUserId != null) {
          debugPrint('[Socket] App resumed — reconnecting');
          _socket?.connect();
        }
        break;
      default:
        break;
    }
  }

  /// Safely convert socket data to typed Map (won't crash on unexpected format)
  Map<String, dynamic>? _toTypedMap(dynamic data) {
    try {
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is String) return {'value': data};
      debugPrint('[Socket] Unexpected data type: ${data.runtimeType}');
      return null;
    } catch (e) {
      debugPrint('[Socket] Data conversion error: $e');
      return null;
    }
  }

  /// Safely add data to a stream controller (won't crash if closed)
  void _safeAdd(StreamController<Map<String, dynamic>> controller, Map<String, dynamic> data) {
    try {
      if (!controller.isClosed && !_disposed) {
        controller.add(data);
      }
    } catch (e) {
      debugPrint('[Socket] Safe add error: $e');
    }
  }

  /// Safe emit: convert data + add to stream (combined helper)
  void _safeEmitToStream(StreamController<Map<String, dynamic>> controller, dynamic data) {
    final typed = _toTypedMap(data);
    if (typed != null) _safeAdd(controller, typed);
  }

  String? _authToken;

  /// Connect to Socket.io server
  void connect(String userId, {String? authToken}) {
    if (_disposed) return;
    if (_isConnected && _currentUserId == userId) return;

    // If reconnecting as same user, clear old listeners first
    if (_socket != null) {
      _removeAllListeners();
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        debugPrint('[Socket] Cleanup error: $e');
      }
      _socket = null;
    }

    _currentUserId = userId;
    _authToken = authToken;

    _manualReconnectAttempts = 0;

    try {
      final optionsBuilder = IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)        // Start at 2s (less aggressive)
          .setReconnectionDelayMax(30000)     // Max 30s between retries (battery friendly)
          .setReconnectionAttempts(10)        // 10 auto-retries, then manual backoff
          .setQuery({'userId': userId});      // Send userId in handshake (backward compat)

      // Send JWT token in auth handshake for server-side verification
      if (_authToken != null && _authToken!.isNotEmpty) {
        optionsBuilder.setAuth({'token': _authToken!});
      }

      _socket = IO.io(
        NearfoConfig.wsUrl,
        optionsBuilder.build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[Socket] Connected: ${_socket?.id}');
        _isConnected = true;
        _manualReconnectAttempts = 0; // Reset on successful connect
        _reconnectTimer?.cancel();
        _socket?.emit('user_online', userId);
        // Join any active chat rooms (in case joinChat was called before connect)
        for (final chatId in _activeChats) {
          _socket?.emit('join_chat', chatId);
        }
        // Notify listeners (e.g. chat screen) so they can refresh missed messages
        if (!_reconnectedController.isClosed) {
          _reconnectedController.add(null);
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('[Socket] Disconnected');
        _isConnected = false;
        // Only attempt manual reconnect if app is in foreground
        if (!_isInBackground && !_disposed) {
          _scheduleManualReconnect();
        }
      });

      _socket!.onConnectError((error) {
        debugPrint('[Socket] Connection error: $error');
        _isConnected = false;
      });

      _socket!.on('reconnect', (_) {
        debugPrint('[Socket] Reconnected — re-registering listeners & re-announcing online');
        _isConnected = true;
        _manualReconnectAttempts = 0;
        _reconnectTimer?.cancel();
        // Remove old listeners and re-register to prevent duplicates
        _removeAllListeners();
        _registerEventListeners();
        _socket?.emit('user_online', userId);
        // Re-join all active chat rooms (room membership is lost on reconnect)
        for (final chatId in _activeChats) {
          debugPrint('[Socket] Re-joining chat room: $chatId');
          _socket?.emit('join_chat', chatId);
        }
        // Flush offline message queue on reconnect
        try {
          unawaited(OfflineMessageQueue.instance.processQueue());
        } catch (e) {
          debugPrint('[Socket] Queue flush on reconnect error: $e');
        }
      });

      _socket!.on('reconnect_failed', (_) {
        debugPrint('[Socket] Auto-reconnection failed — switching to manual backoff');
        _isConnected = false;
        if (!_isInBackground && !_disposed) {
          _scheduleManualReconnect();
        }
      });

      _registerEventListeners();
    } catch (e) {
      debugPrint('[Socket] Connect error: $e');
      _isConnected = false;
    }
  }

  /// Manual reconnect with exponential backoff + jitter (after auto-reconnect exhausted)
  void _scheduleManualReconnect() {
    if (_disposed || _isConnected || _isInBackground) return;
    if (_manualReconnectAttempts >= _maxManualReconnects) {
      debugPrint('[Socket] Max manual reconnect attempts reached — giving up until app resumes');
      return;
    }

    _reconnectTimer?.cancel();
    // Exponential backoff: 30s, 60s, 120s, 240s, 480s + random jitter
    final baseDelay = 30 * pow(2, _manualReconnectAttempts).toInt();
    final jitter = Random().nextInt(5); // 0-4s random jitter
    final delay = Duration(seconds: baseDelay + jitter);

    debugPrint('[Socket] Manual reconnect in ${delay.inSeconds}s (attempt ${_manualReconnectAttempts + 1}/$_maxManualReconnects)');
    _reconnectTimer = Timer(delay, () {
      if (!_disposed && !_isConnected && !_isInBackground && _currentUserId != null) {
        _manualReconnectAttempts++;
        debugPrint('[Socket] Attempting manual reconnect...');
        _socket?.connect();
      }
    });
  }

  /// Register all socket event listeners
  void _registerEventListeners() {
    if (_socket == null) return;

    _socket!.on('new_message', (data) => _safeEmitToStream(_newMessageController, data));
    _socket!.on('user_typing', (data) => _safeEmitToStream(_typingController, data));
    _socket!.on('user_stop_typing', (data) => _safeEmitToStream(_stopTypingController, data));
    _socket!.on('user_status', (data) => _safeEmitToStream(_userStatusController, data));
    _socket!.on('chat_update', (data) => _safeEmitToStream(_chatUpdateController, data));
    _socket!.on('new_notification', (data) => _safeEmitToStream(_newNotificationController, data));
    _socket!.on('messages_delivered', (data) => _safeEmitToStream(_messagesDeliveredController, data));
    _socket!.on('messages_read', (data) => _safeEmitToStream(_messagesReadController, data));
    _socket!.on('message_edited', (data) => _safeEmitToStream(_messageEditedController, data));
    _socket!.on('message_deleted', (data) => _safeEmitToStream(_messageDeletedController, data));
    _socket!.on('message_reaction', (data) => _safeEmitToStream(_messageReactionController, data));
    _socket!.on('message_reaction_removed', (data) => _safeEmitToStream(_messageReactionRemovedController, data));
    _socket!.on('user_blocked', (data) => _safeEmitToStream(_userBlockedController, data));
    _socket!.on('user_restricted', (data) => _safeEmitToStream(_userRestrictedController, data));

    _socket!.on('screenshot_taken', (data) {
      debugPrint('[Socket] Screenshot taken notification');
      _safeEmitToStream(_screenshotTakenController, data);
    });

    // ===== Live Streaming Listeners =====
    _socket!.on('live_comment', (data) => _safeEmitToStream(_liveCommentController, data));
    _socket!.on('live_like', (data) => _safeEmitToStream(_liveLikeController, data));
    _socket!.on('viewer_joined', (data) => _safeEmitToStream(_liveViewerJoinedController, data));
    _socket!.on('viewer_left', (data) => _safeEmitToStream(_liveViewerLeftController, data));
    _socket!.on('live_ended', (data) => _safeEmitToStream(_liveEndedController, data));
    _socket!.on('live_started', (data) => _safeEmitToStream(_liveStartedController, data));
    _socket!.on('live_offer', (data) => _safeEmitToStream(_liveOfferController, data));
    _socket!.on('live_answer', (data) => _safeEmitToStream(_liveAnswerController, data));
    _socket!.on('live_ice', (data) => _safeEmitToStream(_liveIceController, data));

    // ===== Call Signaling Listeners =====
    _socket!.on('incoming_call', (data) {
      debugPrint('[Socket] Incoming call');
      _safeEmitToStream(_incomingCallController, data);
    });

    _socket!.on('call_answered', (data) {
      debugPrint('[Socket] Call answered');
      _safeEmitToStream(_callAnsweredController, data);
    });

    _socket!.on('call_rejected', (data) {
      debugPrint('[Socket] Call rejected');
      _safeEmitToStream(_callRejectedController, data);
    });

    _socket!.on('call_ended', (data) {
      debugPrint('[Socket] Call ended');
      _safeEmitToStream(_callEndedController, data);
    });

    _socket!.on('ice_candidate', (data) => _safeEmitToStream(_iceCandidateController, data));

    _socket!.on('call_unavailable', (data) {
      debugPrint('[Socket] Call unavailable');
      _safeEmitToStream(_callUnavailableController, data);
    });
  }

  /// Remove all socket event listeners to prevent duplicates
  void _removeAllListeners() {
    if (_socket == null) return;
    try {
      _socket!.off('new_message');
      _socket!.off('user_typing');
      _socket!.off('user_stop_typing');
      _socket!.off('user_status');
      _socket!.off('chat_update');
      _socket!.off('new_notification');
      _socket!.off('messages_delivered');
      _socket!.off('messages_read');
      _socket!.off('message_edited');
      _socket!.off('message_deleted');
      _socket!.off('message_reaction');
      _socket!.off('message_reaction_removed');
      _socket!.off('user_blocked');
      _socket!.off('user_restricted');
      _socket!.off('screenshot_taken');
      _socket!.off('live_comment');
      _socket!.off('live_like');
      _socket!.off('viewer_joined');
      _socket!.off('viewer_left');
      _socket!.off('live_ended');
      _socket!.off('live_started');
      _socket!.off('live_offer');
      _socket!.off('live_answer');
      _socket!.off('live_ice');
      _socket!.off('incoming_call');
      _socket!.off('call_answered');
      _socket!.off('call_rejected');
      _socket!.off('call_ended');
      _socket!.off('ice_candidate');
      _socket!.off('call_unavailable');
      _socket!.off('reconnect');
      _socket!.off('reconnect_failed');
    } catch (e) {
      debugPrint('[Socket] Remove listeners error: $e');
    }
  }

  // ===== Connection helpers =====

  /// Ensure the socket is connected — call this before any critical emit.
  /// If disconnected, resets retry counters and triggers an immediate reconnect
  /// so callers (e.g. joinChat) don't silently emit into the void.
  void ensureConnected() {
    if (_disposed || _currentUserId == null) return;
    if (_isConnected) return;

    debugPrint('[Socket] ensureConnected — socket is disconnected, forcing reconnect');
    // Reset manual reconnect counter so we don't stay in "gave up" state
    _manualReconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _isInBackground = false; // treat as foreground since user is actively using the app

    if (_socket != null) {
      _socket!.connect();
    } else if (_currentUserId != null) {
      // Socket was disposed or never created — full reconnect
      connect(_currentUserId!, authToken: _authToken);
    }
  }

  // ===== Emit methods =====

  void joinChat(String chatId) {
    _activeChats.add(chatId);
    ensureConnected(); // Make sure socket is alive before joining
    _socket?.emit('join_chat', chatId);
  }

  void leaveChat(String chatId) {
    _activeChats.remove(chatId);
    _socket?.emit('leave_chat', chatId);
  }

  void sendMessage({required String chatId, required Map<String, dynamic> message}) {
    _socket?.emit('send_message', {'chatId': chatId, 'message': message});
  }

  void startTyping({required String chatId, required String userId, required String userName}) {
    _socket?.emit('typing', {'chatId': chatId, 'userId': userId, 'userName': userName});
  }

  void emitMessageDelivered({required String chatId, required List<String> messageIds, required String userId}) {
    _socket?.emit('message_delivered', {'chatId': chatId, 'messageIds': messageIds, 'userId': userId});
  }

  void emitMessagesRead({required String chatId, required String userId}) {
    _socket?.emit('messages_read', {'chatId': chatId, 'userId': userId});
  }

  void stopTyping({required String chatId, required String userId}) {
    _socket?.emit('stop_typing', {'chatId': chatId, 'userId': userId});
  }

  void addMessageReaction({required String chatId, required String messageId, required String emoji}) {
    _socket?.emit('add_reaction', {'chatId': chatId, 'messageId': messageId, 'emoji': emoji});
  }

  void removeMessageReaction({required String chatId, required String messageId}) {
    _socket?.emit('remove_reaction', {'chatId': chatId, 'messageId': messageId});
  }

  /// Toggle online visibility (ghost mode). When visible=false, user appears offline to everyone.
  void toggleOnlineVisibility({required String userId, required bool visible}) {
    _socket?.emit('toggle_online_visibility', {'userId': userId, 'visible': visible});
  }

  /// Emit screenshot taken event
  void emitScreenshotTaken({required String chatId, required String userId, required String userName, required String recipientId}) {
    _socket?.emit('screenshot_taken', {'chatId': chatId, 'userId': userId, 'userName': userName, 'recipientId': recipientId});
  }

  /// Generic emit for custom events
  void emit(String event, Map<String, dynamic> data) {
    if (_socket == null || !_isConnected) {
      debugPrint('[Socket] Cannot emit $event — socket not connected');
      return;
    }
    _socket!.emit(event, data);
  }

  // ===== Live Streaming Methods =====

  /// Join a live stream socket room
  void joinLiveStream(String streamId) {
    ensureConnected();
    _socket?.emit('live_join', streamId);
  }

  /// Leave a live stream socket room
  void leaveLiveStream(String streamId) {
    _socket?.emit('live_leave', streamId);
  }

  /// Send WebRTC offer (broadcaster -> all viewers in room)
  void sendLiveOffer({required String streamId, required Map<String, dynamic> offer}) {
    if (!_guardCall('sendLiveOffer')) return;
    _socket!.emit('live_offer', {'streamId': streamId, 'offer': offer});
  }

  /// Send WebRTC answer (viewer -> host)
  void sendLiveAnswer({required String hostId, required String viewerId, required Map<String, dynamic> answer}) {
    if (!_guardCall('sendLiveAnswer')) return;
    _socket!.emit('live_answer', {'hostId': hostId, 'viewerId': viewerId, 'answer': answer});
  }

  /// Send ICE candidate for live stream
  void sendLiveIce({String? targetId, String? streamId, required String senderId, required Map<String, dynamic> candidate}) {
    if (!_guardCall('sendLiveIce')) return;
    _socket!.emit('live_ice', {
      'targetId': targetId,
      'streamId': streamId,
      'senderId': senderId,
      'candidate': candidate,
    });
  }

  // ===== Call Signaling Methods =====
  bool _guardCall(String method) {
    if (_socket == null || !_isConnected) {
      debugPrint('[Socket] Cannot $method — socket not connected');
      return false;
    }
    return true;
  }

  void initiateCall({
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required String recipientId,
    required Map<String, dynamic> offer,
    required bool isVideo,
  }) {
    if (!_guardCall('initiateCall')) return;
    _socket!.emit('call_initiate', {
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar ?? '',
      'recipientId': recipientId,
      'offer': offer,
      'isVideo': isVideo,
    });
  }

  void answerCall({required String callerId, required Map<String, dynamic> answer}) {
    if (!_guardCall('answerCall')) return;
    _socket!.emit('call_answer', {'callerId': callerId, 'answer': answer});
  }

  void rejectCall({required String callerId}) {
    if (!_guardCall('rejectCall')) return;
    _socket!.emit('call_reject', {'callerId': callerId});
  }

  void endCall({required String recipientId}) {
    if (!_guardCall('endCall')) return;
    _socket!.emit('call_end', {'recipientId': recipientId});
  }

  void sendIceCandidate({required String recipientId, required Map<String, dynamic> candidate}) {
    if (!_guardCall('sendIceCandidate')) return;
    _socket!.emit('ice_candidate', {'recipientId': recipientId, 'candidate': candidate});
  }

  /// Disconnect and clean up
  void disconnect() {
    _reconnectTimer?.cancel();
    _backgroundDisconnectTimer?.cancel();
    _removeAllListeners();
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (e) {
      debugPrint('[Socket] Disconnect error: $e');
    }
    _socket = null;
    _isConnected = false;
    _currentUserId = null;
    _manualReconnectAttempts = 0;
    debugPrint('[Socket] Disconnected & disposed');
  }

  /// Dispose all stream controllers (call on app close)
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
    _newMessageController.close();
    _typingController.close();
    _stopTypingController.close();
    _userStatusController.close();
    _chatUpdateController.close();
    _messagesDeliveredController.close();
    _messagesReadController.close();
    _newNotificationController.close();
    _messageEditedController.close();
    _messageDeletedController.close();
    _messageReactionController.close();
    _messageReactionRemovedController.close();
    _screenshotTakenController.close();
    _userBlockedController.close();
    _userRestrictedController.close();
    _liveCommentController.close();
    _liveLikeController.close();
    _liveViewerJoinedController.close();
    _liveViewerLeftController.close();
    _liveEndedController.close();
    _liveStartedController.close();
    _liveOfferController.close();
    _liveAnswerController.close();
    _liveIceController.close();
    _incomingCallController.close();
    _callAnsweredController.close();
    _callRejectedController.close();
    _callEndedController.close();
    _iceCandidateController.close();
    _callUnavailableController.close();
    _reconnectedController.close();
    _instance = null;
  }
}
