import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'connectivity_service.dart';
import 'api_service.dart';
import 'local_chat_storage.dart';

/// Message delivery status
enum MessageDeliveryStatus {
  pending,    // Created locally, not yet sent
  uploading,  // Media being uploaded
  sending,    // API call in progress
  sent,       // Server confirmed
  delivered,  // Recipient received
  read,       // Recipient read
  failed,     // Send failed (will retry)
}

/// A queued message waiting to be sent
class QueuedMessage {
  final String localId;       // UUID generated locally
  final String chatId;
  final String content;
  final String type;          // text, image, video, voice
  final String? localMediaPath;  // Local file path for media (before upload)
  String? mediaUrl;            // Remote URL after upload (mutable — set after upload)
  final Map<String, dynamic>? replyTo;
  final DateTime createdAt;
  MessageDeliveryStatus status;
  int retryCount;
  String? serverId;           // Server-assigned _id after successful send
  String? errorMessage;

  QueuedMessage({
    required this.localId,
    required this.chatId,
    required this.content,
    this.type = 'text',
    this.localMediaPath,
    this.mediaUrl,
    this.replyTo,
    required this.createdAt,
    this.status = MessageDeliveryStatus.pending,
    this.retryCount = 0,
    this.serverId,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'chatId': chatId,
    'content': content,
    'type': type,
    'localMediaPath': localMediaPath,
    'mediaUrl': mediaUrl,
    'replyTo': replyTo,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'retryCount': retryCount,
    'serverId': serverId,
    'errorMessage': errorMessage,
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      localId: (json['localId'] as String?) ?? '',
      chatId: (json['chatId'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'text',
      localMediaPath: json['localMediaPath'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      replyTo: json['replyTo'] is Map<String, dynamic> ? json['replyTo'] as Map<String, dynamic> : null,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      status: MessageDeliveryStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String?),
        orElse: () => MessageDeliveryStatus.pending,
      ),
      retryCount: (json['retryCount'] as int?) ?? 0,
      serverId: json['serverId'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Convert to a Map that looks like a server message (for display in chat)
  Map<String, dynamic> toDisplayMessage({String? senderId, Map<String, dynamic>? senderData}) {
    return {
      '_id': serverId ?? localId,
      '_localId': localId,
      '_localStatus': status.name,
      'chat': chatId,
      'sender': senderData ?? {'_id': senderId ?? ''},
      'content': content,
      'type': type,
      'mediaUrl': mediaUrl ?? localMediaPath,
      'readBy': <String>[],
      'isDeleted': false,
      'createdAt': createdAt.toIso8601String(),
      if (replyTo != null) 'replyTo': replyTo,
      if (errorMessage != null) '_errorMessage': errorMessage,
    };
  }
}

/// Offline message queue — persists unsent messages and processes them when online.
/// Singleton service.
class OfflineMessageQueue {
  static OfflineMessageQueue? _instance;
  static OfflineMessageQueue get instance => _instance ??= OfflineMessageQueue._();
  OfflineMessageQueue._();

  static const _boxName = 'offline_msg_queue';
  static const _maxRetries = 5;
  static const _uuid = Uuid();

  late Box<String> _box;
  bool _initialized = false;
  bool _isProcessing = false;
  Timer? _retryTimer;
  StreamSubscription? _connectivitySub;

  // Stream to notify UI of queue changes
  final _queueUpdateController = StreamController<QueuedMessage>.broadcast();
  Stream<QueuedMessage> get onQueueUpdate => _queueUpdateController.stream;

  /// Initialize — call once at app startup (after Hive.initFlutter)
  /// Graceful fail: if Hive can't open, queue degrades to in-memory only
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _box = await Hive.openBox<String>(_boxName);
    } catch (e) {
      debugPrint('[OfflineQueue] Hive open error — using empty fallback: $e');
      // Can't persist queue — messages won't survive app restart but won't crash either
      _box = await Hive.openBox<String>('${_boxName}_fallback_${DateTime.now().millisecondsSinceEpoch}');
    }
    debugPrint('[OfflineQueue] Initialized with ${_box.length} pending messages');

    // Listen for connectivity changes to auto-flush queue
    _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('[OfflineQueue] Network restored — flushing queue');
        unawaited(processQueue());
      }
    });

    // Process any leftover messages from previous session
    if (_box.isNotEmpty && ConnectivityService.instance.isOnline) {
      unawaited(Future.delayed(const Duration(seconds: 2), () => processQueue()));
    }
  }

  /// Enqueue a new message for sending.
  /// Returns a QueuedMessage with localId for immediate UI display.
  Future<QueuedMessage> enqueue({
    required String chatId,
    required String content,
    String type = 'text',
    String? localMediaPath,
    String? mediaUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    final msg = QueuedMessage(
      localId: _uuid.v4(),
      chatId: chatId,
      content: content,
      type: type,
      localMediaPath: localMediaPath,
      mediaUrl: mediaUrl,
      replyTo: replyTo,
      createdAt: DateTime.now(),
    );

    // Persist to Hive (graceful fail: if disk is full, message still shows in UI but won't survive restart)
    try {
      await _box.put(msg.localId, jsonEncode(msg.toJson()));
    } catch (e) {
      debugPrint('[OfflineQueue] Hive persist error (message in-memory only): $e');
    }
    debugPrint('[OfflineQueue] Enqueued message ${msg.localId} (type: $type, chat: $chatId)');

    // Notify UI
    _notifyUpdate(msg);

    // Try to send immediately if online
    if (ConnectivityService.instance.isOnline) {
      // Don't await — let it process in background
      unawaited(processQueue());
    }

    return msg;
  }

  /// Get all pending messages for a specific chat (for display)
  List<QueuedMessage> getPendingForChat(String chatId) {
    final pending = <QueuedMessage>[];
    for (final key in _box.keys) {
      final json = _box.get(key);
      if (json != null) {
        try {
          final msg = QueuedMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);
          if (msg.chatId == chatId && msg.status != MessageDeliveryStatus.sent) {
            pending.add(msg);
          }
        } catch (_) {}
      }
    }
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  /// Process all queued messages sequentially
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final keys = _box.keys.toList();
      for (final key in keys) {
        final json = _box.get(key as String);
        if (json == null) continue;

        try {
          final decoded = jsonDecode(json);
          if (decoded is! Map<String, dynamic>) {
            debugPrint('[OfflineQueue] Corrupted entry $key — removing');
            await _box.delete(key);
            continue;
          }
          final msg = QueuedMessage.fromJson(decoded);

          // Skip already sent messages (cleanup)
          if (msg.status == MessageDeliveryStatus.sent) {
            await _box.delete(key);
            continue;
          }

          // Skip messages that exceeded retry limit
          if (msg.retryCount >= _maxRetries) {
            msg.status = MessageDeliveryStatus.failed;
            msg.errorMessage = 'Max retries exceeded';
            await _box.put(key, jsonEncode(msg.toJson()));
            _notifyUpdate(msg);
            continue;
          }

          // Check connectivity before each send
          if (!ConnectivityService.instance.isOnline) {
            debugPrint('[OfflineQueue] Offline — pausing queue processing');
            break;
          }

          // Process this message
          await _processMessage(msg);
        } catch (e) {
          debugPrint('[OfflineQueue] Process error for key $key: $e');
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single queued message
  Future<void> _processMessage(QueuedMessage msg) async {
    debugPrint('[OfflineQueue] Processing ${msg.localId} (retry: ${msg.retryCount})');

    // Step 1: Upload media if needed
    String? mediaUrl = msg.mediaUrl;
    if (msg.type != 'text' && mediaUrl == null && msg.localMediaPath != null) {
      msg.status = MessageDeliveryStatus.uploading;
      _updateInBox(msg);
      _notifyUpdate(msg);

      try {
        if (msg.type == 'image') {
          final res = await ApiService.uploadImage(msg.localMediaPath!, folder: 'chat');
          if (res.isSuccess && res.data != null && res.data!.isNotEmpty) mediaUrl = res.data;
        } else if (msg.type == 'video') {
          final res = await ApiService.uploadVideo(msg.localMediaPath!, folder: 'chat');
          if (res.isSuccess && res.data != null && res.data!.isNotEmpty) mediaUrl = res.data;
        } else if (msg.type == 'voice') {
          final duration = int.tryParse(msg.content.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final res = await ApiService.uploadVoice(msg.localMediaPath!, duration: duration);
          if (res.isSuccess && res.data != null && res.data!.isNotEmpty) mediaUrl = res.data;
        }

        if (mediaUrl == null || mediaUrl.isEmpty) {
          debugPrint('[OfflineQueue] Upload returned empty/null URL for ${msg.type}');
          msg.retryCount++;
          msg.status = MessageDeliveryStatus.failed;
          msg.errorMessage = 'Upload failed — no URL returned';
          _updateInBox(msg);
          _notifyUpdate(msg);
          return;
        }
        debugPrint('[OfflineQueue] Upload success: mediaUrl=$mediaUrl');

        msg.mediaUrl = mediaUrl;
      } catch (e) {
        msg.retryCount++;
        msg.status = MessageDeliveryStatus.failed;
        msg.errorMessage = 'Upload error: $e';
        _updateInBox(msg);
        _notifyUpdate(msg);
        return;
      }
    }

    // Step 2: Send via API
    msg.status = MessageDeliveryStatus.sending;
    _updateInBox(msg);
    _notifyUpdate(msg);

    try {
      final res = await ApiService.sendMessage(
        chatId: msg.chatId,
        content: msg.content,
        type: msg.type,
        mediaUrl: mediaUrl,
        replyTo: msg.replyTo,
      );

      if (res.isSuccess && res.data != null) {
        final serverMsg = res.data!;
        final serverId = serverMsg['_id']?.toString() ?? '';

        msg.status = MessageDeliveryStatus.sent;
        msg.serverId = serverId;

        // Remove from queue FIRST to prevent duplicate sends on crash/restart
        await _box.delete(msg.localId);

        // Update local storage: replace local message with server version
        await LocalChatStorage.instance.updateMessage(msg.chatId, msg.localId, {
          ...serverMsg,
          '_localId': msg.localId,
          '_localStatus': 'sent',
        });

        // Notify UI AFTER queue deletion (prevents re-send race)
        _notifyUpdate(msg);
        debugPrint('[OfflineQueue] Message ${msg.localId} sent successfully (server: $serverId)');
      } else {
        msg.retryCount++;
        msg.status = MessageDeliveryStatus.failed;
        msg.errorMessage = res.errorMessage ?? 'Send failed';
        _updateInBox(msg);
        _notifyUpdate(msg);
        debugPrint('[OfflineQueue] Message ${msg.localId} send failed: ${msg.errorMessage}');
      }
    } catch (e) {
      msg.retryCount++;
      msg.status = MessageDeliveryStatus.failed;
      msg.errorMessage = 'Network error: $e';
      _updateInBox(msg);
      _notifyUpdate(msg);
    }
  }

  /// Retry a specific failed message
  Future<void> retryMessage(String localId) async {
    final json = _box.get(localId);
    if (json == null) return;

    final msg = QueuedMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);
    msg.retryCount = 0; // Reset retry count
    msg.status = MessageDeliveryStatus.pending;
    msg.errorMessage = null;
    _updateInBox(msg);
    _notifyUpdate(msg);

    if (ConnectivityService.instance.isOnline) {
      unawaited(processQueue());
    }
  }

  /// Remove a failed message from queue (user decided to discard)
  Future<void> removeMessage(String localId) async {
    // Look up chatId from the queued message before deleting
    final json = _box.get(localId);
    String chatId = '';
    if (json != null) {
      try {
        final msg = QueuedMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);
        chatId = msg.chatId;
      } catch (_) {}
    }
    await _box.delete(localId);
    if (chatId.isNotEmpty) {
      await LocalChatStorage.instance.deleteMessage(chatId, localId);
    }
  }

  /// Get queue size
  int get queueSize => _box.length;

  // ===== INTERNAL =====

  void _updateInBox(QueuedMessage msg) {
    try {
      _box.put(msg.localId, jsonEncode(msg.toJson()));
    } catch (e) {
      debugPrint('[OfflineQueue] _updateInBox error: $e');
    }
  }

  void _notifyUpdate(QueuedMessage msg) {
    try {
      if (!_queueUpdateController.isClosed) {
        _queueUpdateController.add(msg);
      }
    } catch (_) {}
  }

  void dispose() {
    _retryTimer?.cancel();
    _connectivitySub?.cancel();
    _queueUpdateController.close();
    _instance = null;
  }
}
