import 'package:flutter/foundation.dart';
import 'package:nearfo_app/utils/json_helpers.dart';

class PostModel {
  final String id;
  final PostAuthor author;
  final String content;
  final List<String> images;
  final String? video;
  final String? mood;
  final List<String> hashtags;
  final List<String> mentions;
  final String visibility;
  final double latitude;
  final double longitude;
  final String city;
  final String? state;
  final String feedType; // 'local' or 'global'
  final double distanceKm;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final double viralScore;
  final bool isLiked;
  final bool isBookmarked;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.author,
    required this.content,
    this.images = const [],
    this.video,
    this.mood,
    this.hashtags = const [],
    this.mentions = const [],
    this.visibility = 'public',
    required this.latitude,
    required this.longitude,
    required this.city,
    this.state,
    this.feedType = 'local',
    this.distanceKm = 0.0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.viralScore = 0.0,
    this.isLiked = false,
    this.isBookmarked = false,
    required this.createdAt,
  });

  /// Parse from backend API response — crash-safe with try-catch
  factory PostModel.fromJson(Map<String, dynamic> json) {
    try {
      return PostModel._parseJson(json);
    } catch (e, st) {
      debugPrint('[PostModel] fromJson error: $e\n$st');
      return PostModel(
        id: json.asString('_id', json.asString('id', 'error')),
        author: PostAuthor(id: '', name: 'Unknown', handle: 'unknown'),
        content: '', latitude: 0, longitude: 0, city: '', createdAt: DateTime.now(),
      );
    }
  }

  static PostModel _parseJson(Map<String, dynamic> json) {
    // Debug: trace raw images field to diagnose blank-image bug
    debugPrint('[PostModel] raw images field: ${json['images']}');

    // Backend populates author as object or returns plain string ID
    final authorRaw = json['author'];
    final PostAuthor author;
    if (authorRaw is Map<String, dynamic>) {
      author = PostAuthor.fromJson(authorRaw);
    } else {
      final authorId = authorRaw is String ? authorRaw : '';
      author = PostAuthor(id: authorId, name: 'Unknown', handle: 'unknown');
    }

    // Location
    double lat = 0.0, lng = 0.0;
    final locMap = json.asMapOrNull('location');
    if (locMap != null && locMap['coordinates'] is List<dynamic>) {
      final coords = locMap['coordinates'] as List<dynamic>;
      if (coords.length >= 2) {
        lng = ((coords[0] as num?) ?? 0.0).toDouble();
        lat = ((coords[1] as num?) ?? 0.0).toDouble();
      }
    }

    return PostModel(
      id: json.asString('_id', json.asString('id', '')),
      author: author,
      content: json.asString('content', ''),
      images: json.asUrlList('images'),
      video: json.asStringOrNull('video'),
      mood: json.asStringOrNull('mood'),
      hashtags: json.asStringList('hashtags'),
      mentions: json.asStringList('mentions'),
      visibility: json.asString('visibility', 'public'),
      latitude: lat,
      longitude: lng,
      city: json.asString('city', ''),
      state: json.asStringOrNull('state'),
      feedType: json.asString('feedType', 'local'),
      distanceKm: json.asDouble('distanceKm', 0.0),
      likesCount: json.asInt('likesCount', 0),
      commentsCount: json.asInt('commentsCount', 0),
      sharesCount: json.asInt('sharesCount', 0),
      viewsCount: json.asInt('viewsCount', 0),
      viralScore: json.asDouble('viralScore', 0.0),
      isLiked: json.asBool('isLiked', false),
      isBookmarked: json.asBool('isBookmarked', false),
      createdAt: (json.asDateTimeOrNull('createdAt')?.toLocal() ?? DateTime.now()),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get formattedDistance {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()}m';
    if (distanceKm < 100) return '${distanceKm.toStringAsFixed(1)}km';
    return '${distanceKm.round()}km';
  }

  /// Serialize back to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'author': author.toJson(),
      'content': content,
      'images': images,
      'video': video,
      'mood': mood,
      'hashtags': hashtags,
      'mentions': mentions,
      'visibility': visibility,
      'location': {
        'coordinates': [longitude, latitude],
      },
      'city': city,
      'state': state,
      'feedType': feedType,
      'distanceKm': distanceKm,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'viralScore': viralScore,
      'isLiked': isLiked,
      'isBookmarked': isBookmarked,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}

class PostAuthor {
  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool isVerified;
  final String? city;
  final int nearfoScore;

  PostAuthor({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
    this.isVerified = false,
    this.city,
    this.nearfoScore = 0,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json.asString('_id', json.asString('id', '')),
      name: json.asString('name', 'Unknown'),
      handle: json.asString('handle', 'unknown'),
      avatarUrl: json.asStringOrNull('avatarUrl'),
      isVerified: json.asBool('isVerified', false),
      city: json.asStringOrNull('city'),
      nearfoScore: json.asInt('nearfoScore', 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
      'city': city,
      'nearfoScore': nearfoScore,
    };
  }

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
