import 'package:flutter/foundation.dart';
import 'package:nearfo_app/utils/json_helpers.dart';

class UserModel {
  final String id;
  final String firebaseUid;
  final String name;
  final String handle;
  final String phone;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String country;
  final int followers;
  final int following;
  final int postsCount;
  final int nearfoScore;
  final bool isVerified;
  final bool isOnline;
  final bool isPremium;
  final List<String> interests;
  final String feedPreference;
  final bool notificationsEnabled;
  final String profileVisibility;
  final bool isPrivateAccount;
  final List<String> closeFriends;
  final List<String> blockedUsers;
  final List<String> hiddenOnlineFromUsers;
  final bool crosspostingEnabled;
  final bool showActivityInFriendsTab;
  final String storyVisibility;
  final bool showLocationInStory;
  final bool allowStoryReplies;
  final bool liveNotificationsEnabled;
  final bool hideFollowersList;
  final bool showLikedPosts;
  final bool showComments;
  final bool showNewFollows;
  final DateTime? dateOfBirth;
  final bool showDobOnProfile;
  final bool showOnlineStatus;
  final bool showLastSeen;
  final DateTime? lastSeen;
  final DateTime createdAt;

  UserModel({
    required this.id,
    this.firebaseUid = '',
    required this.name,
    required this.handle,
    required this.phone,
    this.email,
    this.bio,
    this.avatarUrl,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
    this.country = 'India',
    this.followers = 0,
    this.following = 0,
    this.postsCount = 0,
    this.nearfoScore = 0,
    this.isVerified = false,
    this.isOnline = false,
    this.isPremium = false,
    this.interests = const [],
    this.feedPreference = 'mixed',
    this.notificationsEnabled = true,
    this.profileVisibility = 'public',
    this.isPrivateAccount = false,
    this.closeFriends = const [],
    this.blockedUsers = const [],
    this.hiddenOnlineFromUsers = const [],
    this.crosspostingEnabled = false,
    this.showActivityInFriendsTab = true,
    this.storyVisibility = 'everyone',
    this.showLocationInStory = true,
    this.allowStoryReplies = true,
    this.liveNotificationsEnabled = true,
    this.hideFollowersList = false,
    this.showLikedPosts = true,
    this.showComments = true,
    this.showNewFollows = true,
    this.dateOfBirth,
    this.showDobOnProfile = true,
    this.showOnlineStatus = true,
    this.showLastSeen = true,
    this.lastSeen,
    required this.createdAt,
  });

  /// Parse from backend API response — crash-safe with try-catch
  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel._parseJson(json);
    } catch (e, st) {
      debugPrint('[UserModel] fromJson error: $e\n$st');
      return UserModel._empty(json.asString('_id', json.asString('id', 'error')));
    }
  }

  /// Named constructor for empty/fallback user
  factory UserModel._empty(String id) => UserModel(
    id: id, name: 'Unknown', handle: '', phone: '',
    latitude: 0, longitude: 0, city: '', state: '', createdAt: DateTime.now(),
  );

  static UserModel _parseJson(Map<String, dynamic> json) {
    // Backend sends location as { type: 'Point', coordinates: [lng, lat] }
    double lat = 0.0;
    double lng = 0.0;
    final locMap = json.asMapOrNull('location');
    if (locMap != null && locMap['coordinates'] is List<dynamic>) {
      final coords = locMap['coordinates'] as List<dynamic>;
      if (coords.length >= 2) {
        lng = ((coords[0] as num?) ?? 0.0).toDouble();
        lat = ((coords[1] as num?) ?? 0.0).toDouble();
      }
    } else {
      lat = json.asDouble('latitude', 0.0);
      lng = json.asDouble('longitude', 0.0);
    }

    return UserModel(
      id: json.asString('_id', json.asString('id', '')),
      firebaseUid: json.asString('firebaseUid', ''),
      name: json.asString('name', ''),
      handle: json.asString('handle', ''),
      phone: json.asString('phone', ''),
      email: json.asStringOrNull('email'),
      bio: json.asStringOrNull('bio'),
      avatarUrl: json.asStringOrNull('avatarUrl'),
      latitude: lat,
      longitude: lng,
      city: json.asString('city', ''),
      state: json.asString('state', ''),
      country: json.asString('country', 'India'),
      followers: json.asInt('followersCount', json.asInt('followers', 0)),
      following: json.asInt('followingCount', json.asInt('following', 0)),
      postsCount: json.asInt('postsCount', 0),
      nearfoScore: json.asInt('nearfoScore', 0),
      isVerified: json.asBool('isVerified', false),
      isOnline: json.asBool('isOnline', false),
      isPremium: json.asBool('isPremium', false),
      interests: json.asStringList('interests'),
      feedPreference: json.asString('feedPreference', 'mixed'),
      notificationsEnabled: json.asBool('notificationsEnabled', true),
      profileVisibility: json.asString('profileVisibility', 'public'),
      isPrivateAccount: json.asBool('isPrivateAccount', false),
      closeFriends: json.asStringList('closeFriends'),
      blockedUsers: json.asStringList('blockedUsers'),
      hiddenOnlineFromUsers: json.asStringList('hiddenOnlineFromUsers'),
      crosspostingEnabled: json.asBool('crosspostingEnabled', false),
      showActivityInFriendsTab: json.asBool('showActivityInFriendsTab', true),
      storyVisibility: json.asString('storyVisibility', 'everyone'),
      showLocationInStory: json.asBool('showLocationInStory', true),
      allowStoryReplies: json.asBool('allowStoryReplies', true),
      liveNotificationsEnabled: json.asBool('liveNotificationsEnabled', true),
      hideFollowersList: json.asBool('hideFollowersList', false),
      showLikedPosts: json.asBool('showLikedPosts', true),
      showComments: json.asBool('showComments', true),
      showNewFollows: json.asBool('showNewFollows', true),
      dateOfBirth: json.asDateTimeOrNull('dateOfBirth'),
      showDobOnProfile: json.asBool('showDobOnProfile', true),
      showOnlineStatus: json.asBool('showOnlineStatus', true),
      showLastSeen: json.asBool('showLastSeen', true),
      lastSeen: json.asDateTimeOrNull('lastSeen'),
      createdAt: (json.asDateTimeOrNull('createdAt') ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'handle': handle,
    'phone': phone,
    'email': email,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'city': city,
    'state': state,
    'country': country,
    'interests': interests,
    'feedPreference': feedPreference,
    'notificationsEnabled': notificationsEnabled,
    'profileVisibility': profileVisibility,
    'isPrivateAccount': isPrivateAccount,
    'closeFriends': closeFriends,
    'blockedUsers': blockedUsers,
    'hiddenOnlineFromUsers': hiddenOnlineFromUsers,
    'crosspostingEnabled': crosspostingEnabled,
    'showActivityInFriendsTab': showActivityInFriendsTab,
    'storyVisibility': storyVisibility,
    'showLocationInStory': showLocationInStory,
    'allowStoryReplies': allowStoryReplies,
    'liveNotificationsEnabled': liveNotificationsEnabled,
    'hideFollowersList': hideFollowersList,
    'showLikedPosts': showLikedPosts,
    'showComments': showComments,
    'showNewFollows': showNewFollows,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'showDobOnProfile': showDobOnProfile,
    'showOnlineStatus': showOnlineStatus,
    'showLastSeen': showLastSeen,
  };

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int a = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) a--;
    return a;
  }

  String? get formattedDob {
    if (dateOfBirth == null) return null;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dateOfBirth!.day} ${months[dateOfBirth!.month - 1]} ${dateOfBirth!.year}';
  }

  String get displayLocation {
    if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
    if (city.isNotEmpty) return city;
    if (state.isNotEmpty) return state;
    return 'Unknown';
  }
}
