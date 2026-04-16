import 'package:flutter/foundation.dart';
import 'package:nearfo_app/utils/json_helpers.dart';

class ChatParticipant {
  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool isVerified;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatParticipant({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
    this.isVerified = false,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json.asString('_id', json.asString('id', '')),
      name: json.asString('name', ''),
      handle: json.asString('handle', ''),
      avatarUrl: json.asStringOrNull('avatarUrl'),
      isVerified: json.asBool('isVerified', false),
      isOnline: json.asBool('isOnline', false),
      lastSeen: json.asDateTimeOrNull('lastSeen'),
    );
  }

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Returns human-readable last seen text
  String get lastSeenText {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastSeen!.day}/${lastSeen!.month}/${lastSeen!.year}';
  }
}

class ChatModel {
  final String id;
  final List<ChatParticipant> participants;
  final bool isGroup;
  final String groupName;
  final String? groupAvatar;
  final String? groupDescription;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? lastMessageBy;
  final int unreadCount;
  final bool isEncrypted;

  ChatModel({
    required this.id,
    required this.participants,
    this.isGroup = false,
    this.groupName = '',
    this.groupAvatar,
    this.groupDescription,
    this.lastMessage = '',
    required this.lastMessageAt,
    this.lastMessageBy,
    this.unreadCount = 0,
    this.isEncrypted = true,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    try {
      return ChatModel(
        id: json.asString('_id', json.asString('id', '')),
        participants: json.asList('participants')
            .map((p) => p is Map<String, dynamic>
                ? ChatParticipant.fromJson(p)
                : ChatParticipant(id: p.toString(), name: '', handle: ''))
            .toList(),
        isGroup: json.asBool('isGroup', false),
        groupName: json.asString('groupName', ''),
        groupAvatar: json.asStringOrNull('groupAvatar'),
        groupDescription: json.asStringOrNull('groupDescription'),
        lastMessage: json.asString('lastMessage', ''),
        lastMessageAt: json.asDateTimeOrNull('lastMessageAt') ?? DateTime.now(),
        lastMessageBy: json.asStringOrNull('lastMessageBy'),
        unreadCount: json.asInt('unreadCount', 0),
        isEncrypted: json.asBool('isEncrypted', true),
      );
    } catch (e, st) {
      debugPrint('[ChatModel] fromJson error: $e\n$st');
      return ChatModel(
        id: json.asString('_id', json.asString('id', 'error')),
        participants: [], lastMessageAt: DateTime.now(),
      );
    }
  }

  /// Get the "other" participant in 1:1 chat
  ChatParticipant? otherParticipant(String myUserId) {
    if (isGroup) return null;
    try {
      return participants.firstWhere((p) => p.id != myUserId);
    } catch (_) {
      return participants.isNotEmpty ? participants.first : null;
    }
  }

  /// Display name (group name or other person's name)
  String displayName(String myUserId) {
    if (isGroup) return groupName;
    final other = otherParticipant(myUserId);
    return other?.name ?? 'Unknown';
  }

  /// Time text for chat list
  String get timeText {
    final now = DateTime.now();
    final diff = now.difference(lastMessageAt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${lastMessageAt.day}/${lastMessageAt.month}';
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final ChatParticipant? sender;
  final String senderId;
  final String content;
  final String type; // text, image, voice, location, system
  final String? mediaUrl;
  final List<String> readBy;
  final bool isDeleted;
  final bool isRestricted;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.chatId,
    this.sender,
    required this.senderId,
    this.content = '',
    this.type = 'text',
    this.mediaUrl,
    this.readBy = const [],
    this.isDeleted = false,
    this.isRestricted = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    try {
      ChatParticipant? senderObj;
      String senderId = '';
      final senderMap = json.asMapOrNull('sender');
      if (senderMap != null) {
        senderObj = ChatParticipant.fromJson(senderMap);
        senderId = senderObj.id;
      } else {
        senderId = json.asStringOrNull('sender') ?? '';
      }

      return MessageModel(
        id: json.asString('_id', json.asString('id', '')),
        chatId: json.asStringOrNull('chat') ?? '',
        sender: senderObj,
        senderId: senderId,
        content: json.asString('content', ''),
        type: json.asString('type', 'text'),
        mediaUrl: json.asStringOrNull('mediaUrl'),
        readBy: json.asStringList('readBy'),
        isDeleted: json.asBool('isDeleted', false),
        isRestricted: json.asBool('isRestricted', false),
        createdAt: json.asDateTimeOrNull('createdAt') ?? DateTime.now(),
      );
    } catch (e, st) {
      debugPrint('[MessageModel] fromJson error: $e\n$st');
      return MessageModel(
        id: json.asString('_id', json.asString('id', 'error')),
        chatId: '', senderId: '', createdAt: DateTime.now(),
      );
    }
  }

  bool isReadBy(String userId) => readBy.contains(userId);

  bool isMine(String myUserId) => senderId == myUserId;
}
