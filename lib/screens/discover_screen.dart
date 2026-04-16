import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../services/location_service.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_utils.dart';
import 'user_profile_screen.dart';
import '../l10n/l10n_helper.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();
  List<UserModel> _nearbyUsers = [];
  bool _isLoadingUsers = false;

  // Find Friends search
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _debounce;

  // Radius slider
  double _radiusKm = 500.0;

  // Local/Global scope toggle (for Map & People tabs)
  bool _isGlobalScope = false;

  // Global feed posts
  List<PostModel> _globalPosts = [];
  bool _isLoadingGlobal = false;

  // Global users (outside radius)
  List<UserModel> _globalUsers = [];
  bool _isLoadingGlobalUsers = false;

  // Suggest Friends
  List<Map<String, dynamic>> _suggestedFriends = [];
  bool _isLoadingSuggestions = false;
  final Set<String> _followedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSavedRadius();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadTrending();
      context.read<FeedProvider>().loadTrendingPosts();
      _loadNearbyUsers();
      _loadSuggestedFriends();
      _loadGlobalFeed();
      _loadGlobalUsers();
    });
  }

  Future<void> _loadSavedRadius() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble('discover_radius_km');
    if (saved != null && mounted) {
      final clamped = saved.clamp(100.0, 500.0);
      setState(() => _radiusKm = clamped);
      LocationService.nearfoRadiusKm = clamped;
    }
  }

  Future<void> _saveRadius(double value) async {
    LocationService.nearfoRadiusKm = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('discover_radius_km', value);
  }

  Future<void> _loadNearbyUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    final res = await ApiService.searchNearbyUsers('', radiusKm: _radiusKm, scope: _isGlobalScope ? 'global' : null);
    if (mounted && res.isSuccess && res.data != null) {
      setState(() => _nearbyUsers = res.data!);
    }
    if (mounted) setState(() => _isLoadingUsers = false);
  }

  Future<void> _loadSuggestedFriends() async {
    if (!mounted) return;
    setState(() => _isLoadingSuggestions = true);
    // Pass user's selected radius so backend respects dynamic radius
    final auth = context.read<AuthProvider>();
    final feedPref = auth.user?.feedPreference;
    final res = await ApiService.getSuggestedFriends(limit: 50, mode: feedPref, radiusKm: _radiusKm);
    if (mounted && res.isSuccess && res.data != null) {
      setState(() => _suggestedFriends = res.data!);
    }
    if (mounted) setState(() => _isLoadingSuggestions = false);
  }

  /// Load global feed posts — ALL posts worldwide (no radius filter)
  Future<void> _loadGlobalFeed() async {
    if (!mounted) return;
    setState(() => _isLoadingGlobal = true);
    final res = await ApiService.getFeed(mode: 'global', radiusKm: 0);
    if (mounted && res.isSuccess) {
      setState(() => _globalPosts = res.posts);
    }
    if (mounted) setState(() => _isLoadingGlobal = false);
  }

  /// Load global users — ALL users worldwide (no radius filter)
  Future<void> _loadGlobalUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingGlobalUsers = true);
    final res = await ApiService.searchNearbyUsers('', radiusKm: 0, scope: 'global');
    if (mounted && res.isSuccess && res.data != null) {
      setState(() => _globalUsers = res.data!);
    }
    if (mounted) setState(() => _isLoadingGlobalUsers = false);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = null;
    if (query.trim().isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchUsers(query));
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });
    final res = await ApiService.searchUsers(query.trim());
    if (mounted && res.isSuccess && res.data != null) {
      setState(() {
        _searchResults = res.data!;
        _isSearching = false;
      });
    } else if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _toggleFollow(String userId, {bool isSuggested = false}) async {
    final res = await ApiService.toggleFollow(userId);
    if (res.isSuccess && mounted) {
      setState(() {
        if (_followedIds.contains(userId)) {
          _followedIds.remove(userId);
        } else {
          _followedIds.add(userId);
        }
      });
    }
  }

  void _navigateToProfile(String handle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(handle: handle)),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _mapController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final feed = context.watch<FeedProvider>();
    final user = auth.user;

    final hasLocation = user?.latitude != null && user?.longitude != null;
    final userLat = user?.latitude ?? 20.5937; // India center as fallback
    final userLng = user?.longitude ?? 78.9629;

    return SafeArea(
      child: Column(
        children: [
          // Header with Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => NearfoColors.primaryGradient.createShader(bounds),
                  child: Text(context.l10n.discoverTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: NearfoColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NearfoColors.border.withOpacity(0.5), width: 1.5),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [NearfoColors.primary.withOpacity(0.03), NearfoColors.accent.withOpacity(0.03)],
                    ),
                    boxShadow: [
                      BoxShadow(color: NearfoColors.primary.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4), spreadRadius: 2),
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: NearfoColors.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: context.l10n.discoverSearchHint,
                      hintStyle: TextStyle(color: NearfoColors.textDim, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: NearfoColors.textMuted, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showSearchResults = false;
                                  _searchResults = [];
                                });
                              },
                              icon: Icon(Icons.close, color: NearfoColors.textMuted, size: 20),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Show search results overlay OR tabs
          if (_showSearchResults)
            Expanded(child: _buildSearchResults())
          else ...[
            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: NearfoColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NearfoColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: NearfoColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: Colors.white,
                unselectedLabelColor: NearfoColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                dividerHeight: 0,
                isScrollable: false,
                tabs: [
                  Tab(text: context.l10n.discoverTabViral),
                  Tab(text: context.l10n.discoverTabGlobal),
                  Tab(text: context.l10n.discoverTabSuggested),
                  Tab(text: context.l10n.discoverTabMap),
                  Tab(text: context.l10n.discoverTabTrending),
                  Tab(text: context.l10n.discoverTabPeople),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // VIRAL POSTS TAB
                  _buildViralPostsTab(feed),

                  // GLOBAL FEED TAB
                  _buildGlobalTab(),

                  // SUGGESTED FRIENDS TAB
                  _buildSuggestedFriendsTab(),

                  // MAP TAB
                  _buildMapTab(userLat, userLng),

                  // TRENDING HASHTAGS TAB
                  _buildTrendingTab(feed),

                  // PEOPLE TAB
                  _buildPeopleTab(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== VIRAL POSTS TAB ==========
  Widget _buildViralPostsTab(FeedProvider feed) {
    return Column(
      children: [
        // Time window filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: NearfoColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(context.l10n.discoverViralNow, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              // Time filter dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NearfoColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: NearfoColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: feed.trendingTimeWindow,
                    isDense: true,
                    dropdownColor: NearfoColors.card,
                    style: TextStyle(color: NearfoColors.text, fontSize: 12, fontWeight: FontWeight.w600),
                    items: [
                      DropdownMenuItem(value: '1h', child: Text(context.l10n.discover1Hour)),
                      DropdownMenuItem(value: '6h', child: Text(context.l10n.discover6Hours)),
                      DropdownMenuItem(value: '24h', child: Text(context.l10n.discover24Hours)),
                      DropdownMenuItem(value: '7d', child: Text(context.l10n.discover7Days)),
                      DropdownMenuItem(value: '30d', child: Text(context.l10n.discover30Days)),
                    ],
                    onChanged: (val) {
                      if (val != null) feed.loadTrendingPosts(timeWindow: val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Scope toggle
              GestureDetector(
                onTap: () {
                  final newScope = feed.trendingScope == 'all' ? 'local' : 'all';
                  feed.loadTrendingPosts(scope: newScope);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: feed.trendingScope == 'local' ? NearfoColors.primaryGradient : null,
                    color: feed.trendingScope == 'local' ? null : NearfoColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: feed.trendingScope == 'local' ? Colors.transparent : NearfoColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: feed.trendingScope == 'local' ? Colors.white : NearfoColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        feed.trendingScope == 'local' ? context.l10n.discoverLocal : context.l10n.discoverGlobal,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: feed.trendingScope == 'local' ? Colors.white : NearfoColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Posts list
        Expanded(
          child: feed.isLoadingTrending && feed.trendingPosts.isEmpty
              ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
              : feed.trendingPosts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department, size: 56, color: NearfoColors.textDim.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text(context.l10n.discoverNoViral, style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(context.l10n.discoverNoViralDesc, style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: NearfoColors.primary,
                      onRefresh: () => feed.loadTrendingPosts(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: feed.trendingPosts.length + (feed.hasMoreTrending ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= feed.trendingPosts.length) {
                            feed.loadMoreTrending();
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(color: NearfoColors.primary)),
                            );
                          }
                          final post = feed.trendingPosts[i];
                          // Record view when post appears on screen
                          feed.recordView(post.id);
                          return Column(
                            children: [
                              if (i == 0) _buildViralRankBadge(i + 1, post),
                              PostCard(
                                post: post,
                                onLike: () => feed.toggleLike(post.id),
                                onComment: () => CommentsSheet.show(
                                  context,
                                  postId: post.id,
                                  commentsCount: post.commentsCount,
                                ),
                                onShare: () {
                                  feed.recordShare(post.id);
                                  ShareUtils.sharePost(
                                    postId: post.id,
                                    content: post.content,
                                    authorName: post.author.name.isNotEmpty
                                        ? post.author.name
                                        : '@${post.author.handle}',
                                  );
                                },
                                onBookmark: () => feed.toggleBookmark(post.id),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ========== GLOBAL TAB ==========
  Widget _buildGlobalTab() {
    return Column(
      children: [
        // Header — no slider needed, global = whole world
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: NearfoColors.secondaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.public, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('Global Feed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: NearfoColors.secondaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Worldwide', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Global posts + users
        Expanded(
          child: _isLoadingGlobal && _globalPosts.isEmpty
              ? Center(child: CircularProgressIndicator(color: NearfoColors.accent))
              : _globalPosts.isEmpty && _globalUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 56, color: NearfoColors.textDim.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text('No global content yet', style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('Posts & people from around the world will appear here', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: NearfoColors.accent,
                      onRefresh: () async {
                        await Future.wait([_loadGlobalFeed(), _loadGlobalUsers()]);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: (_globalUsers.isNotEmpty ? 1 : 0) + _globalPosts.length,
                        itemBuilder: (ctx, i) {
                          // First item: horizontal scroll of global users
                          if (_globalUsers.isNotEmpty && i == 0) {
                            return _buildGlobalUsersRow();
                          }
                          final postIndex = _globalUsers.isNotEmpty ? i - 1 : i;
                          if (postIndex >= _globalPosts.length) return const SizedBox();
                          final post = _globalPosts[postIndex];
                          return PostCard(
                            post: post,
                            onLike: () async {
                              await ApiService.toggleLike(post.id);
                              _loadGlobalFeed();
                            },
                            onComment: () => CommentsSheet.show(
                              context,
                              postId: post.id,
                              commentsCount: post.commentsCount,
                            ),
                            onShare: () {
                              ShareUtils.sharePost(
                                postId: post.id,
                                content: post.content,
                                authorName: post.author.name.isNotEmpty
                                    ? post.author.name
                                    : '@${post.author.handle}',
                              );
                            },
                            onBookmark: () async {
                              await ApiService.togglePostBookmark(post.id);
                              _loadGlobalFeed();
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  /// Horizontal row of global users (outside radius)
  Widget _buildGlobalUsersRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              Icon(Icons.people, color: NearfoColors.accent, size: 16),
              const SizedBox(width: 6),
              Text('People worldwide', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: NearfoColors.accent)),
              const Spacer(),
              Text('${_globalUsers.length} found', style: TextStyle(color: NearfoColors.textDim, fontSize: 11)),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _globalUsers.length,
            itemBuilder: (ctx, i) {
              final u = _globalUsers[i];
              final initial = u.name.isNotEmpty ? u.name[0].toUpperCase() : '?';
              return GestureDetector(
                onTap: () => _navigateToProfile(u.handle),
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      (u.avatarUrl ?? '').isNotEmpty
                          ? CircleAvatar(
                              radius: 28,
                              backgroundImage: CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(u.avatarUrl!)),
                              backgroundColor: NearfoColors.accent,
                            )
                          : CircleAvatar(
                              radius: 28,
                              backgroundColor: NearfoColors.accent,
                              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        u.name.split(' ').first,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Divider(color: NearfoColors.border, height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildViralRankBadge(int rank, PostModel post) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NearfoColors.primary.withOpacity(0.15),
            NearfoColors.accent.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NearfoColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text(
            'Top Viral Post',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: NearfoColors.primary,
            ),
          ),
          const Spacer(),
          Text(
            '${post.viewsCount} views  ·  ${post.likesCount} likes  ·  ${post.sharesCount} shares',
            style: TextStyle(color: NearfoColors.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ========== SEARCH RESULTS ==========
  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator(color: NearfoColors.primary));
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 56, color: NearfoColors.textDim.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('No users found', style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Try a different name or handle', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
        final u = _searchResults[i];
        final userId = u['_id']?.toString() ?? '';
        final isFollowing = u['isFollowing'] == true || _followedIds.contains(userId);
        return _buildUserCard(
          name: (u['name'] as String?) ?? '',
          handle: (u['handle'] as String?) ?? '',
          avatarUrl: u['avatarUrl'] as String?,
          city: (u['city'] as String?) ?? '',
          isVerified: (u['isVerified'] as bool?) ?? false,
          nearfoScore: (u['nearfoScore'] as int?) ?? 0,
          distanceKm: null,
          isFollowing: isFollowing,
          userId: userId,
          onFollow: () => _toggleFollow(userId),
          onTap: () => _navigateToProfile((u['handle'] as String?) ?? ''),
        );
      },
    );
  }

  // ========== SUGGESTED FRIENDS TAB ==========
  Widget _buildSuggestedFriendsTab() {
    return Column(
      children: [
        // Radius slider for suggestions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NearfoColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('📍 Distance Range', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: NearfoColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: NearfoColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${_radiusKm.round()} km',
                        style: TextStyle(color: NearfoColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: NearfoColors.primary,
                    inactiveTrackColor: NearfoColors.border,
                    thumbColor: NearfoColors.primary,
                    overlayColor: NearfoColors.primary.withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                    activeTickMarkColor: NearfoColors.primaryLight,
                    inactiveTickMarkColor: NearfoColors.textDim,
                  ),
                  child: Slider(
                    min: 100,
                    max: 500,
                    divisions: 4,
                    value: _radiusKm,
                    label: '${_radiusKm.round()}km',
                    onChanged: (val) {
                      setState(() => _radiusKm = val);
                    },
                    onChangeEnd: (val) {
                      _saveRadius(val);
                      _loadSuggestedFriends();
                      _loadNearbyUsers();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('100', style: TextStyle(color: NearfoColors.textDim, fontSize: 10)),
                      Text('200', style: TextStyle(color: NearfoColors.textDim, fontSize: 10)),
                      Text('300', style: TextStyle(color: NearfoColors.textDim, fontSize: 10)),
                      Text('400', style: TextStyle(color: NearfoColors.textDim, fontSize: 10)),
                      Text('500', style: TextStyle(color: NearfoColors.textDim, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Suggestions list
        Expanded(
          child: _isLoadingSuggestions
              ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
              : _suggestedFriends.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: NearfoColors.textDim.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text('No suggestions yet', style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('No people found within ${_radiusKm.round()}km', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: NearfoColors.primary,
                      onRefresh: _loadSuggestedFriends,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _suggestedFriends.length + 1, // +1 for header
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: NearfoColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.person_add, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Suggested Friends', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        Text('People within ${_radiusKm.round()}km you might know', style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final u = _suggestedFriends[i - 1];
                          final userId = u['_id']?.toString() ?? '';
                          final isFollowing = _followedIds.contains(userId);
                          final distanceKm = u['distanceKm'];
                          return _buildUserCard(
                            name: (u['name'] as String?) ?? '',
                            handle: (u['handle'] as String?) ?? '',
                            avatarUrl: u['avatarUrl'] as String?,
                            city: (u['city'] as String?) ?? '',
                            isVerified: (u['isVerified'] as bool?) ?? false,
                            nearfoScore: (u['nearfoScore'] as int?) ?? 0,
                            distanceKm: distanceKm is num ? distanceKm.toDouble() : null,
                            isFollowing: isFollowing,
                            userId: userId,
                            onFollow: () => _toggleFollow(userId, isSuggested: true),
                            onTap: () => _navigateToProfile((u['handle'] as String?) ?? ''),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ========== REUSABLE USER CARD ==========
  Widget _buildUserCard({
    required String name,
    required String handle,
    String? avatarUrl,
    required String city,
    required bool isVerified,
    required int nearfoScore,
    double? distanceKm,
    required bool isFollowing,
    required String userId,
    required VoidCallback onFollow,
    required VoidCallback onTap,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NearfoColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NearfoColors.border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [NearfoColors.primary.withOpacity(0.04), NearfoColors.accent.withOpacity(0.02)],
          ),
          boxShadow: [
            BoxShadow(color: NearfoColors.primary.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: 1),
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            avatarUrl != null && avatarUrl.isNotEmpty
                ? CircleAvatar(
                    radius: 24,
                    backgroundImage: CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatarUrl)),
                    backgroundColor: NearfoColors.primary,
                  )
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: NearfoColors.primary,
                    child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                  ),
            const SizedBox(width: 12),
            // Name, handle, location/distance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, color: NearfoColors.accent, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(child: Text('@$handle', style: TextStyle(color: NearfoColors.textDim, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      if (distanceKm != null) ...[
                        Text(' · ', style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                        Icon(Icons.location_on, size: 12, color: NearfoColors.primary.withOpacity(0.7)),
                        Text(
                          distanceKm < 1 ? '< 1 km' : '${distanceKm.toStringAsFixed(0)} km',
                          style: TextStyle(color: NearfoColors.primary.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ] else if (city.isNotEmpty) ...[
                        Flexible(child: Text(' · $city', style: TextStyle(color: NearfoColors.textDim, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Follow button
            GestureDetector(
              onTap: onFollow,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isFollowing ? 16 : 16, vertical: isFollowing ? 8 : 6),
                decoration: BoxDecoration(
                  gradient: isFollowing ? null : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                  color: isFollowing ? NearfoColors.bg : null,
                  borderRadius: BorderRadius.circular(20),
                  border: isFollowing ? Border.all(color: NearfoColors.border) : null,
                  boxShadow: isFollowing ? null : [
                    BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 10, spreadRadius: 0, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: isFollowing ? NearfoColors.textMuted : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== MAP TAB ==========
  Widget _buildMapTab(double userLat, double userLng) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(userLat, userLng),
              initialZoom: 10,
            ),
            children: [
              TileLayer(
                urlTemplate: NearfoConfig.mapTileUrl,
                userAgentPackageName: 'com.nearfo.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(userLat, userLng),
                    radius: _radiusKm * 1000, // Convert km to meters
                    useRadiusInMeter: true,
                    color: (_isGlobalScope ? NearfoColors.accent : NearfoColors.primary).withOpacity(0.08),
                    borderColor: (_isGlobalScope ? NearfoColors.accent : NearfoColors.primary).withOpacity(0.3),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(userLat, userLng),
                    width: 50, height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: NearfoColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: NearfoColors.primary.withOpacity(0.4), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                  ),
                  ..._nearbyUsers.map((u) => Marker(
                    point: LatLng(u.latitude, u.longitude),
                    width: 40, height: 40,
                    child: GestureDetector(
                      onTap: () => _showUserBottomSheet(u),
                      child: Container(
                        decoration: BoxDecoration(
                          color: NearfoColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(u.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              decoration: BoxDecoration(
                color: NearfoColors.bg.withOpacity(0.93),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NearfoColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar, color: _isGlobalScope ? NearfoColors.accent : NearfoColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text('${_radiusKm.round()}km', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 8),
                      // Local/Global toggle
                      GestureDetector(
                        onTap: () {
                          setState(() => _isGlobalScope = !_isGlobalScope);
                          _loadNearbyUsers();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: _isGlobalScope ? NearfoColors.secondaryGradient : NearfoColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isGlobalScope ? Icons.public : Icons.location_on,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _isGlobalScope ? 'Global' : 'Local',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text('100', style: TextStyle(fontSize: 10, color: NearfoColors.textMuted)),
                      const SizedBox(width: 4),
                      Text('500', style: TextStyle(fontSize: 10, color: NearfoColors.textMuted)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _isGlobalScope ? NearfoColors.accent : NearfoColors.primary,
                      inactiveTrackColor: (_isGlobalScope ? NearfoColors.accent : NearfoColors.primary).withOpacity(0.15),
                      thumbColor: _isGlobalScope ? NearfoColors.accent : NearfoColors.primary,
                      overlayColor: (_isGlobalScope ? NearfoColors.accent : NearfoColors.primary).withOpacity(0.1),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      min: 100,
                      max: 500,
                      divisions: 4,
                      value: _radiusKm,
                      label: '${_radiusKm.round()}km',
                      onChanged: (val) {
                        setState(() => _radiusKm = val);
                      },
                      onChangeEnd: (val) {
                        _saveRadius(val);
                        _loadNearbyUsers();
                        _loadSuggestedFriends();
                        _loadGlobalFeed();
                        _loadGlobalUsers();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== TRENDING TAB ==========
  Widget _buildTrendingTab(FeedProvider feed) {
    if (feed.trending.isEmpty) {
      return Center(child: Text('No trending hashtags yet', style: TextStyle(color: NearfoColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: feed.trending.length,
      itemBuilder: (ctx, i) {
        final tag = feed.trending[i];
        final tagName = (tag['_id'] as String?) ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NearfoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NearfoColors.border.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/hashtag', arguments: tag['_id']?.toString() ?? ''),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: NearfoColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [NearfoColors.primary.withOpacity(0.2), NearfoColors.primary.withOpacity(0.08)]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: NearfoColors.primary.withOpacity(0.35)),
                              boxShadow: [BoxShadow(color: NearfoColors.primary.withOpacity(0.15), blurRadius: 6)],
                            ),
                            child: Text('#$tagName', style: TextStyle(color: NearfoColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${(tag['count'] as int?) ?? 0} posts · ${(tag['totalLikes'] as int?) ?? 0} likes',
                        style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: NearfoColors.textDim, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========== PEOPLE TAB ==========
  Widget _buildPeopleTab() {
    return Column(
      children: [
        // Radius slider for people
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NearfoColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar, color: NearfoColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Text('Within ${_radiusKm.round()}km', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    Text('100', style: TextStyle(fontSize: 10, color: NearfoColors.textMuted)),
                    const SizedBox(width: 4),
                    Text('500', style: TextStyle(fontSize: 10, color: NearfoColors.textMuted)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: NearfoColors.primary,
                    inactiveTrackColor: NearfoColors.primary.withOpacity(0.15),
                    thumbColor: NearfoColors.primary,
                    overlayColor: NearfoColors.primary.withOpacity(0.1),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    min: 100,
                    max: 500,
                    divisions: 4,
                    value: _radiusKm,
                    label: '${_radiusKm.round()}km',
                    onChanged: (val) {
                      setState(() => _radiusKm = val);
                    },
                    onChangeEnd: (val) {
                      _saveRadius(val);
                      _loadNearbyUsers();
                      _loadSuggestedFriends();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // People list
        Expanded(
          child: _isLoadingUsers
              ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
              : _nearbyUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: NearfoColors.textDim.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text('No people found', style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('No one within ${_radiusKm.round()}km yet', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: NearfoColors.primary,
                      onRefresh: _loadNearbyUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _nearbyUsers.length,
                        itemBuilder: (ctx, i) {
                          final u = _nearbyUsers[i];
                          return _buildUserCard(
                            name: u.name,
                            handle: u.handle,
                            avatarUrl: u.avatarUrl,
                            city: u.city ?? '',
                            isVerified: u.isVerified,
                            nearfoScore: u.nearfoScore,
                            distanceKm: null,
                            isFollowing: _followedIds.contains(u.id),
                            userId: u.id,
                            onFollow: () => _toggleFollow(u.id),
                            onTap: () => _navigateToProfile(u.handle),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showUserBottomSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: NearfoColors.primary,
              child: Text(user.initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            Text(user.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('@${user.handle}', style: TextStyle(color: NearfoColors.textMuted)),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(user.bio!, style: TextStyle(color: NearfoColors.textMuted, fontSize: 14), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statColumn('${user.postsCount}', 'Posts'),
                const SizedBox(width: 32),
                _statColumn('${user.followers}', 'Followers'),
                const SizedBox(width: 32),
                _statColumn('${user.nearfoScore}', 'Score'),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _navigateToProfile(user.handle);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  gradient: NearfoColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
      ],
    );
  }
}
