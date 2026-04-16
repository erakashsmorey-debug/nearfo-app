import 'package:flutter/foundation.dart';
import 'package:nearfo_app/utils/json_helpers.dart';

class ReelModel {
  final String id;
  final ReelAuthor author;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final List<String> hashtags;
  final String audioName;
  final int duration; // seconds
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final bool isLiked;
  final bool isBookmarked;
  final double distanceKm;
  final DateTime createdAt;

  ReelModel({
    required this.id,
    required this.author,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.caption = '',
    this.hashtags = const [],
    this.audioName = 'Original Audio',
    this.duration = 0,
    this.latitude = 0,
    this.longitude = 0,
    this.city = '',
    this.state = '',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.distanceKm = 0,
    required this.createdAt,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    try {
      return ReelModel._parseJson(json);
    } catch (e, st) {
      debugPrint('[ReelModel] fromJson error: $e\n$st');
      return ReelModel(
        id: json.asString('_id', json.asString('id', 'error')),
        author: ReelAuthor(id: '', name: 'Unknown', handle: ''),
        videoUrl: '', createdAt: DateTime.now(),
      );
    }
  }

  static ReelModel _parseJson(Map<String, dynamic> json) {
    final locMap = json.asMapOrNull('location');
    double lat = 0, lon = 0;
    if (locMap != null && locMap['coordinates'] is List<dynamic>) {
      final coords = locMap['coordinates'] as List<dynamic>;
      if (coords.length >= 2) {
        lon = ((coords[0] as num?) ?? 0).toDouble();
        lat = ((coords[1] as num?) ?? 0).toDouble();
      }
    }

    return ReelModel(
      id: json.asString('_id', json.asString('id', '')),
      author: ReelAuthor.fromJson(json.asMapOrNull('author') ?? {}),
      videoUrl: json.asString('videoUrl', ''),
      thumbnailUrl: json.asString('thumbnailUrl', ''),
      caption: json.asString('caption', ''),
      hashtags: json.asStringList('hashtags'),
      audioName: json.asString('audioName', 'Original Audio'),
      duration: json.asInt('duration', 0),
      latitude: lat,
      longitude: lon,
      city: json.asString('city', ''),
      state: json.asString('state', ''),
      likesCount: json.asInt('likesCount', 0),
      commentsCount: json.asInt('commentsCount', 0),
      sharesCount: json.asInt('sharesCount', 0),
      viewsCount: json.asInt('viewsCount', 0),
      isLiked: json.asBool('isLiked', false),
      isBookmarked: json.asBool('isBookmarked', false),
      distanceKm: json.asDouble('distanceKm', 0.0),
      createdAt: (json.asDateTimeOrNull('createdAt') ?? DateTime.now()),
    );
  }

  ReelModel copyWith({
    bool? isLiked,
    bool? isBookmarked,
    int? likesCount,
    int? viewsCount,
    int? commentsCount,
    int? sharesCount,
  }) {
    return ReelModel(
      id: id,
      author: author,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      hashtags: hashtags,
      audioName: audioName,
      duration: duration,
      latitude: latitude,
      longitude: longitude,
      city: city,
      state: state,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      distanceKm: distanceKm,
      createdAt: createdAt,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  String get formattedViews {
    if (viewsCount < 1000) return '$viewsCount';
    if (viewsCount < 1000000) return '${(viewsCount / 1000).toStringAsFixed(1)}K';
    return '${(viewsCount / 1000000).toStringAsFixed(1)}M';
  }

  String get formattedLikes {
    if (likesCount < 1000) return '$likesCount';
    if (likesCount < 1000000) return '${(likesCount / 1000).toStringAsFixed(1)}K';
    return '${(likesCount / 1000000).toStringAsFixed(1)}M';
  }

  String get authorName {
    return author.name;
  }
}

class ReelAuthor {
  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool isVerified;
  final String? city;
  final int nearfoScore;

  ReelAuthor({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
    this.isVerified = false,
    this.city,
    this.nearfoScore = 0,
  });

  factory ReelAuthor.fromJson(Map<String, dynamic> json) {
    return ReelAuthor(
      id: json.asString('_id', json.asString('id', '')),
      name: json.asString('name', 'Unknown'),
      handle: json.asString('handle', ''),
      avatarUrl: json.asStringOrNull('avatarUrl'),
      isVerified: json.asBool('isVerified', false),
      city: json.asStringOrNull('city'),
      nearfoScore: json.asInt('nearfoScore', 0),
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
