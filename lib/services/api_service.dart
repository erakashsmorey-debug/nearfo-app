import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import '../utils/json_helpers.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/notification_model.dart';
import '../models/reel_model.dart';
import 'location_service.dart';
import 'dart:async';

class ApiService {
  static const String _baseUrl = NearfoConfig.apiBaseUrl;
  static String? _authToken;
  static const Duration _timeout = Duration(seconds: 30);

  /// Metered.ca TURN API key for direct client fallback
  static const String _meteredApiKey = NearfoConfig.meteredTurnApiKey;

  /// Get correct MediaType from file extension for multipart uploads
  static MediaType _getMediaType(String filePath) {
    final parts = filePath.split('.');
    final ext = parts.length > 1 ? parts.last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
      case 'heif':
        return MediaType('image', 'heic');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mov':
        return MediaType('video', 'quicktime');
      case '3gp':
      case '3gpp':
        return MediaType('video', '3gpp');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      case 'wav':
        return MediaType('audio', 'wav');
      case 'ogg':
        return MediaType('audio', 'ogg');
      case 'aac':
      case 'm4a':
        return MediaType('audio', 'mp4');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  // ===== TOKEN MANAGEMENT (Encrypted via flutter_secure_storage) =====

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static String? _refreshToken;
  static bool _isRefreshing = false;
  static Completer<bool>? _refreshCompleter;

  static Future<void> loadToken() async {
    try {
      _authToken = await _secureStorage.read(key: _tokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      // Fallback: migrate from old SharedPreferences if secure storage fails
      debugPrint('[ApiService] Secure storage read failed, trying migration: $e');
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('auth_token');
      if (oldToken != null && oldToken.isNotEmpty) {
        _authToken = oldToken;
        // Migrate to secure storage
        try {
          await _secureStorage.write(key: _tokenKey, value: oldToken);
          await prefs.remove('auth_token'); // Remove from insecure storage
          debugPrint('[ApiService] Token migrated to secure storage');
        } catch (e) {
          debugPrint('[ApiService] Token migration failed: $e');
        }
      }
    }
  }

  static Future<void> saveToken(String token) async {
    _authToken = token;
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint('[ApiService] Secure storage write failed: $e');
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
  }

  static Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      debugPrint('[ApiService] Refresh token save failed: $e');
    }
  }

  static Future<void> clearToken() async {
    _authToken = null;
    _refreshToken = null;
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('[ApiService] Secure storage delete failed: $e');
    }
    // Also clear from SharedPreferences (in case of old data)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static String? get refreshToken => _refreshToken;
  static String? get accessToken => _authToken;
  static bool get isLoggedIn => _authToken != null && _authToken!.isNotEmpty;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null && _authToken!.isNotEmpty) 'Authorization': 'Bearer $_authToken',
  };

  /// Callback to trigger logout when token expires (set by AuthProvider)
  static void Function()? onSessionExpired;

  /// Safely decode JSON from HTTP response, checking for 401 first
  static Map<String, dynamic> _decodeResponse(http.Response res) {
    // Detect token expiry
    if (res.statusCode == 401 || res.statusCode == 403) {
      onSessionExpired?.call();
      throw Exception('Session expired. Please login again.');
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid server response (status ${res.statusCode})');
    }
  }

  /// Attempt to refresh the access token using the stored refresh token.
  /// Returns true if refresh succeeded, false otherwise.
  static Future<bool> tryRefreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      debugPrint('[ApiService] No refresh token available');
      return false;
    }

    // If another request is already refreshing, wait for it
    if (_isRefreshing && _refreshCompleter != null) {
      debugPrint('[ApiService] Waiting for ongoing token refresh...');
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      debugPrint('[ApiService] Refreshing access token...');
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(res.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : (decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{});

      if (res.statusCode == 200 && data['success'] == true) {
        await saveToken(data.asString('token'));
        await saveRefreshToken(data.asString('refreshToken'));
        debugPrint('[ApiService] Token refreshed successfully');
        _refreshCompleter?.complete(true);
        return true;
      } else {
        debugPrint('[ApiService] Token refresh failed: ${data.asStringOrNull('message')}');
        _refreshCompleter?.complete(false);
        return false;
      }
    } catch (e) {
      debugPrint('[ApiService] Token refresh error: $e');
      _refreshCompleter?.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }


  // ===== AUTH ENDPOINTS =====

  /// POST /api/auth/send-otp — Send OTP to phone number
  static Future<ApiResponse<String>> sendOTP({required String phone}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      ).timeout(_timeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        // In dev mode, server returns OTP for testing
        final otp = data.asStringOrNull('otp');
        return ApiResponse.success(otp ?? 'sent');
      }
      return ApiResponse.error(data.asString('message', 'Failed to send OTP'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/auth/verify-otp — Verify OTP and login/register
  static Future<ApiResponse<UserModel>> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      ).timeout(_timeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        await saveToken(data.asString('token'));
        if (data['refreshToken'] != null) {
          await saveRefreshToken(data.asString('refreshToken'));
        }
        return ApiResponse.success(
          UserModel.fromJson(data.asMap('user')),
          isNewUser: data.asBool('isNewUser'),
        );
      }
      return ApiResponse.error(data.asString('message', 'Verification failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/auth/firebase-login — Verify Firebase ID token and login/register
  static Future<ApiResponse<UserModel>> verifyFirebaseToken({
    required String idToken,
    String? phone,
    String? email,
    String? displayName,
    String? photoUrl,
    String? provider,
  }) async {
    try {
      final body = <String, dynamic>{'idToken': idToken};
      if (phone != null) body['phone'] = phone;
      if (email != null) body['email'] = email;
      if (displayName != null) body['displayName'] = displayName;
      if (photoUrl != null) body['photoUrl'] = photoUrl;
      if (provider != null) body['provider'] = provider;

      final res = await http.post(
        Uri.parse('$_baseUrl/auth/firebase-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        await saveToken(data.asString('token'));
        if (data['refreshToken'] != null) {
          await saveRefreshToken(data.asString('refreshToken'));
        }
        return ApiResponse.success(
          UserModel.fromJson(data.asMap('user')),
          isNewUser: data.asBool('isNewUser'),
        );
      }
      return ApiResponse.error(data.asString('message', 'Login failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/auth/verify-phone (legacy Firebase method)
  static Future<ApiResponse<UserModel>> verifyPhone({
    required String firebaseToken,
    required String phone,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/verify-phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebaseToken': firebaseToken,
          'phone': phone,
        }),
      ).timeout(_timeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        await saveToken(data.asString('token'));
        if (data['refreshToken'] != null) {
          await saveRefreshToken(data.asString('refreshToken'));
        }
        return ApiResponse.success(
          UserModel.fromJson(data.asMap('user')),
          isNewUser: data.asBool('isNewUser'),
        );
      }
      return ApiResponse.error(data.asString('message', 'Verification failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/auth/logout — Logout and revoke refresh token on backend
  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: _headers,
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[ApiService] Logout API call failed: $e');
    }
  }

  /// PUT /api/auth/setup-profile
  static Future<ApiResponse<UserModel>> setupProfile({
    required String name,
    required String handle,
    String? bio,
    String? avatarUrl,
    required double latitude,
    required double longitude,
    required String city,
    required String state,
    DateTime? dateOfBirth,
    bool showDobOnProfile = true,
  }) async {
    try {
      final body = <String, dynamic>{
          'name': name,
          'handle': handle,
          'bio': bio ?? '',
          'avatarUrl': avatarUrl ?? '',
          'latitude': latitude,
          'longitude': longitude,
          'city': city,
          'state': state,
          'showDobOnProfile': showDobOnProfile,
      };
      if (dateOfBirth != null) {
        // Send date in multiple formats for maximum backend compatibility
        // ISO date-only (YYYY-MM-DD) — most common backend expectation
        body['dateOfBirth'] = '${dateOfBirth.year}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}';
      }
      debugPrint('[ApiService] setupProfile body: $body');
      final res = await http.put(
        Uri.parse('$_baseUrl/auth/setup-profile'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(UserModel.fromJson(data.asMap('user')));
      }
      debugPrint('[ApiService] setupProfile failed: ${data.asString('message')} | errors: ${data['errors']}');
      // Show detailed validation errors if available
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final details = errors.map((e) => e is Map ? (e['msg'] ?? e['message'] ?? e.toString()) : e.toString()).join(', ');
        return ApiResponse.error(details);
      }
      return ApiResponse.error(data.asString('message', 'Profile setup failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/auth/me
  static Future<ApiResponse<UserModel>> getMe() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['user'] != null) {
        return ApiResponse.success(UserModel.fromJson(data.asMap('user')));
      }
      return ApiResponse.error(data.asString('message', 'Failed to get user'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/auth/analytics
  static Future<ApiResponse<Map<String, dynamic>>> getAnalytics() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/auth/analytics'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['analytics'] != null) {
        final a = Map<String, dynamic>.from(data.asMap('analytics'));
        // Flatten nested structure for easy screen consumption
        final posts = (a['posts'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final reels = (a['reels'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final weekly = (a['weekly'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final flat = <String, dynamic>{
          'totalPosts': posts['totalPosts'] ?? a['totalPosts'] ?? 0,
          'totalReels': reels['totalReels'] ?? a['totalReels'] ?? 0,
          'followersCount': a['followers'] ?? a['followersCount'] ?? 0,
          'followingCount': a['following'] ?? a['followingCount'] ?? 0,
          'totalLikes': (posts['totalLikes'] ?? 0) + (reels['totalLikes'] ?? 0),
          'totalReelViews': reels['totalViews'] ?? a['totalReelViews'] ?? 0,
          'totalComments': (posts['totalComments'] ?? 0) + (reels['totalComments'] ?? 0),
          'engagementRate': a['engagementRate'] ?? 0,
          'postsThisWeek': weekly['posts'] ?? a['postsThisWeek'] ?? 0,
          'reelsThisWeek': weekly['reels'] ?? a['reelsThisWeek'] ?? 0,
          'recentFollowers': weekly['newFollowers'] ?? a['recentFollowers'] ?? 0,
          'nearfoScore': a['nearfoScore'] ?? 0,
        };
        return ApiResponse.success(flat);
      }
      return ApiResponse.error(data.asString('message', 'Failed to get analytics'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// PUT /api/auth/update-profile
  static Future<ApiResponse<UserModel>> updateProfile(Map<String, dynamic> fields) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/auth/update-profile'),
        headers: _headers,
        body: jsonEncode(fields),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(UserModel.fromJson(data.asMap('user')));
      }
      return ApiResponse.error(data.asString('message', 'Profile update failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/auth/update-location
  static Future<ApiResponse<UserModel>> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/update-location'),
        headers: _headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(UserModel.fromJson(data.asMap('user')));
      }
      return ApiResponse.error(data.asString('message', 'Location update failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== FEED / POSTS =====

  /// GET /api/posts/feed — supports both page-based and cursor-based pagination
  static Future<FeedResponse> getFeed({
    String mode = 'mixed',
    int page = 1,
    int limit = 20,
    String? cursor,
    double? radiusKm,
  }) async {
    try {
      final radius = radiusKm ?? LocationService.nearfoRadiusKm;
      String url = '$_baseUrl/posts/feed?mode=$mode&limit=$limit&radius=${radius.round()}';
      if (cursor != null) {
        url += '&cursor=$cursor';
      } else {
        url += '&page=$page';
      }
      final res = await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['posts'] is List) {
        final posts = (data.asListOrNull('posts') ?? [])
            .map((p) => PostModel.fromJson(p as Map<String, dynamic>))
            .toList();
        return FeedResponse(
          posts: posts,
          hasMore: data.asBool('hasMore'),
          nextCursor: data.asStringOrNull('nextCursor'),
        );
      }
      return FeedResponse(posts: [], hasMore: false, error: data.asString('message', 'Failed to load feed'));
    } on TimeoutException {
      return FeedResponse(posts: [], hasMore: false, error: 'Request timed out.');
    } catch (e) {
      return FeedResponse(posts: [], hasMore: false, error: 'Network error: $e');
    }
  }

  /// Upload a single video via server-side multipart (like image upload)
  static Future<ApiResponse<String>> uploadVideo(String filePath, {String folder = 'videos'}) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final fileSizeMB = await File(filePath).length() / (1024 * 1024);
        // Dynamic timeout: 120s base + 30s per MB (min 120s, max 600s)
        final timeoutSecs = (120 + (fileSizeMB * 30)).clamp(120, 600).toInt();
        debugPrint('[ApiService] uploadVideo: ${fileSizeMB.toStringAsFixed(1)}MB, timeout: ${timeoutSecs}s, folder=$folder, attempt=${attempt + 1}');

        final uri = Uri.parse('$_baseUrl/upload/video?folder=$folder');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${_authToken ?? ''}';
        request.files.add(await http.MultipartFile.fromPath('video', filePath, contentType: _getMediaType(filePath)));

        final streamedResponse = await request.send().timeout(Duration(seconds: timeoutSecs));

        // Handle 401/403 — try token refresh on first attempt
        if ((streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) && attempt == 0) {
          debugPrint('[ApiService] uploadVideo: token expired, refreshing...');
          final refreshed = await tryRefreshToken();
          if (refreshed) continue; // Retry with new token
          onSessionExpired?.call();
          return ApiResponse.error('Session expired. Please login again.');
        }

        final responseBody = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        if (data['success'] == true) {
          final url = data['url']?.toString() ?? '';
          debugPrint('[ApiService] uploadVideo success: url=$url');
          if (url.isEmpty) {
            return ApiResponse.error('Upload succeeded but no URL returned');
          }
          return ApiResponse.success(url);
        }
        debugPrint('[ApiService] uploadVideo failed: $responseBody');
        return ApiResponse.error(data.asString('message', 'Video upload failed'));
      } on TimeoutException {
        return ApiResponse.error('Upload timed out. Please try again.');
      } catch (e) {
        debugPrint('[ApiService] uploadVideo error: $e');
        return ApiResponse.error('Upload error: $e');
      }
    }
    return ApiResponse.error('Video upload failed after retries');
  }

  /// POST /api/posts
  static Future<ApiResponse<PostModel>> createPost({
    required String content,
    List<String>? images,
    String? video,
    String? mood,
    List<String>? hashtags,
    String visibility = 'public',
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
        'visibility': visibility,
      };
      // Only include optional fields when they have real values
      if (images != null && images.isNotEmpty) {
        body['images'] = images;
      }
      if (video != null && video.isNotEmpty) {
        body['video'] = video;
      }
      if (mood != null && mood.isNotEmpty) {
        body['mood'] = mood;
      }
      if (hashtags != null && hashtags.isNotEmpty) {
        body['hashtags'] = hashtags;
      }

      debugPrint('[API] createPost body: ${jsonEncode(body)}');

      final res = await http.post(
        Uri.parse('$_baseUrl/posts'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      debugPrint('[API] createPost response images: ${data.asMap('post')['images']}');
      if (data['success'] == true) {
        return ApiResponse.success(PostModel.fromJson(data.asMap('post')));
      }
      final errMsg = data.asString('message', 'Failed to create post');
      // Parse detailed backend validation errors
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final details = errors
            .map((e) => e is Map
                ? (e['msg'] ?? e['message'] ?? e.toString())
                : e.toString())
            .join(', ');
        return ApiResponse.error('$errMsg: $details');
      }
      return ApiResponse.error(errMsg);
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/posts/:id/like (toggle)
  static Future<ApiResponse<Map<String, dynamic>>> toggleLike(String postId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/posts/$postId/like'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'isLiked': data.asBool('isLiked'),
          'likesCount': data.asInt('likesCount'),
        });
      }
      return ApiResponse.error(data.asString('message', 'Like failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// DELETE /api/posts/:id
  static Future<ApiResponse<void>> deletePost(String postId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/posts/$postId'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(null);
      }
      return ApiResponse.error(data.asString('message', 'Delete failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/posts/trending/hashtags
  static Future<ApiResponse<List<Map<String, dynamic>>>> getTrendingHashtags() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/posts/trending/hashtags'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['trending'] is List) {
        final trending = (data.asListOrNull('trending') ?? [])
            .map((t) => Map<String, dynamic>.from(t as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(trending);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load trending'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/posts/trending/posts — Get viral/trending posts
  static Future<ApiResponse<List<PostModel>>> getTrendingPosts({
    int page = 1,
    int limit = 20,
    String timeWindow = '24h',
    String scope = 'all',
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/posts/trending/posts?page=$page&limit=$limit&timeWindow=$timeWindow&scope=$scope&radius=${LocationService.nearfoRadiusKm.round()}'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['posts'] is List) {
        final posts = (data.asListOrNull('posts') ?? [])
            .map((p) => PostModel.fromJson(p as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(posts, hasMore: data.asBool('hasMore'));
      }
      return ApiResponse.error(data.asString('message', 'Failed to load trending posts'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/posts/:id/view — Record a post view
  static Future<ApiResponse<Map<String, dynamic>>> recordPostView(String postId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/posts/$postId/view'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data.asString('message', 'Failed to record view'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/posts/:id/share — Record a post share
  static Future<ApiResponse<Map<String, dynamic>>> recordPostShare(String postId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/posts/$postId/share'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data.asString('message', 'Failed to record share'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== COMMENTS =====

  /// GET /api/comments/:contentId — Get comments for a post or reel
  static Future<ApiResponse<List<Map<String, dynamic>>>> getComments(String contentId, {bool isReel = false}) async {
    try {
      final type = isReel ? 'reel' : 'post';
      final res = await http.get(
        Uri.parse('$_baseUrl/comments/$contentId?type=$type'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final comments = (data.asListOrNull('comments') ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(comments);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load comments'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/comments — Add a comment to a post or reel
  static Future<ApiResponse<Map<String, dynamic>>> addComment({
    required String contentId,
    required String content,
    bool isReel = false,
    String? parentComment,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
        if (parentComment != null) 'parentComment': parentComment,
      };
      if (isReel) {
        body['reelId'] = contentId;
      } else {
        body['postId'] = contentId;
      }
      final res = await http.post(
        Uri.parse('$_baseUrl/comments'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(Map<String, dynamic>.from(data.asMap('comment')));
      }
      return ApiResponse.error(data.asString('message', 'Failed to add comment'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/comments/:id/like — Toggle like on a comment
  static Future<ApiResponse<Map<String, dynamic>>> toggleCommentLike(String commentId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/comments/$commentId/like'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'isLiked': data.asBool('isLiked'),
          'likesCount': data.asInt('likesCount'),
        });
      }
      return ApiResponse.error(data.asString('message', 'Like failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/comments/:contentId/replies/:commentId — Get replies for a comment
  static Future<ApiResponse<List<Map<String, dynamic>>>> getCommentReplies(String contentId, String commentId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/comments/$contentId/replies/$commentId'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final replies = (data.asListOrNull('replies') ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(replies);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load replies'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== CHAT =====

  /// POST /api/chat — Create or get existing 1:1 chat
  static Future<ApiResponse<Map<String, dynamic>>> createOrGetChat(String participantId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: _headers,
        body: jsonEncode({'participantId': participantId}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(Map<String, dynamic>.from(data.asMap('chat')));
      }
      return ApiResponse.error(data.asString('message', 'Failed to create chat'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/chat — Get all user's chats
  static Future<ApiResponse<List<Map<String, dynamic>>>> getChats({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat?page=$page&limit=$limit'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final chats = (data.asListOrNull('chats') ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(chats);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load chats'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/chat/:chatId/messages
  static Future<ApiResponse<Map<String, dynamic>>> getChatMessages(
    String chatId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat/$chatId/messages?page=$page&limit=$limit'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'messages': (data.asListOrNull('messages') ?? [])
              .where((m) => m is Map)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList(),
          'hasMore': data.asBool('hasMore'),
          'totalMessages': data.asInt('totalMessages'),
        });
      }
      return ApiResponse.error(data.asString('message', 'Failed to load messages'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/chat/:chatId/messages — Send a message via REST
  static Future<ApiResponse<Map<String, dynamic>>> sendMessage({
    required String chatId,
    required String content,
    String type = 'text',
    String? mediaUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/$chatId/messages'),
        headers: _headers,
        body: jsonEncode({
          'content': content,
          'type': type,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (replyTo != null) 'replyTo': replyTo,
        }),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(Map<String, dynamic>.from(data.asMap('message')));
      }
      return ApiResponse.error(data.asString('message', 'Failed to send message'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== MESSAGE REACTIONS =====

  /// POST /api/chat/:chatId/messages/:messageId/react — Add emoji reaction to a message
  static Future<ApiResponse> addReaction(String chatId, String messageId, String emoji) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/$chatId/messages/$messageId/react'),
        headers: _headers,
        body: jsonEncode({'emoji': emoji}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data.asString('message', 'Failed to add reaction'));
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// DELETE /api/chat/:chatId/messages/:messageId/react — Remove emoji reaction from a message
  static Future<ApiResponse> removeReaction(String chatId, String messageId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/chat/$chatId/messages/$messageId/react'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data.asString('message', 'Failed to remove reaction'));
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ===== NOTIFICATIONS =====

  /// GET /api/notifications
  static Future<ApiResponse<NotificationsResponse>> getNotifications({
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/notifications?page=$page&limit=$limit'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final notifications = (data.asListOrNull('notifications') ?? [])
            .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(NotificationsResponse(
          notifications: notifications,
          unreadCount: data.asInt('unreadCount'),
          hasMore: data.asBool('hasMore'),
        ));
      }
      return ApiResponse.error(data.asString('message', 'Failed to load notifications'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/notifications/unread-count
  static Future<ApiResponse<int>> getUnreadCount() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/notifications/unread-count'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(data.asInt('unreadCount'));
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// PUT /api/notifications/read-all
  static Future<ApiResponse<void>> markAllNotificationsRead() async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/notifications/read-all'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// PUT /api/notifications/:id/read — Mark single notification as read
  static Future<ApiResponse<void>> markNotificationRead(String notifId) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/notifications/$notifId/read'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== UPLOAD =====

  /// POST /api/upload/avatar — Upload profile avatar (multipart)
  static Future<ApiResponse<String>> uploadAvatar(String filePath) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = Uri.parse('$_baseUrl/upload/avatar');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${_authToken ?? ''}';
        request.files.add(await http.MultipartFile.fromPath(
          'avatar',
          filePath,
          contentType: _getMediaType(filePath),
        ));
        final streamedResponse = await request.send().timeout(const Duration(seconds: 60));

        // Handle 401/403 — try token refresh on first attempt
        if ((streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) && attempt == 0) {
          debugPrint('[ApiService] uploadAvatar: token expired, refreshing...');
          final refreshed = await tryRefreshToken();
          if (refreshed) continue;
          onSessionExpired?.call();
          return ApiResponse.error('Session expired. Please login again.');
        }

        final responseBody = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResponse.success(data.asString('url'));
        }
        return ApiResponse.error(data.asString('message', 'Upload failed'));
      } on TimeoutException {
        return ApiResponse.error('Request timed out. Please try again.');
      } catch (e) {
        if (attempt == 0) { debugPrint('[ApiService] uploadAvatar error (retrying): $e'); continue; }
        return ApiResponse.error('Upload error: $e');
      }
    }
    return ApiResponse.error('Avatar upload failed after retries');
  }

  /// POST /api/upload/image — Upload single image (multipart)
  /// Retries once on transient network failure.
  static Future<ApiResponse<String>> uploadImage(String filePath, {String folder = 'images'}) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final fileSizeMB = await File(filePath).length() / (1024 * 1024);
        // Dynamic timeout: 60s base + 20s per MB (min 60s, max 300s)
        final timeoutSecs = (60 + (fileSizeMB * 20)).clamp(60, 300).toInt();
        debugPrint('[ApiService] uploadImage: ${fileSizeMB.toStringAsFixed(1)}MB, timeout: ${timeoutSecs}s, folder=$folder, attempt=${attempt + 1}');

        final uri = Uri.parse('$_baseUrl/upload/image?folder=$folder');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${_authToken ?? ''}';
        request.files.add(await http.MultipartFile.fromPath('image', filePath, contentType: _getMediaType(filePath)));
        final streamedResponse = await request.send().timeout(Duration(seconds: timeoutSecs));

        // Handle 401/403 — try token refresh on first attempt
        if ((streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) && attempt == 0) {
          debugPrint('[ApiService] uploadImage: token expired, refreshing...');
          final refreshed = await tryRefreshToken();
          if (refreshed) continue; // Retry with new token
          onSessionExpired?.call();
          return ApiResponse.error('Session expired. Please login again.');
        }

        final responseBody = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true) {
          final url = data['url']?.toString() ?? data['path']?.toString() ?? '';
          debugPrint('[ApiService] uploadImage success: url=$url');
          if (url.isEmpty) return ApiResponse.error('Upload succeeded but no URL returned');
          return ApiResponse.success(url);
        }
        debugPrint('[ApiService] uploadImage failed: $responseBody');
        return ApiResponse.error(data.asString('message', 'Upload failed'));
      } on TimeoutException {
        if (attempt == 0) {
          debugPrint('[ApiService] uploadImage timed out, retrying...');
          continue;
        }
        return ApiResponse.error('Upload timed out. Check your internet and try again.');
      } catch (e) {
        if (attempt == 0) {
          debugPrint('[ApiService] uploadImage error (retrying): $e');
          continue;
        }
        return ApiResponse.error('Upload error: $e');
      }
    }
    return ApiResponse.error('Upload failed after retries');
  }

  /// POST /api/upload/voice — Upload voice message (multipart)
  static Future<ApiResponse<String>> uploadVoice(String filePath, {int duration = 0}) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = Uri.parse('$_baseUrl/upload/voice');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${_authToken ?? ''}';
        request.fields['duration'] = duration.toString();
        request.files.add(await http.MultipartFile.fromPath('voice', filePath, contentType: _getMediaType(filePath)));
        final streamedResponse = await request.send().timeout(const Duration(seconds: 60));

        // Handle 401/403 — try token refresh on first attempt
        if ((streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) && attempt == 0) {
          debugPrint('[ApiService] uploadVoice: token expired, refreshing...');
          final refreshed = await tryRefreshToken();
          if (refreshed) continue;
          onSessionExpired?.call();
          return ApiResponse.error('Session expired. Please login again.');
        }

        final responseBody = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResponse.success(data.asString('url'));
        }
        return ApiResponse.error(data.asString('message', 'Voice upload failed'));
      } on TimeoutException {
        return ApiResponse.error('Upload timed out. Check your internet and try again.');
      } catch (e) {
        if (attempt == 0) { debugPrint('[ApiService] uploadVoice error (retrying): $e'); continue; }
        return ApiResponse.error('Upload error: $e');
      }
    }
    return ApiResponse.error('Voice upload failed after retries');
  }

  /// POST /api/upload/images — Upload multiple images (multipart, max 5)
  /// Retries up to 2 times on transient network errors.
  static Future<ApiResponse<List<String>>> uploadImages(List<String> filePaths, {String folder = 'posts'}) async {
    // If total file size > 5MB, upload one at a time to avoid server limits
    int totalBytes = 0;
    for (final path in filePaths) {
      totalBytes += await File(path).length();
    }
    debugPrint('[API] uploadImages: ${filePaths.length} files, total ${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB');

    // If files are large, upload individually via single-image endpoint
    if (totalBytes > 5 * 1024 * 1024 || filePaths.length == 1) {
      return _uploadImagesOneByOne(filePaths, folder: folder);
    }

    // Try batch upload with retry
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = Uri.parse('$_baseUrl/upload/images?folder=$folder');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${_authToken ?? ''}';
        for (final path in filePaths) {
          request.files.add(await http.MultipartFile.fromPath('images', path, contentType: _getMediaType(path)));
        }
        final streamedResponse = await request.send().timeout(const Duration(seconds: 120));

        // Handle 401/403 — try token refresh on first attempt
        if ((streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) && attempt == 0) {
          debugPrint('[API] uploadImages: token expired, refreshing...');
          final refreshed = await tryRefreshToken();
          if (refreshed) continue;
          onSessionExpired?.call();
          return ApiResponse.error('Session expired. Please login again.');
        }

        final responseBody = await streamedResponse.stream.bytesToString();
        debugPrint('[API] uploadImages raw response: $responseBody');
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResponse.success(_parseImageUrls(data));
        }
        return ApiResponse.error(data.asString('message', 'Upload failed'));
      } on TimeoutException {
        return ApiResponse.error('Request timed out. Please try again.');
      } catch (e) {
        debugPrint('[API] uploadImages attempt ${attempt + 1} failed: $e');
        if (attempt == 0) {
          // First failure: try one-by-one upload as fallback
          debugPrint('[API] Falling back to one-by-one upload');
          return _uploadImagesOneByOne(filePaths, folder: folder);
        }
        return ApiResponse.error('Upload error: $e');
      }
    }
    return ApiResponse.error('Upload failed after retries');
  }

  /// Upload images one at a time using the single-image endpoint
  static Future<ApiResponse<List<String>>> _uploadImagesOneByOne(List<String> filePaths, {String folder = 'posts'}) async {
    final List<String> urls = [];
    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];
      final fileSize = await File(path).length();
      debugPrint('[API] Uploading image ${i + 1}/${filePaths.length} (${(fileSize / 1024).toStringAsFixed(0)}KB)');

      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final uri = Uri.parse('$_baseUrl/upload/image?folder=$folder');
          final request = http.MultipartRequest('POST', uri);
          request.headers['Authorization'] = 'Bearer ${_authToken ?? ''}';
          request.files.add(await http.MultipartFile.fromPath('image', path, contentType: _getMediaType(path)));
          final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
          final responseBody = await streamedResponse.stream.bytesToString();
          debugPrint('[API] uploadImage response: $responseBody');
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          if (data['success'] == true) {
            final url = data['url']?.toString() ??
                data['path']?.toString() ??
                (data['image'] is Map ? data['image']['url']?.toString() : data['image']?.toString()) ??
                '';
            if (url.isNotEmpty) {
              urls.add(url);
              break; // Success, move to next image
            }
            return ApiResponse.error('Upload succeeded but no URL returned');
          }
          return ApiResponse.error(data.asString('message', 'Image upload failed'));
        } on TimeoutException {
          return ApiResponse.error('Upload timed out. Try again.');
        } catch (e) {
          debugPrint('[API] Single upload attempt ${attempt + 1} error: $e');
          if (attempt == 1) return ApiResponse.error('Upload failed: $e');
          await Future.delayed(const Duration(seconds: 1)); // Brief pause before retry
        }
      }
    }
    debugPrint('[API] All images uploaded: $urls');
    return ApiResponse.success(urls);
  }

  /// Parse image URLs from various backend response formats
  static List<String> _parseImageUrls(Map<String, dynamic> data) {
    final rawImages = data['images'] ?? data['urls'] ?? data['files'] ?? data['data'];
    debugPrint('[API] uploadImages raw images field: $rawImages (type: ${rawImages.runtimeType})');

    List<String> images = [];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is String && item.isNotEmpty) {
          images.add(item);
        } else if (item is Map) {
          final url = (item['url'] ?? item['secure_url'] ?? item['path'] ?? item['location'] ?? item['key'])?.toString();
          if (url != null && url.isNotEmpty) images.add(url);
        }
      }
    } else if (rawImages is String && rawImages.isNotEmpty) {
      images.add(rawImages);
    }

    // Fallback: check if URL is directly in data
    if (images.isEmpty) {
      final directUrl = data['url']?.toString() ?? data['path']?.toString();
      if (directUrl != null && directUrl.isNotEmpty) images.add(directUrl);
    }

    debugPrint('[API] uploadImages parsed URLs: $images');
    return images;
  }

  // ===== SEARCH =====

  /// GET /api/users/nearby — Get nearby users (scope: 'local' or 'global')
  static Future<ApiResponse<List<UserModel>>> searchNearbyUsers(String query, {double? radiusKm, String? scope}) async {
    try {
      final radius = radiusKm ?? LocationService.nearfoRadiusKm;
      final url = query.isNotEmpty
          ? '$_baseUrl/users/search/${Uri.encodeComponent(query)}'
          : '$_baseUrl/users/nearby?limit=50&radius=${radius.round()}${scope != null ? '&scope=$scope' : ''}';
      final res = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['users'] is List) {
        final users = (data.asListOrNull('users') ?? [])
            .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(users);
      }
      return ApiResponse.error(data.asString('message', 'Search failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/users/search/:query — Search users by name or handle
  static Future<ApiResponse<List<Map<String, dynamic>>>> searchUsers(String query) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/search/${Uri.encodeComponent(query)}'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['users'] is List) {
        final users = (data.asListOrNull('users') ?? [])
            .map((u) => Map<String, dynamic>.from(u as Map))
            .toList();
        return ApiResponse.success(users);
      }
      return ApiResponse.error(data.asString('message', 'Search failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/users/suggested — Suggested friends (respects feedPreference / dynamic radius)
  static Future<ApiResponse<List<Map<String, dynamic>>>> getSuggestedFriends({int page = 1, int limit = 30, String? mode, double? radiusKm}) async {
    try {
      final radius = radiusKm ?? LocationService.nearfoRadiusKm;
      final modeParam = mode != null ? '&mode=$mode' : '';
      final res = await http.get(
        Uri.parse('$_baseUrl/users/suggested?limit=$limit$modeParam&radius=${radius.round()}'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['suggestions'] is List) {
        final users = (data.asListOrNull('suggestions') ?? [])
            .map((u) => Map<String, dynamic>.from(u as Map))
            .toList();
        return ApiResponse.success(users);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load suggestions'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/users/my-circle — Mutual followers
  static Future<ApiResponse<List<Map<String, dynamic>>>> getMyCircle() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/my-circle'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if ((data['success'] == true || data['circle'] != null) && data['circle'] is List) {
        final circle = (data.asListOrNull('circle') ?? []).map((u) {
          final m = Map<String, dynamic>.from(u as Map);
          // Backend may return 'distance' instead of 'distanceKm'
          if (m['distanceKm'] == null && m['distance'] != null) {
            m['distanceKm'] = m['distance'];
          }
          return m;
        }).toList();
        return ApiResponse.success(circle);
      }
      return ApiResponse.error(data.asString('message', 'Failed to get circle'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== REELS =====

  /// GET /api/reels/feed — Infinite scroll Reels feed (respects dynamic radius)
  static Future<ApiResponse<List<ReelModel>>> getReelsFeed({
    String mode = 'mixed',
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/reels/feed?mode=$mode&page=$page&limit=$limit&radius=${LocationService.nearfoRadiusKm.round()}'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final reels = (data.asListOrNull('reels') ?? [])
            .map((r) => ReelModel.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(reels, hasMore: data.asBool('hasMore'));
      }
      return ApiResponse.error(data.asString('message', 'Failed to load reels'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/reels — Create a new Reel
  static Future<ApiResponse<ReelModel>> createReel({
    required String videoUrl,
    String? thumbnailUrl,
    String caption = '',
    String audioName = 'Original Audio',
    int duration = 0,
    String visibility = 'public',
  }) async {
    try {
      final body = <String, dynamic>{
        'videoUrl': videoUrl,
        'caption': caption,
        'audioName': audioName,
        'duration': duration,
        'visibility': visibility,
      };
      // Only include thumbnailUrl if it's actually set (empty string fails validation)
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        body['thumbnailUrl'] = thumbnailUrl;
      }
      debugPrint('[ApiService] createReel body: $body');
      final res = await http.post(
        Uri.parse('$_baseUrl/reels'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(ReelModel.fromJson(data.asMap('reel')));
      }
      debugPrint('[ApiService] createReel failed: ${data.asString('message')} | errors: ${data['errors']}');
      // Include validation errors in user-visible message for debugging
      final errors = data['errors'];
      final errMsg = data.asString('message', 'Failed to create reel');
      if (errors is List && errors.isNotEmpty) {
        final details = errors.map((e) => e is Map ? (e['msg'] ?? e['message'] ?? e.toString()) : e.toString()).join(', ');
        return ApiResponse.error('$errMsg: $details');
      }
      return ApiResponse.error(errMsg);
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/reels/:id/like — Toggle like on a reel
  static Future<ApiResponse<Map<String, dynamic>>> toggleReelLike(String reelId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/reels/$reelId/like'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'isLiked': data.asBool('isLiked'),
          'likesCount': data.asInt('likesCount'),
        });
      }
      return ApiResponse.error(data.asString('message', 'Like failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/reels/:id/view — Increment view count
  static Future<ApiResponse<int>> recordReelView(String reelId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/reels/$reelId/view'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(data.asInt('viewsCount'));
      }
      return ApiResponse.error(data.asString('message', 'View tracking failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/reels/:id/bookmark — Toggle bookmark on a reel
  static Future<ApiResponse<bool>> toggleReelBookmark(String reelId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/reels/$reelId/bookmark'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(data.asBool('isBookmarked'));
      }
      return ApiResponse.error(data.asString('message', 'Bookmark failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// DELETE /api/reels/:id — Delete a reel
  static Future<ApiResponse<void>> deleteReel(String reelId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/reels/$reelId'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Delete failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/reels/user/:userId — Get reels by user
  static Future<ApiResponse<List<ReelModel>>> getUserReels(String userId, {int page = 1}) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/reels/user/$userId?page=$page&limit=20'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final reels = (data.asListOrNull('reels') ?? [])
            .map((r) => ReelModel.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(reels, hasMore: data.asBool('hasMore'));
      }
      return ApiResponse.error(data.asString('message', 'Failed to load reels'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/posts/:id/bookmark — Toggle bookmark on a post
  static Future<ApiResponse<bool>> togglePostBookmark(String postId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/posts/$postId/bookmark'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(data.asBool('isBookmarked'));
      }
      return ApiResponse.error(data.asString('message', 'Bookmark failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/posts/saved/list — Get user's bookmarked posts
  static Future<ApiResponse<List<PostModel>>> getSavedPosts({int page = 1}) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/posts/saved/list?page=$page&limit=20'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if ((data['success'] == true || data['posts'] != null) && data['posts'] is List) {
        final posts = (data.asListOrNull('posts') ?? [])
            .map((p) => PostModel.fromJson(p as Map<String, dynamic>))
            .toList();
        final hasMore = data.asBool('hasMore') || (data['pages'] != null ? page < data.asInt('pages') : false);
        return ApiResponse.success(posts, hasMore: hasMore);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load saved posts'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/reels/saved/list — Get user's bookmarked reels
  static Future<ApiResponse<List<ReelModel>>> getSavedReels({int page = 1}) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/reels/saved/list?page=$page&limit=20'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if ((data['success'] == true || data['reels'] != null) && data['reels'] is List) {
        final reels = (data.asListOrNull('reels') ?? [])
            .map((r) => ReelModel.fromJson(r as Map<String, dynamic>))
            .toList();
        final hasMore = data.asBool('hasMore') || (data['pages'] != null ? page < data.asInt('pages') : false);
        return ApiResponse.success(reels, hasMore: hasMore);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load saved reels'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== USER PROFILE & FOLLOW =====

  /// GET /api/users/:handle — Get another user's public profile
  static Future<ApiResponse<Map<String, dynamic>>> getUserProfile(String handle) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/$handle'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(Map<String, dynamic>.from(data.asMap('user')));
      }
      return ApiResponse.error(data.asString('message', 'User not found'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/users/id/:userId — Get user profile by MongoDB _id
  static Future<ApiResponse<Map<String, dynamic>>> getUserProfileById(String userId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/id/$userId'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success(Map<String, dynamic>.from(data.asMap('user')));
      }
      return ApiResponse.error(data.asString('message', 'User not found'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/users/:id/follow — Toggle follow/unfollow
  static Future<ApiResponse<Map<String, dynamic>>> toggleFollow(String userId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/users/$userId/follow'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'isFollowing': data.asBool('isFollowing'),
          'followersCount': data.asInt('followersCount'),
          'followingCount': data.asInt('followingCount'),
        });
      }
      return ApiResponse.error(data.asString('message', 'Follow failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/users/:id/followers — Get followers list
  static Future<ApiResponse<Map<String, dynamic>>> getFollowers(String userId, {int page = 1}) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/$userId/followers?page=$page&limit=30'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'users': (data.asListOrNull('followers') ?? []).map((u) => Map<String, dynamic>.from(u as Map<String, dynamic>)).toList(),
          'total': data.asInt('totalFollowers'),
          'hasMore': data.asBool('hasMore'),
        });
      }
      return ApiResponse.error(data.asString('message', 'Failed to load followers'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/users/:id/following — Get following list
  static Future<ApiResponse<Map<String, dynamic>>> getFollowing(String userId, {int page = 1}) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/$userId/following?page=$page&limit=30'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'users': (data.asListOrNull('following') ?? []).map((u) => Map<String, dynamic>.from(u as Map<String, dynamic>)).toList(),
          'total': data.asInt('totalFollowing'),
          'hasMore': data.asBool('hasMore'),
        });
      }
      return ApiResponse.error(data.asString('message', 'Failed to load following'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get posts by a specific user — tries ALL possible endpoint patterns
  static Future<ApiResponse<List<PostModel>>> getUserPosts(String userId, {int page = 1}) async {
    // List of endpoint patterns to try (most common backend patterns)
    final endpoints = [
      '$_baseUrl/posts/user/$userId?page=$page&limit=20',        // /posts/user/:id
      '$_baseUrl/users/$userId/posts?page=$page&limit=20',       // /users/:id/posts
      '$_baseUrl/posts?userId=$userId&page=$page&limit=20',      // /posts?userId=
      '$_baseUrl/posts?author=$userId&page=$page&limit=20',      // /posts?author=
      '$_baseUrl/posts/feed?userId=$userId&page=$page&limit=20', // /posts/feed?userId=
    ];

    for (final url in endpoints) {
      try {
        final res = await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);

        // Skip 404s silently — endpoint doesn't exist
        if (res.statusCode == 404) {
          debugPrint('[ApiService] getUserPosts: 404 for $url');
          continue;
        }
        // Handle auth errors
        if (res.statusCode == 401 || res.statusCode == 403) {
          onSessionExpired?.call();
          return ApiResponse.error('Session expired. Please login again.');
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          // Try all common response keys for posts array
          final rawPosts = data.asListOrNull('posts')
              ?? data.asListOrNull('data')
              ?? data.asListOrNull('results')
              ?? data.asListOrNull('items')
              ?? [];
          debugPrint('[ApiService] getUserPosts($userId): ${rawPosts.length} posts from $url');
          if (rawPosts.isNotEmpty) {
            final posts = rawPosts
                .map((p) => PostModel.fromJson(p as Map<String, dynamic>))
                .toList();
            return ApiResponse.success(posts, hasMore: data.asBool('hasMore'));
          }
        }
      } catch (e) {
        debugPrint('[ApiService] getUserPosts endpoint error ($url): $e');
      }
    }

    debugPrint('[ApiService] getUserPosts($userId): all endpoints returned empty');
    return ApiResponse.success([]);
  }

  // ===== BLOCK USER =====

  /// POST /api/users/:id/block — Toggle block/unblock
  static Future<ApiResponse<Map<String, dynamic>>> toggleBlock(String userId, {String reason = ''}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/users/$userId/block'),
        headers: _headers,
        body: jsonEncode({'reason': reason}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({'isBlocked': data.asBool('isBlocked')});
      }
      return ApiResponse.error(data.asString('message', 'Block failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/users/blocked/list — Get blocked users list
  static Future<ApiResponse<List<Map<String, dynamic>>>> getBlockedUsers() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/blocked/list'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final users = (data.asListOrNull('blockedUsers') ?? [])
            .map((u) => Map<String, dynamic>.from(u as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(users);
      }
      return ApiResponse.error(data.asString('message', 'Failed to load blocked users'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== CHAT RESTRICTION =====

  /// POST /api/chat/:chatId/restrict — Toggle restrict a user in chat (silent)
  static Future<ApiResponse<Map<String, dynamic>>> toggleChatRestriction({
    required String chatId,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/$chatId/restrict'),
        headers: _headers,
        body: jsonEncode({'userId': userId}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({'isRestricted': data.asBool('isRestricted')});
      }
      return ApiResponse.error(data.asString('message', 'Restriction failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET /api/chat/:chatId/restriction-status
  static Future<ApiResponse<List<String>>> getChatRestrictionStatus(String chatId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat/$chatId/restriction-status'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final ids = (data.asListOrNull('restrictedUserIds') ?? []).map((id) => id.toString()).toList();
        return ApiResponse.success(ids);
      }
      return ApiResponse.error(data.asString('message', 'Failed to get restriction status'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/chat/:chatId/accept-restricted — Accept restricted messages (message request)
  static Future<ApiResponse<Map<String, dynamic>>> acceptRestrictedMessages(String chatId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/$chatId/accept-restricted'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({'accepted': data['accepted'] ?? 0});
      }
      return ApiResponse.error(data.asString('message', 'Failed to accept messages'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /api/chat/:chatId/delete-restricted — Delete restricted messages (decline message request)
  static Future<ApiResponse<Map<String, dynamic>>> deleteRestrictedMessages(String chatId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/$chatId/delete-restricted'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({'deleted': data['deleted'] ?? 0});
      }
      return ApiResponse.error(data.asString('message', 'Failed to delete messages'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ===== STORIES =====

  static Future<ApiResponse<Map<String, dynamic>>> createStory({
    required String mediaUrl, String mediaType = 'image', String caption = '', int duration = 5, String visibility = 'public',
    String? musicName, String? musicUrl,
  }) async {
    try {
      final body = {
        'mediaUrl': mediaUrl, 'mediaType': mediaType, 'caption': caption, 'duration': duration, 'visibility': visibility,
        if (musicName != null) 'musicName': musicName,
        if (musicUrl != null) 'musicUrl': musicUrl,
      };
      debugPrint('[ApiService] createStory body: $body');
      final res = await http.post(Uri.parse('$_baseUrl/stories'), headers: _headers,
        body: jsonEncode(body)).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('story')));
      debugPrint('[ApiService] createStory failed: ${data.asString('message')} | errors: ${data['errors']}');
      final errors = data['errors'];
      final errMsg = data.asString('message', 'Failed to create story');
      if (errors is List && errors.isNotEmpty) {
        final details = errors.map((e) => e is Map ? (e['msg'] ?? e['message'] ?? e.toString()) : e.toString()).join(', ');
        return ApiResponse.error('$errMsg: $details');
      }
      return ApiResponse.error(errMsg);
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getStoryFeed() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/stories/feed'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        // Backend returns 'storyGroups', support both keys for compatibility
        final feed = (data.asListOrNull('storyGroups') ?? data.asListOrNull('storyFeed')) ?? [];
        return ApiResponse.success(feed.map((s) => Map<String, dynamic>.from(s as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<int>> viewStory(String storyId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/stories/$storyId/view'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asInt('viewsCount'));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<Map<String, dynamic>>> toggleStoryLike(String storyId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/stories/$storyId/like'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success({'isLiked': data.asBool('isLiked'), 'likesCount': data.asInt('likesCount')});
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> deleteStory(String storyId) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/stories/$storyId'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getStoryViewers(String storyId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/stories/$storyId/viewers'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data.asListOrNull('viewers') ?? []).map((v) => Map<String, dynamic>.from(v as Map<String, dynamic>)).toList());
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  /// GET /api/stories/:id/likes — Get users who liked this story
  static Future<ApiResponse<List<Map<String, dynamic>>>> getStoryLikers(String storyId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/stories/$storyId/likes'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final likers = data.asListOrNull('likes') ?? data.asListOrNull('likers') ?? data.asListOrNull('users') ?? [];
        return ApiResponse.success(likers.map((v) => Map<String, dynamic>.from(v as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== STORY HIGHLIGHTS =====

  static Future<ApiResponse<Map<String, dynamic>>> createHighlight({
    required String title, List<String>? storyIds, String? coverUrl,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/stories/highlights'), headers: _headers,
        body: jsonEncode({'title': title, 'storyIds': storyIds ?? [], 'coverUrl': coverUrl ?? ''})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('highlight')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getHighlights(String userId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/stories/highlights/$userId'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('highlights') ?? [];
        return ApiResponse.success(list.map((h) => Map<String, dynamic>.from(h as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> updateHighlight(String id, {String? title, List<String>? storyIds, String? coverUrl}) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (storyIds != null) body['storyIds'] = storyIds;
      if (coverUrl != null) body['coverUrl'] = coverUrl;
      final res = await http.put(Uri.parse('$_baseUrl/stories/highlights/$id'), headers: _headers,
        body: jsonEncode(body)).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> deleteHighlight(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/stories/highlights/$id'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> addStoryToHighlight(String highlightId, String storyId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/stories/highlights/$highlightId/add'), headers: _headers,
        body: jsonEncode({'storyId': storyId})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== SUGGESTED USERS (EXPLORE/DISCOVER) =====

  static Future<ApiResponse<List<Map<String, dynamic>>>> getSuggestedUsers({int limit = 20}) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/users/suggested?limit=$limit'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('suggestions') ?? [];
        return ApiResponse.success(list.map((s) => Map<String, dynamic>.from(s as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== POST EDIT =====

  static Future<ApiResponse<Map<String, dynamic>>> editPost(String postId, {String? content, String? mood, String? visibility}) async {
    try {
      final body = <String, dynamic>{};
      if (content != null) body['content'] = content;
      if (mood != null) body['mood'] = mood;
      if (visibility != null) body['visibility'] = visibility;
      final res = await http.put(Uri.parse('$_baseUrl/posts/$postId'), headers: _headers,
        body: jsonEncode(body)).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('post')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== ONLINE STATUS =====

  static Future<ApiResponse<Map<String, dynamic>>> getOnlineStatus(List<String> userIds) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/users/online-status'), headers: _headers,
        body: jsonEncode({'userIds': userIds})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('statuses')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== LIVE STREAMING =====

  static Future<ApiResponse<Map<String, dynamic>>> startLiveStream({String title = 'Live', String? description}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/live/start'), headers: _headers,
        body: jsonEncode({'title': title, 'description': description ?? ''})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('stream')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> endLiveStream(String streamId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/live/$streamId/end'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getActiveLiveStreams() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/live/active'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('streams') ?? [];
        return ApiResponse.success(list.map((s) => Map<String, dynamic>.from(s as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> joinLiveStream(String streamId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/live/$streamId/join'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> sendLiveComment(String streamId, String text) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/live/$streamId/comment'), headers: _headers,
        body: jsonEncode({'text': text})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }


  /// Like a live stream (heart reaction)
  static Future<ApiResponse<Map<String, dynamic>>> sendLiveLike(String streamId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/live/$streamId/like'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  /// Leave a live stream (viewer exits)
  static Future<ApiResponse<void>> leaveLiveStream(String streamId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/live/$streamId/leave'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  /// Get live stream info (for refreshing viewer/like counts)
  static Future<ApiResponse<Map<String, dynamic>>> getLiveStreamInfo(String streamId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/live/$streamId'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final stream = data['stream'] ?? data['data'] ?? data;
        return ApiResponse.success(Map<String, dynamic>.from(stream as Map));
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  /// Get live stream comments/chat
  static Future<ApiResponse<List<Map<String, dynamic>>>> getLiveComments(String streamId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/live/$streamId/comments'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('comments') ?? data.asListOrNull('data') ?? [];
        return ApiResponse.success(list.map((c) => Map<String, dynamic>.from(c as Map)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== HASHTAG PAGES =====

  static Future<ApiResponse<Map<String, dynamic>>> getHashtagFeed(String tag, {int page = 1, String sort = 'recent'}) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/posts/hashtag/$tag?page=$page&sort=$sort'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== REPOST TO STORY =====

  static Future<ApiResponse<Map<String, dynamic>>> repostToStory(String postId, {String? caption}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/stories/repost'), headers: _headers,
        body: jsonEncode({'postId': postId, 'caption': caption ?? ''})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('story')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== COLLECTIONS =====

  static Future<ApiResponse<Map<String, dynamic>>> createCollection({required String name, String? description, bool isPrivate = true}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/collections'), headers: _headers,
        body: jsonEncode({'name': name, 'description': description ?? '', 'isPrivate': isPrivate})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('collection')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getCollections() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/collections'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('collections') ?? [];
        return ApiResponse.success(list.map((c) => Map<String, dynamic>.from(c as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getCollection(String id) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/collections/$id'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('collection')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<dynamic>>> getCollectionPosts(String collectionId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/collections/$collectionId/posts'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode == 200 && data['success'] == true) {
        final posts = data.asListOrNull('posts') ?? [];
        return ApiResponse.success(posts);
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> addToCollection(String collectionId, String postId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/collections/$collectionId/add'), headers: _headers,
        body: jsonEncode({'postId': postId})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> removeFromCollection(String collectionId, String postId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/collections/$collectionId/remove'), headers: _headers,
        body: jsonEncode({'postId': postId})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> deleteCollection(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/collections/$id'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== CHAT SEARCH =====

  static Future<ApiResponse<List<Map<String, dynamic>>>> searchChatMessages(String query, {String? chatId}) async {
    try {
      final params = 'q=${Uri.encodeComponent(query)}${chatId != null ? '&chatId=$chatId' : ''}';
      final res = await http.get(Uri.parse('$_baseUrl/chat/search?$params'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('messages') ?? [];
        return ApiResponse.success(list.map((m) => Map<String, dynamic>.from(m as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== DMCA TAKEDOWN =====

  static Future<ApiResponse<Map<String, dynamic>>> submitTakedown({
    required String complainantName, required String complainantEmail, required String contentType,
    required String contentId, required String description, String? originalWorkUrl, bool swornStatement = false,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/takedown'), headers: _headers,
        body: jsonEncode({
          'complainantName': complainantName, 'complainantEmail': complainantEmail,
          'contentType': contentType, 'contentId': contentId, 'description': description,
          'originalWorkUrl': originalWorkUrl ?? '', 'swornStatement': swornStatement,
        })).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getTakedowns({String status = 'pending'}) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/takedown?status=$status'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('takedowns') ?? [];
        return ApiResponse.success(list.map((t) => Map<String, dynamic>.from(t as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> reviewTakedown(String id, {required String action, String? notes}) async {
    try {
      final res = await http.put(Uri.parse('$_baseUrl/takedown/$id/review'), headers: _headers,
        body: jsonEncode({'action': action, 'notes': notes ?? ''})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== MODERATION (ADMIN) =====

  static Future<ApiResponse<void>> banUser(String userId, {String? reason}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/moderation/ban'), headers: _headers,
        body: jsonEncode({'userId': userId, 'reason': reason ?? ''})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> unbanUser(String userId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/moderation/unban'), headers: _headers,
        body: jsonEncode({'userId': userId})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> suspendUser(String userId, {int hours = 168, String? reason}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/moderation/suspend'), headers: _headers,
        body: jsonEncode({'userId': userId, 'durationHours': hours, 'reason': reason ?? ''})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getBannedUsers() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/moderation/banned'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        final list = data.asListOrNull('users') ?? [];
        return ApiResponse.success(list.map((u) => Map<String, dynamic>.from(u as Map<String, dynamic>)).toList());
      }
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> hidePost(String postId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/moderation/hide-post'), headers: _headers,
        body: jsonEncode({'postId': postId})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException { return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== NEARFO SCORE =====

  static Future<ApiResponse<Map<String, dynamic>>> getNearfoScore() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/users/nearfo-score'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data));
      return ApiResponse.error(data.asString('message', 'Failed to load score'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== REPORTS =====

  static Future<ApiResponse<void>> reportContent({
    required String contentType, required String contentId, required String reason, String description = '',
  }) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/reports'), headers: _headers,
        body: jsonEncode({'contentType': contentType, 'contentId': contentId, 'reason': reason, 'description': description})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Report failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== MESSAGE REQUESTS =====

  static Future<ApiResponse<Map<String, dynamic>>> sendMessageRequest({required String recipientId, String message = ''}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/message-requests'), headers: _headers,
        body: jsonEncode({'recipientId': recipientId, 'message': message})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('request')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getIncomingMessageRequests() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/message-requests/incoming'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data.asListOrNull('requests') ?? []).map((r) => Map<String, dynamic>.from(r as Map<String, dynamic>)).toList());
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<Map<String, dynamic>>> acceptMessageRequest(String requestId) async {
    try {
      final res = await http.put(Uri.parse('$_baseUrl/message-requests/$requestId/accept'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('chat')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> declineMessageRequest(String requestId) async {
    try {
      final res = await http.put(Uri.parse('$_baseUrl/message-requests/$requestId/decline'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<int>> getMessageRequestCount() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/message-requests/count'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asInt('count'));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== GROUP CHAT =====

  static Future<ApiResponse<Map<String, dynamic>>> createGroupChat({
    required List<String> participantIds, required String groupName, String groupDescription = '',
  }) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/chat/group'), headers: _headers,
        body: jsonEncode({'participantIds': participantIds, 'groupName': groupName, 'groupDescription': groupDescription})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('chat')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateGroupChat({
    required String chatId, String? groupName, String? groupDescription, String? groupAvatar,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (groupName != null) body['groupName'] = groupName;
      if (groupDescription != null) body['groupDescription'] = groupDescription;
      if (groupAvatar != null) body['groupAvatar'] = groupAvatar;
      final res = await http.put(Uri.parse('$_baseUrl/chat/group/$chatId'), headers: _headers, body: jsonEncode(body)).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('chat')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> addGroupMembers({required String chatId, required List<String> userIds}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/chat/group/$chatId/add'), headers: _headers, body: jsonEncode({'userIds': userIds})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> removeGroupMember({required String chatId, required String userId}) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/chat/group/$chatId/remove'), headers: _headers, body: jsonEncode({'userId': userId})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> leaveGroup(String chatId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/chat/group/$chatId/leave'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== CHAT SETTINGS & PREMIUM =====

  static Future<ApiResponse<Map<String, dynamic>>> getChatSettings(String chatId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/chat/$chatId/settings'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('settings')));
      return ApiResponse.error(data.asString('message', 'Failed to load settings'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> updateChatSettings({
    required String chatId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      final res = await http.put(Uri.parse('$_baseUrl/chat/$chatId/settings'), headers: _headers, body: jsonEncode(settings)).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed to update settings'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  /// Toggle hiding online status from a specific user
  static Future<ApiResponse<void>> toggleHideOnlineFrom({required String targetUserId, required bool hide}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/hide-online'),
        headers: _headers,
        body: jsonEncode({'targetUserId': targetUserId, 'hide': hide}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed to update'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  /// Check if online status is hidden from a specific user
  static Future<ApiResponse<bool>> isOnlineHiddenFrom(String targetUserId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat/hide-online/$targetUserId'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asBool('hidden'));
      return ApiResponse.error(data.asString('message', 'Failed to check'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getChatMedia(String chatId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/chat/$chatId/media'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data.asListOrNull('media') ?? []).map((m) => Map<String, dynamic>.from(m as Map<String, dynamic>)).toList());
      return ApiResponse.error(data.asString('message', 'Failed to load media'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  /// PUT /api/chat/:chatId/messages/:messageId/edit — Edit a text message
  static Future<ApiResponse<Map<String, dynamic>>> editMessage({
    required String chatId,
    required String messageId,
    required String content,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/chat/$chatId/messages/$messageId/edit'),
        headers: _headers,
        body: jsonEncode({'content': content}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('data')));
      return ApiResponse.error(data.asString('message', 'Failed to edit message'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> unsendMessage({required String chatId, required String messageId}) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/chat/$chatId/messages/$messageId/unsend'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed to unsend message'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> deleteMessage({required String chatId, required String messageId}) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/chat/$chatId/messages/$messageId'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed to delete message'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> deleteChat(String chatId) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/chat/$chatId'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed to delete chat'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> toggleBlockUser(String userId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/chat/block/$userId'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== ADMIN =====

  static Future<ApiResponse<Map<String, dynamic>>> getAdminDashboard() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/admin/dashboard'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(Map<String, dynamic>.from(data.asMap('dashboard')));
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getAdminUsers({int page = 1, String search = ''}) async {
    try {
      final q = search.isNotEmpty ? '&search=${Uri.encodeComponent(search)}' : '';
      final res = await http.get(Uri.parse('$_baseUrl/admin/users?page=$page&limit=30$q'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data.asListOrNull('users') ?? []).map((u) => Map<String, dynamic>.from(u as Map<String, dynamic>)).toList());
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> updateAdminUser(String userId, Map<String, dynamic> fields) async {
    try {
      final res = await http.put(Uri.parse('$_baseUrl/admin/users/$userId'), headers: _headers, body: jsonEncode(fields)).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getFlaggedContent() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/admin/content/flagged'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success({'flaggedPosts': (data['flaggedPosts'] as List?) ?? [], 'flaggedReels': (data['flaggedReels'] as List?) ?? []});
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getReports({String status = 'pending', int page = 1}) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/reports?status=$status&page=$page'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data.asListOrNull('reports') ?? []).map((r) => Map<String, dynamic>.from(r as Map<String, dynamic>)).toList());
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  static Future<ApiResponse<void>> reviewReport(String reportId, {required String status, String actionTaken = ''}) async {
    try {
      final res = await http.put(Uri.parse('$_baseUrl/reports/$reportId/review'), headers: _headers,
        body: jsonEncode({'status': status, 'actionTaken': actionTaken})).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== HEALTH CHECK =====

  static Future<bool> healthCheck() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(_timeout);
      final data = _decodeResponse(res);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ===== FCM TOKEN =====

  static Future<ApiResponse<void>> registerFcmToken(String fcmToken) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/fcm-token'),
        headers: _headers,
        body: jsonEncode({'fcmToken': fcmToken}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(null);
      return ApiResponse.error(data.asString('message', 'FCM token failed'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  // ===== DIGITAL AVATAR =====

  static Future<ApiResponse<List<dynamic>>> getAvatarStyles() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/avatar/styles'), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asListOrNull('styles') ?? []);
      return ApiResponse.error(data.asString('message', 'Failed to get styles'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  static Future<ApiResponse<Map<String, dynamic>>> generateAvatarVariations({
    required String style,
    int count = 12,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/avatar/generate-variations'),
        headers: _headers,
        body: jsonEncode({'style': style, 'count': count}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) {
        return ApiResponse.success({
          'style': data.asString('style'),
          'variations': data['variations'],
        });
      }
      return ApiResponse.error(data.asString('message', 'Failed to generate variations'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  static Future<ApiResponse<String>> setAvatarAsProfile({
    required String style,
    required String seed,
    Map<String, dynamic>? options,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/avatar/set-profile'),
        headers: _headers,
        body: jsonEncode({
          'style': style,
          'seed': seed,
          if (options != null) 'options': options,
        }),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asString('url'));
      return ApiResponse.error(data.asString('message', 'Failed to set avatar'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  static Future<ApiResponse<String>> generateAvatar({
    required String style,
    required String seed,
    Map<String, dynamic>? options,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/avatar/generate'),
        headers: _headers,
        body: jsonEncode({
          'style': style,
          'seed': seed,
          if (options != null) 'options': options,
        }),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asString('url'));
      return ApiResponse.error(data.asString('message', 'Failed to generate avatar'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  // ===== BOSS COMMAND CENTER =====

  /// Submit an order to AI agents
  static Future<ApiResponse<Map<String, dynamic>>> submitBossOrder({
    required String order,
    required List<String> agents,
    String? quickCommand,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/boss/order'),
        headers: _headers,
        body: jsonEncode({
          'order': order,
          'agents': agents,
          if (quickCommand != null) 'quickCommand': quickCommand,
        }),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data['data'] as Map<String, dynamic>?) ?? {});
      return ApiResponse.error(data.asString('message', 'Failed to submit order'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  /// Execute a quick command
  static Future<ApiResponse<Map<String, dynamic>>> executeQuickCommand(String command) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/boss/quick-command'),
        headers: _headers,
        body: jsonEncode({'command': command}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data['data'] as Map<String, dynamic>?) ?? {});
      return ApiResponse.error(data.asString('message', 'Failed to execute command'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  /// Get boss orders list
  static Future<ApiResponse<List<dynamic>>> getBossOrders({int page = 1, String? status}) async {
    try {
      String url = '$_baseUrl/boss/orders?page=$page&limit=20';
      if (status != null) url += '&status=$status';
      final res = await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asListOrNull('data') ?? []);
      return ApiResponse.error(data.asString('message', 'Failed to load orders'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  /// Get single order detail with agent steps
  static Future<ApiResponse<Map<String, dynamic>>> getBossOrderDetail(String orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/boss/orders/$orderId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data['data'] as Map<String, dynamic>?) ?? {});
      return ApiResponse.error(data.asString('message', 'Failed to load order detail'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  /// Get boss dashboard stats
  static Future<ApiResponse<Map<String, dynamic>>> getBossDashboard() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/boss/dashboard'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data['data'] as Map<String, dynamic>?) ?? {});
      return ApiResponse.error(data.asString('message', 'Failed to load dashboard'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  /// Get all agents info
  static Future<ApiResponse<List<dynamic>>> getBossAgents() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/boss/agents'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success(data.asListOrNull('data') ?? []);
      return ApiResponse.error(data.asString('message', 'Failed to load agents'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  /// Cancel an order
  static Future<ApiResponse<Map<String, dynamic>>> cancelBossOrder(String orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/boss/orders/$orderId/cancel'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true) return ApiResponse.success((data['data'] as Map<String, dynamic>?) ?? {});
      return ApiResponse.error(data.asString('message', 'Failed to cancel order'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) { return ApiResponse.error(e.toString()); }
  }

  // ===== CALL HISTORY =====

  /// GET /api/calls — Get call history
  static Future<ApiResponse<List<Map<String, dynamic>>>> getCallHistory({int page = 1}) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/calls?page=$page&limit=30'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode == 200 && data['success'] == true) {
        final calls = (data.asListOrNull('calls') ?? []).map((c) => Map<String, dynamic>.from(c as Map<String, dynamic>)).toList();
        return ApiResponse.success(calls, hasMore: data.asBool('hasMore'));
      }
      return ApiResponse.error(data.asString('message', 'Failed to get call history'));
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// POST /api/calls — Log a call
  static Future<ApiResponse<Map<String, dynamic>>> logCall({
    required String receiverId,
    String type = 'audio',
    String status = 'missed',
    int duration = 0,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/calls'),
        headers: _headers,
        body: jsonEncode({
          'receiverId': receiverId,
          'type': type,
          'status': status,
          'duration': duration,
        }),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode == 200 && data['success'] == true) {
        return ApiResponse.success(Map<String, dynamic>.from(data.asMap('callLog')));
      }
      return ApiResponse.error(data.asString('message', 'Failed to log call'));
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ===== GROUP CHAT =====

  /// GET /api/chat/group/:chatId — Get group info
  static Future<ApiResponse<Map<String, dynamic>>> getGroupInfo(String chatId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat/group/$chatId'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode == 200 && data['success'] == true) {
        return ApiResponse.success(Map<String, dynamic>.from(data.asMap('group')));
      }
      return ApiResponse.error(data.asString('message', 'Failed to get group info'));
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// PUT /api/chat/group/:chatId/add — Add member to group
  static Future<ApiResponse> addGroupMember(String chatId, String userId) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/chat/group/$chatId/add'),
        headers: _headers,
        body: jsonEncode({'userId': userId}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode == 200) return ApiResponse.success(data);
      return ApiResponse.error(data.asString('message', 'Failed'));
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ===== CALL SIGNALING =====

  /// POST /api/calls/initiate — Initiate a call (triggers FCM push + stores pending offer)
  /// This ensures the recipient gets a push notification even if their socket is disconnected.
  static Future<ApiResponse<Map<String, dynamic>>> initiateCallPush({
    required String recipientId,
    required String callerName,
    String? callerAvatar,
    required Map<String, dynamic> offer,
    required bool isVideo,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/calls/initiate'),
        headers: _headers,
        body: jsonEncode({
          'recipientId': recipientId,
          'callerName': callerName,
          'callerAvatar': callerAvatar ?? '',
          'offer': offer,
          'isVideo': isVideo,
        }),
      ).timeout(const Duration(seconds: 10));
      final data = _decodeResponse(res);
      if (res.statusCode == 200 && data['success'] == true) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data.asString('message', 'Failed to initiate call'));
    } catch (e) {
      debugPrint('[ApiService] initiateCallPush error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  /// Fetch pending incoming call offer (for push-notification wakeup flow)
  /// When app wakes from push and doesn't have the SDP offer, fetch it from server
  static Future<ApiResponse<Map<String, dynamic>>> getPendingCall() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/calls/pending'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      final data = _decodeResponse(res);
      if (data['success'] == true && data['pending'] != null) {
        return ApiResponse.success(Map<String, dynamic>.from(data['pending'] as Map));
      }
      return ApiResponse.error('No pending call');
    } on TimeoutException {
      return ApiResponse.error('Request timed out');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Fetch TURN/STUN server credentials for WebRTC calls
  /// Backend returns dynamic credentials (Metered.ca / Twilio / coturn)
  static Future<List<Map<String, dynamic>>> getTurnCredentials() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/calls/turn-credentials'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      final data = _decodeResponse(res);
      if (data['success'] == true && data['iceServers'] is List) {
        return (data.asListOrNull('iceServers') ?? []).map((s) => Map<String, dynamic>.from(s as Map)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] TURN credentials fetch failed: $e');
    }
    // Backend TURN fetch failed — try Metered.ca TURN API directly (if API key is configured)
    if (_meteredApiKey.isNotEmpty) {
      debugPrint('[ApiService] Backend TURN unavailable — trying Metered.ca API directly...');
      try {
        final meteredRes = await http.get(
          Uri.parse('https://nearfo.metered.live/api/v1/turn/credentials?apiKey=$_meteredApiKey'),
        ).timeout(const Duration(seconds: 5));
        if (meteredRes.statusCode == 200) {
          final List<dynamic> meteredServers = jsonDecode(meteredRes.body) as List<dynamic>;
          if (meteredServers.isNotEmpty) {
            debugPrint('[ApiService] Got ${meteredServers.length} TURN servers from Metered.ca');
            return meteredServers.map((s) => Map<String, dynamic>.from(s as Map)).toList();
          }
        }
      } catch (e) {
        debugPrint('[ApiService] Metered.ca TURN fetch also failed: $e');
      }
    } else {
      debugPrint('[ApiService] No Metered API key configured — skipping direct TURN fallback');
    }

    // Fallback: Nearfo self-hosted coturn TURN server (Mumbai, India) + Google STUN
    debugPrint('[ApiService] Using Nearfo self-hosted coturn TURN server + Google STUN');
    return [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:3.111.178.231:3478'},
      {
        'urls': 'turn:3.111.178.231:3478',
        'username': 'nearfo',
        'credential': '9r8EVtyYoNxcC8i2zt7Xcu18V8AxsXTi',
      },
      {
        'urls': 'turn:3.111.178.231:3478?transport=tcp',
        'username': 'nearfo',
        'credential': '9r8EVtyYoNxcC8i2zt7Xcu18V8AxsXTi',
      },
      {
        'urls': 'turn:3.111.178.231:5349',
        'username': 'nearfo',
        'credential': '9r8EVtyYoNxcC8i2zt7Xcu18V8AxsXTi',
      },
    ];
  }

  // ===== Music Library =====
  static Future<ApiResponse<List<Map<String, dynamic>>>> getMusicLibrary() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/stories/music-library'),
        headers: _headers,
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['music'] != null) {
        return ApiResponse.success(List<Map<String, dynamic>>.from(data['music'] as List));
      }
      return ApiResponse.error(data.asString('message', 'Failed to load music'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

  // ===== AI Labels =====
  static Future<ApiResponse<List<String>>> generateAILabels({required String caption}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/stories/ai-labels'),
        headers: _headers,
        body: jsonEncode({'caption': caption}),
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (data['success'] == true && data['labels'] != null) {
        return ApiResponse.success(List<String>.from(data['labels'] as List));
      }
      return ApiResponse.error(data.asString('message', 'Failed to generate labels'));
    } on TimeoutException {
      return ApiResponse.error('Request timed out.');
    } catch (e) { return ApiResponse.error('Network error: $e'); }
  }

}

// ===== RESPONSE WRAPPER =====

class ApiResponse<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;
  final bool isNewUser;
  final bool hasMore;

  ApiResponse._({
    this.data,
    this.errorMessage,
    required this.isSuccess,
    this.isNewUser = false,
    this.hasMore = false,
  });

  factory ApiResponse.success(T data, {bool isNewUser = false, bool hasMore = false}) {
    return ApiResponse._(data: data, isSuccess: true, isNewUser: isNewUser, hasMore: hasMore);
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(errorMessage: message, isSuccess: false);
  }
}

class FeedResponse {
  final List<PostModel> posts;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  FeedResponse({required this.posts, required this.hasMore, this.nextCursor, this.error});

  bool get isSuccess => error == null;
}

class NotificationsResponse {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool hasMore;

  NotificationsResponse({
    required this.notifications,
    required this.unreadCount,
    required this.hasMore,
  });
}
