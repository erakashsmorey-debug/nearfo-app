import 'package:flutter/foundation.dart';
import 'package:nearfo_app/utils/json_helpers.dart';

class NotificationModel {
  final String id;
  final NotificationSender? sender;
  final String type; // 'like', 'comment', 'follow', 'mention', 'nearby'
  final String? postId;
  final String? postContent;
  final String? reelId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.sender,
    required this.type,
    this.postId,
    this.postContent,
    this.reelId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    try {
      final senderData = json.asMapOrNull('sender');
      NotificationSender? sender;
      if (senderData != null) {
        sender = NotificationSender.fromJson(senderData);
      }

      final postRaw = json['post'];
      String? postId;
      String? postContent;
      if (postRaw is Map<String, dynamic>) {
        postId = postRaw.asStringOrNull('_id') ?? postRaw.asStringOrNull('id');
        postContent = postRaw.asStringOrNull('content');
      } else if (postRaw is String) {
        postId = postRaw;
      }

      // Parse reel field (could be populated object or string ID)
      final reelRaw = json['reel'];
      String? reelId;
      if (reelRaw is Map<String, dynamic>) {
        reelId = reelRaw.asStringOrNull('_id') ?? reelRaw.asStringOrNull('id');
      } else if (reelRaw is String) {
        reelId = reelRaw;
      }

      return NotificationModel(
        id: json.asString('_id', json.asString('id', '')),
        sender: sender,
        type: json.asString('type', 'like'),
        postId: postId,
        postContent: postContent,
        reelId: reelId,
        isRead: json.asBool('isRead', false),
        createdAt: (json.asDateTimeOrNull('createdAt')?.toLocal() ?? DateTime.now()),
      );
    } catch (e, st) {
      debugPrint('[NotificationModel] fromJson error: $e\n$st');
      return NotificationModel(
        id: json.asString('_id', json.asString('id', 'error')),
        type: 'unknown', createdAt: DateTime.now(),
      );
    }
  }

  /// Whether this notification is about a reel (vs a post)
  bool get isReel => reelId != null && reelId!.isNotEmpty;

  String get message {
    final name = sender?.name ?? 'Someone';
    final contentType = isReel ? 'reel' : 'post';
    switch (type) {
      case 'like':
        return '$name liked your $contentType';
      case 'comment':
        return '$name commented on your $contentType';
      case 'follow':
        return '$name started following you';
      case 'mention':
        return '$name mentioned you in a $contentType';
      case 'nearby':
        return '$name is vibing nearby';
      default:
        return '$name interacted with your $contentType';
    }
  }

  String get icon {
    switch (type) {
      case 'like': return '❤️';
      case 'comment': return '💬';
      case 'follow': return '👤';
      case 'mention': return '@';
      case 'nearby': return '📍';
      default: return '🔔';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${createdAt.day}/${createdAt.month}';
  }

  /// Serialize back to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': sender?.toJson(),
      'type': type,
      'post': postId != null ? {'_id': postId, 'content': postContent} : null,
      'reel': reelId != null ? {'_id': reelId} : null,
      'isRead': isRead,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}

class NotificationSender {
  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool isVerified;

  NotificationSender({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
    this.isVerified = false,
  });

  factory NotificationSender.fromJson(Map<String, dynamic> json) {
    return NotificationSender(
      id: json.asString('_id', json.asString('id', '')),
      name: json.asString('name', 'Unknown'),
      handle: json.asString('handle', 'unknown'),
      avatarUrl: json.asStringOrNull('avatarUrl'),
      isVerified: json.asBool('isVerified', false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
    };
  }
}
