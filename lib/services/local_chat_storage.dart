import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local chat message storage using Hive.
/// Stores messages per chat for offline access and instant display.
/// Each chat has its own Hive box: 'chat_msgs_<chatId>'
class LocalChatStorage {
  static LocalChatStorage? _instance;
  static LocalChatStorage get instance => _instance ??= LocalChatStorage._();
  LocalChatStorage._();

  bool _initialized = false;
  Completer<void>? _initCompleter; // Prevents concurrent init
  late Box<String> _metaBox; // Stores chat metadata (last sync timestamp, etc.)

  /// Initialize Hive — call once at app startup
  Future<void> init() async {
    if (_initialized) return;
    // Prevent concurrent init calls — second caller awaits the first
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      await Hive.initFlutter();
      _metaBox = await Hive.openBox<String>('chat_meta');
      _initialized = true;
      debugPrint('[LocalChatStorage] Initialized');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('[LocalChatStorage] Init error: $e');
      _initCompleter!.completeError(e);
      // Don't reset _initCompleter — concurrent callers awaiting it will
      // get the error. Reset only _initialized flag so next call can retry
      // after all current awaiters have seen the error.
      Future.microtask(() => _initCompleter = null);
      rethrow;
    }
  }

  /// Prevents concurrent openBox calls for the same boxName
  final Map<String, Future<Box<String>>> _openingBoxes = {};

  /// Get or open a chat's message box.
  /// Uses a lock map to prevent TOCTOU race where two concurrent calls
  /// both see isBoxOpen==false and both call openBox simultaneously.
  Future<Box<String>> _chatBox(String chatId) async {
    final boxName = 'chat_msgs_${_sanitizeId(chatId)}';
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<String>(boxName);
      }
      // If another call is already opening this box, await the same future
      if (_openingBoxes.containsKey(boxName)) {
        return await _openingBoxes[boxName]!;
      }
      final future = Hive.openBox<String>(boxName);
      _openingBoxes[boxName] = future;
      try {
        final box = await future;
        return box;
      } finally {
        _openingBoxes.remove(boxName);
      }
    } catch (e) {
      debugPrint('[LocalChatStorage] _chatBox error for $chatId: $e');
      _openingBoxes.remove(boxName);
      // Try a clean open with a different name as last resort
      final fallbackName = '${boxName}_${DateTime.now().millisecondsSinceEpoch}';
      return await Hive.openBox<String>(fallbackName);
    }
  }

  /// Sanitize chat ID for use as Hive box name (only lowercase alphanumeric + underscore)
  String _sanitizeId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
  }

  // ===== MESSAGE STORAGE =====

  /// Save a single message to local storage
  Future<void> saveMessage(String chatId, Map<String, dynamic> message) async {
    try {
      final box = await _chatBox(chatId);
      final msgId = _getMessageId(message);
      if (msgId.isEmpty) return;
      await box.put(msgId, jsonEncode(message));
    } catch (e) {
      debugPrint('[LocalChatStorage] saveMessage error: $e');
    }
  }

  /// Save multiple messages in batch (efficient for initial load)
  Future<void> saveMessages(String chatId, List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return;
    try {
      final box = await _chatBox(chatId);
      final entries = <String, String>{};
      for (final msg in messages) {
        final msgId = _getMessageId(msg);
        if (msgId.isNotEmpty) {
          entries[msgId] = jsonEncode(msg);
        }
      }
      await box.putAll(entries);
      debugPrint('[LocalChatStorage] Saved ${entries.length} messages for chat $chatId');
    } catch (e) {
      debugPrint('[LocalChatStorage] saveMessages error: $e');
    }
  }

  /// Get all locally stored messages for a chat, sorted by createdAt
  Future<List<Map<String, dynamic>>> getMessages(String chatId, {int? limit}) async {
    try {
      final box = await _chatBox(chatId);
      final messages = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        final json = box.get(key);
        if (json != null) {
          try {
            final msg = jsonDecode(json) as Map<String, dynamic>;
            messages.add(msg);
          } catch (_) {}
        }
      }

      // Sort by createdAt ascending (oldest first — matches chat display order)
      messages.sort((a, b) {
        final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });

      if (limit != null && messages.length > limit) {
        return messages.sublist(messages.length - limit);
      }
      return messages;
    } catch (e) {
      debugPrint('[LocalChatStorage] getMessages error: $e');
      return [];
    }
  }

  /// Update a specific message (e.g., when pending message gets server _id)
  Future<void> updateMessage(String chatId, String oldId, Map<String, dynamic> updatedMessage) async {
    try {
      final box = await _chatBox(chatId);
      // Remove old entry
      await box.delete(oldId);
      // Save with new ID
      final newId = _getMessageId(updatedMessage);
      if (newId.isNotEmpty) {
        await box.put(newId, jsonEncode(updatedMessage));
      }
    } catch (e) {
      debugPrint('[LocalChatStorage] updateMessage error: $e');
    }
  }

  /// Delete a specific message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final box = await _chatBox(chatId);
      await box.delete(messageId);
    } catch (e) {
      debugPrint('[LocalChatStorage] deleteMessage error: $e');
    }
  }

  /// Update message status field
  Future<void> updateMessageStatus(String chatId, String messageId, String status) async {
    try {
      final box = await _chatBox(chatId);
      final json = box.get(messageId);
      if (json != null) {
        final msg = jsonDecode(json) as Map<String, dynamic>;
        msg['_localStatus'] = status;
        await box.put(messageId, jsonEncode(msg));
      }
    } catch (e) {
      debugPrint('[LocalChatStorage] updateMessageStatus error: $e');
    }
  }

  /// Clear all messages for a chat
  Future<void> clearChat(String chatId) async {
    try {
      final box = await _chatBox(chatId);
      await box.clear();
    } catch (e) {
      debugPrint('[LocalChatStorage] clearChat error: $e');
    }
  }

  // ===== SYNC METADATA =====

  /// Store last sync timestamp for a chat
  Future<void> setLastSync(String chatId, DateTime timestamp) async {
    try {
      await _metaBox.put('last_sync_$chatId', timestamp.toIso8601String());
    } catch (e) {
      debugPrint('[LocalChatStorage] setLastSync error: $e');
    }
  }

  /// Get last sync timestamp for a chat
  DateTime? getLastSync(String chatId) {
    try {
      final ts = _metaBox.get('last_sync_$chatId');
      return ts != null ? DateTime.tryParse(ts) : null;
    } catch (_) {
      return null;
    }
  }

  // ===== HELPERS =====

  String _getMessageId(Map<String, dynamic> msg) {
    // Prefer server _id, fall back to local _localId
    return msg['_id']?.toString() ??
        msg['id']?.toString() ??
        msg['_localId']?.toString() ??
        '';
  }

  /// Close all open boxes
  Future<void> close() async {
    try {
      await Hive.close();
    } catch (e) {
      debugPrint('[LocalChatStorage] close error: $e');
    }
    _instance = null;
  }
}
