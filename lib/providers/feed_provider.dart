import 'dart:async';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class FeedProvider extends ChangeNotifier {
  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String _feedMode = 'mixed'; // local, global, mixed
  String? _error;
  String? _nextCursor; // cursor-based pagination
  List<Map<String, dynamic>> _trending = [];

  // Prevent double-tap race conditions on like/bookmark
  final Set<String> _likeInProgress = {};
  final Set<String> _bookmarkInProgress = {};

  // Viral/Trending posts
  List<PostModel> _trendingPosts = [];
  bool _isLoadingTrending = false;
  bool _hasMoreTrending = true;
  int _trendingPage = 1;
  String _trendingTimeWindow = '24h'; // 1h, 6h, 24h, 7d, 30d
  String _trendingScope = 'all'; // all, local

  // Track already-viewed posts to prevent duplicate API calls
  final Set<String> _viewedPostIds = {};

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get feedMode => _feedMode;
  String? get error => _error;
  List<Map<String, dynamic>> get trending => _trending;

  // Trending posts getters
  List<PostModel> get trendingPosts => _trendingPosts;
  bool get isLoadingTrending => _isLoadingTrending;
  bool get hasMoreTrending => _hasMoreTrending;
  String get trendingTimeWindow => _trendingTimeWindow;
  String get trendingScope => _trendingScope;

  /// Load feed (reset) — cache-first: show cached instantly, refresh in background
  Future<void> loadFeed({String? mode}) async {
    if (mode != null) _feedMode = mode;
    _page = 1;
    _nextCursor = null;
    _error = null;

    // 1) Show cached feed instantly (stale is fine for first paint)
    final cacheKey = 'feed_$_feedMode';
    final cached = CacheService.getStale(cacheKey);
    if (cached != null && cached is List && _posts.isEmpty) {
      try {
        _posts = cached.map((p) => PostModel.fromJson((p as Map<String, dynamic>?) ?? {})).toList();
        _isLoading = false;
        notifyListeners();
      } catch (_) {
        // Cache parse failed — fall through to network
      }
    }

    // 2) Always fetch fresh data from API
    _isLoading = _posts.isEmpty; // only show loader if no cached data
    if (_isLoading) notifyListeners();

    final res = await ApiService.getFeed(mode: _feedMode, page: 1);
    if (res.isSuccess) {
      _posts = res.posts;
      _hasMore = res.hasMore;
      _nextCursor = res.nextCursor;
      _page = 2;
      // 3) Save fresh data to cache
      CacheService.put(cacheKey, res.posts.map((p) => p.toJson()).toList());
    } else {
      _error = res.error;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load more — prefers cursor if available, falls back to page
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    final res = await ApiService.getFeed(mode: _feedMode, page: _page, cursor: _nextCursor);
    if (res.isSuccess) {
      if (res.posts.isNotEmpty) {
        _posts.addAll(res.posts);
        _page++;
      }
      _hasMore = res.hasMore;
      _nextCursor = res.nextCursor;
    } else {
      _error = res.error ?? 'Failed to load more posts';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Change feed mode
  void setFeedMode(String mode) {
    if (_feedMode != mode && !_isLoading) {
      _feedMode = mode;
      loadFeed();
    }
  }

  /// Toggle like
  Future<void> toggleLike(String postId) async {
    if (_likeInProgress.contains(postId)) return; // Prevent double-tap
    _likeInProgress.add(postId);

    // Find post in _posts or _trendingPosts
    var idx = _posts.indexWhere((p) => p.id == postId);
    final isTrending = idx == -1;
    if (isTrending) idx = _trendingPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) { _likeInProgress.remove(postId); return; }

    final list = isTrending ? _trendingPosts : _posts;
    final post = list[idx];
    final newLiked = !post.isLiked;
    final newCount = newLiked ? post.likesCount + 1 : post.likesCount - 1;

    list[idx] = PostModel(
      id: post.id,
      author: post.author,
      content: post.content,
      images: post.images,
      video: post.video,
      mood: post.mood,
      hashtags: post.hashtags,
      mentions: post.mentions,
      visibility: post.visibility,
      latitude: post.latitude,
      longitude: post.longitude,
      city: post.city,
      state: post.state,
      feedType: post.feedType,
      distanceKm: post.distanceKm,
      likesCount: newCount,
      commentsCount: post.commentsCount,
      sharesCount: post.sharesCount,
      viewsCount: post.viewsCount,
      viralScore: post.viralScore,
      isLiked: newLiked,
      isBookmarked: post.isBookmarked,
      createdAt: post.createdAt,
    );
    notifyListeners();

    // Server call
    final res = await ApiService.toggleLike(postId);
    if (!res.isSuccess) {
      // Revert on failure — re-find index in case list changed
      final revertIdx = list.indexWhere((p) => p.id == postId);
      if (revertIdx >= 0 && revertIdx < list.length) {
        list[revertIdx] = post;
        notifyListeners();
      }
    }
    _likeInProgress.remove(postId);
  }

  /// Toggle bookmark
  Future<void> toggleBookmark(String postId) async {
    if (_bookmarkInProgress.contains(postId)) return; // Prevent double-tap
    _bookmarkInProgress.add(postId);

    // Find post in _posts or _trendingPosts
    var idx = _posts.indexWhere((p) => p.id == postId);
    final isTrending = idx == -1;
    if (isTrending) idx = _trendingPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) { _bookmarkInProgress.remove(postId); return; }

    final list = isTrending ? _trendingPosts : _posts;
    final post = list[idx];
    final newBookmarked = !post.isBookmarked;

    list[idx] = PostModel(
      id: post.id,
      author: post.author,
      content: post.content,
      images: post.images,
      video: post.video,
      mood: post.mood,
      hashtags: post.hashtags,
      mentions: post.mentions,
      visibility: post.visibility,
      latitude: post.latitude,
      longitude: post.longitude,
      city: post.city,
      state: post.state,
      feedType: post.feedType,
      distanceKm: post.distanceKm,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      sharesCount: post.sharesCount,
      viewsCount: post.viewsCount,
      viralScore: post.viralScore,
      isLiked: post.isLiked,
      isBookmarked: newBookmarked,
      createdAt: post.createdAt,
    );
    notifyListeners();

    // Server call
    final res = await ApiService.togglePostBookmark(postId);
    if (!res.isSuccess) {
      // Revert on failure — re-find index in case list changed
      final revertIdx = list.indexWhere((p) => p.id == postId);
      if (revertIdx >= 0 && revertIdx < list.length) {
        list[revertIdx] = post;
        notifyListeners();
      }
    }
    _bookmarkInProgress.remove(postId);
  }

  /// Remove post from local list (after server-side delete)
  void removePost(String postId) {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  /// Create post
  /// Returns null on success, or an error message string on failure
  Future<String?> createPost({
    required String content,
    List<String>? images,
    String? video,
    String? mood,
  }) async {
    final res = await ApiService.createPost(
      content: content,
      images: images,
      video: video,
      mood: mood,
    );
    if (res.isSuccess && res.data != null) {
      _posts.insert(0, res.data!);
      notifyListeners();
      return null; // success
    }
    return res.errorMessage ?? 'Failed to create post';
  }

  /// Load viral/trending posts (reset) — cache-first
  Future<void> loadTrendingPosts({String? timeWindow, String? scope}) async {
    if (timeWindow != null) _trendingTimeWindow = timeWindow;
    if (scope != null) _trendingScope = scope;
    _trendingPage = 1;

    // Show cached trending instantly
    final cacheKey = 'trending_${_trendingTimeWindow}_$_trendingScope';
    final cached = CacheService.getStale(cacheKey);
    if (cached != null && cached is List && _trendingPosts.isEmpty) {
      try {
        _trendingPosts = cached.map((p) => PostModel.fromJson((p as Map<String, dynamic>?) ?? {})).toList();
        _isLoadingTrending = false;
        notifyListeners();
      } catch (_) {}
    }

    _isLoadingTrending = _trendingPosts.isEmpty;
    if (_isLoadingTrending) notifyListeners();

    final res = await ApiService.getTrendingPosts(
      page: 1,
      timeWindow: _trendingTimeWindow,
      scope: _trendingScope,
    );
    if (res.isSuccess && res.data != null) {
      _trendingPosts = res.data!;
      _hasMoreTrending = res.hasMore;
      _trendingPage = 2;
      CacheService.put(cacheKey, res.data!.map((p) => p.toJson()).toList(), maxAge: const Duration(minutes: 15));
    }

    _isLoadingTrending = false;
    notifyListeners();
  }

  /// Load more trending posts (pagination)
  Future<void> loadMoreTrending() async {
    if (_isLoadingTrending || !_hasMoreTrending) return;

    _isLoadingTrending = true;
    notifyListeners();

    final res = await ApiService.getTrendingPosts(
      page: _trendingPage,
      timeWindow: _trendingTimeWindow,
      scope: _trendingScope,
    );
    if (res.isSuccess && res.data != null) {
      _trendingPosts.addAll(res.data!);
      _hasMoreTrending = res.hasMore;
      _trendingPage++;
    } else {
      _error = res.errorMessage ?? 'Failed to load trending posts';
    }

    _isLoadingTrending = false;
    notifyListeners();
  }

  /// Record a post view (fire and forget, deduplicated per session)
  void recordView(String postId) {
    if (_viewedPostIds.contains(postId)) return;
    _viewedPostIds.add(postId);
    unawaited(ApiService.recordPostView(postId));
  }

  /// Record a post share
  Future<void> recordShare(String postId) async {
    await ApiService.recordPostShare(postId);
  }

  /// Load trending hashtags
  Future<void> loadTrending() async {
    final res = await ApiService.getTrendingHashtags();
    if (res.isSuccess && res.data != null) {
      _trending = res.data!;
      notifyListeners();
    }
  }
}
