import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../widgets/post_card.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/share_utils.dart';
import 'followers_following_screen.dart';
import '../../services/ad_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../utils/json_helpers.dart';
import '../stories/stories_screen.dart';

/// Screen to view another user's public profile
class UserProfileScreen extends StatefulWidget {
  final String handle;
  final String? userId;

  const UserProfileScreen({super.key, required this.handle, this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  bool _isBlocked = false;
  bool _amIBlocked = false;
  int _followersCount = 0;
  int _followingCount = 0;
  String? _loadError;

  // Story ring
  Map<String, dynamic>? _storyGroup;
  bool _hasActiveStory = false;

  // User posts
  List<PostModel> _posts = [];
  bool _postsLoading = false;
  String? _postsError;

  @override
  void initState() {
    super.initState();
    // Record action for non-intrusive interstitial
    AdService.instance.recordAction();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      ApiResponse<Map<String, dynamic>> res;
      // Strip @ prefix if present (handles come in various formats)
      final cleanHandle = widget.handle.trim().replaceFirst(RegExp(r'^@'), '');
      final hasHandle = cleanHandle.isNotEmpty;
      final cleanUserId = (widget.userId ?? '').trim();
      final hasUserId = cleanUserId.isNotEmpty;

      debugPrint('[UserProfile] Loading profile: handle="$cleanHandle" userId="$cleanUserId"');

      // Try ALL methods — handle, userId, then handle-as-id fallback
      if (hasHandle) {
        res = await ApiService.getUserProfile(cleanHandle);
        if (!res.isSuccess && hasUserId) {
          debugPrint('[UserProfile] handle lookup failed (${res.errorMessage}), trying userId=$cleanUserId');
          res = await ApiService.getUserProfileById(cleanUserId);
        }
        // Last resort: maybe the "handle" is actually an ID
        if (!res.isSuccess && cleanHandle.length == 24 && RegExp(r'^[a-f\d]{24}$', caseSensitive: false).hasMatch(cleanHandle)) {
          debugPrint('[UserProfile] trying handle as userId');
          res = await ApiService.getUserProfileById(cleanHandle);
        }
      } else if (hasUserId) {
        res = await ApiService.getUserProfileById(cleanUserId);
        // Fallback: try userId as handle (some callers swap the fields)
        if (!res.isSuccess) {
          debugPrint('[UserProfile] userId lookup failed (${res.errorMessage}), trying as handle');
          res = await ApiService.getUserProfile(cleanUserId);
        }
      } else {
        res = ApiResponse<Map<String, dynamic>>.error('No handle or userId provided');
      }

      if (!mounted) return;

      if (res.isSuccess && res.data != null) {
        final data = res.data!;
        setState(() {
          _userData = data;
          _isFollowing = ((data['isFollowing'] as bool?) ?? false);
          _isBlocked = ((data['isBlocked'] as bool?) ?? false);
          _amIBlocked = ((data['amIBlocked'] as bool?) ?? false);
          _followersCount = (((data['followersCount'] as int?) ?? (data['followers'] as int?)) ?? 0);
          _followingCount = (((data['followingCount'] as int?) ?? (data['following'] as int?)) ?? 0);
          _loading = false;
        });
        _loadUserPosts();
        _loadUserStories();
      } else {
        debugPrint('[UserProfile] All lookups failed: handle="$cleanHandle", userId="$cleanUserId", error=${res.errorMessage}');
        final errMsg = res.errorMessage ?? '';
        setState(() {
          _loading = false;
          _loadError = errMsg.contains('Circuit breaker') || errMsg.contains('request cancelled')
              ? 'Server temporarily unavailable. Tap retry.'
              : errMsg;
        });
      }
    } catch (e) {
      debugPrint('[UserProfile] Error: $e');
      if (mounted) {
        final errStr = e.toString();
        setState(() {
          _loading = false;
          _loadError = errStr.contains('Circuit breaker') || errStr.contains('request cancelled')
              ? 'Server temporarily unavailable. Tap retry.'
              : errStr;
        });
      }
    }
  }

  Future<void> _loadUserStories() async {
    final uid = ((_userData?['_id'] as String?) ?? (_userData?['id'] as String?)) ?? widget.userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final res = await ApiService.getUserStories(uid);
      if (res.isSuccess && res.data != null && mounted) {
        final data = res.data!;
        final hasStories = data['hasStories'] == true;
        final group = data['storyGroup'];
        setState(() {
          _hasActiveStory = hasStories;
          _storyGroup = group is Map<String, dynamic> ? group : null;
        });
      }
    } catch (e) {
      debugPrint('[UserProfile] Stories error: $e');
    }
  }

  void _openStoryViewer() {
    if (_storyGroup == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StoriesScreen(
          storyGroups: [_storyGroup!],
          initialIndex: 0,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ).then((_) {
      if (mounted) _loadUserStories(); // Refresh story state after viewing
    });
  }

  Future<void> _loadUserPosts() async {
    final uid = ((_userData?['_id'] as String?) ?? (_userData?['id'] as String?)) ?? widget.userId;
    final handle = ((_userData?['handle'] as String?) ?? widget.handle);
    if (uid == null && handle.isEmpty) return;
    if (!mounted) return;
    setState(() { _postsLoading = true; _postsError = null; });

    try {
      // 1. Check if profile API already returned posts inline
      final inlinePosts = _userData?['posts'];
      if (inlinePosts is List && inlinePosts.isNotEmpty) {
        debugPrint('[UserProfile] Found ${inlinePosts.length} inline posts from profile API');
        setState(() {
          _posts = inlinePosts
              .map((p) => PostModel.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList();
          _postsLoading = false;
        });
        return;
      }

      // 2. Try loading by userId (tries multiple endpoint patterns internally)
      if (uid != null && uid.isNotEmpty) {
        debugPrint('[UserProfile] Loading posts for uid=$uid');
        final res = await ApiService.getUserPosts(uid);
        if (!mounted) return;
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          setState(() {
            _posts = res.data!;
            _postsLoading = false;
          });
          return;
        }
      }

      // 3. Try loading by handle if different from uid
      if (handle.isNotEmpty && handle != uid) {
        debugPrint('[UserProfile] Trying posts by handle=$handle');
        final res = await ApiService.getUserPosts(handle);
        if (!mounted) return;
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          setState(() {
            _posts = res.data!;
            _postsLoading = false;
          });
          return;
        }
      }

      debugPrint('[UserProfile] No posts found for uid=$uid handle=$handle');
      if (mounted) setState(() => _postsLoading = false);
    } catch (e) {
      debugPrint('[UserProfile] Load posts error: $e');
      if (mounted) {
        setState(() {
          _postsLoading = false;
          _postsError = 'Could not load posts. Tap to retry.';
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final uid = ((_userData?['_id'] as String?) ?? (_userData?['id'] as String?)) ?? widget.userId;
    if (uid == null) return;
    setState(() => _followLoading = true);

    // Optimistic
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !_isFollowing;
      _followersCount += _isFollowing ? 1 : -1;
    });

    final res = await ApiService.toggleFollow(uid);
    if (res.isSuccess && res.data != null) {
      setState(() {
        _isFollowing = ((res.data!['isFollowing'] as bool?) ?? _isFollowing);
        _followersCount = (((res.data!['followersCount'] as num?) ?? _followersCount).toInt());
        _followLoading = false;
      });
    } else {
      // Revert on failure
      setState(() {
        _isFollowing = wasFollowing;
        _followersCount += wasFollowing ? 1 : -1;
        _followLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status'), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }

  Future<void> _toggleBlock() async {
    final uid = ((_userData?['_id'] as String?) ?? (_userData?['id'] as String?)) ?? widget.userId;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _isBlocked ? 'Unblock User?' : 'Block User?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _isBlocked
              ? 'They will be able to see your profile and send you messages again.'
              : 'They won\'t be able to see your profile, posts, or send you messages. They won\'t be notified.',
          style: TextStyle(color: NearfoColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _isBlocked ? 'Unblock' : 'Block',
              style: TextStyle(color: _isBlocked ? NearfoColors.success : NearfoColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.toggleBlock(uid);
    if (res.isSuccess && res.data != null) {
      setState(() {
        _isBlocked = ((res.data!['isBlocked'] as bool?) ?? false);
        if (_isBlocked) _isFollowing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBlocked ? 'User blocked' : 'User unblocked'),
            backgroundColor: _isBlocked ? NearfoColors.danger : NearfoColors.success,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Failed to update block status'),
          backgroundColor: NearfoColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _reportUser() async {
    final uid = ((_userData?['_id'] as String?) ?? (_userData?['id'] as String?)) ?? widget.userId;
    if (uid == null) return;

    final reasons = [
      'Spam or fake account',
      'Harassment or bullying',
      'Inappropriate content',
      'Impersonation',
      'Scam or fraud',
      'Other',
    ];

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Report User', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Why are you reporting this user?', style: TextStyle(color: NearfoColors.textMuted, fontSize: 14)),
            const SizedBox(height: 12),
            ...reasons.map((r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r, style: TextStyle(color: NearfoColors.text, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, r),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
          ),
        ],
      ),
    );

    if (reason == null || !mounted) return;

    final res = await ApiService.reportContent(contentType: 'user', contentId: uid, reason: reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.isSuccess ? 'Report submitted. We\'ll review it shortly.' : 'Failed to submit report'),
          backgroundColor: res.isSuccess ? NearfoColors.success : NearfoColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUser = context.read<AuthProvider>().user;
    final isMe = myUser?.handle == widget.handle || myUser?.id == widget.userId;

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${_userData?['handle'] ?? widget.handle}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!isMe)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: NearfoColors.textMuted),
              color: NearfoColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'block') _toggleBlock();
                if (value == 'report') _reportUser();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(_isBlocked ? Icons.check_circle_outline : Icons.block, color: _isBlocked ? NearfoColors.success : NearfoColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Text(_isBlocked ? 'Unblock User' : 'Block User', style: TextStyle(color: _isBlocked ? NearfoColors.success : NearfoColors.danger)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: NearfoColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Text('Report User', style: TextStyle(color: NearfoColors.warning)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _userData == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_outlined, size: 48, color: NearfoColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        _loadError ?? 'User not found',
                        style: TextStyle(color: NearfoColors.textMuted, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          ApiService.resetCircuitBreaker();
                          _loadProfile();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(foregroundColor: NearfoColors.primary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: NearfoColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildProfileCard(isMe),
                        const SizedBox(height: 16),
                        _buildPostsSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileCard(bool isMe) {
    final name = (((_userData?['name'] as String?) ?? '')).toString();
    final handle = (((_userData?['handle'] as String?) ?? widget.handle)).toString();
    final bio = (((_userData?['bio'] as String?) ?? '')).toString();
    final avatarUrl = (((_userData?['avatarUrl'] as String?) ?? '')).toString();
    final city = (((_userData?['city'] as String?) ?? '')).toString();
    final state = (((_userData?['state'] as String?) ?? '')).toString();
    final isVerified = ((_userData?['isVerified'] as bool?) ?? false);
    final nearfoScore = ((_userData?['nearfoScore'] as int?) ?? 0);
    final postsCount = ((_userData?['postsCount'] as int?) ?? 0);
    final displayName = name.isNotEmpty ? name : '@$handle';
    final displayLocation = city.isNotEmpty && state.isNotEmpty
        ? '$city, $state'
        : city.isNotEmpty
            ? city
            : state.isNotEmpty
                ? state
                : '';
    final nameParts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : nameParts.isNotEmpty
            ? nameParts[0][0].toUpperCase()
            : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NearfoColors.border),
      ),
      child: Column(
        children: [
          // Avatar with story ring
          GestureDetector(
            onTap: _hasActiveStory ? _openStoryViewer : null,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _hasActiveStory
                    ? const LinearGradient(
                        colors: [Color(0xFFFF8800), Color(0xFFFF0050), Color(0xFFD500F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : NearfoColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: _hasActiveStory
                        ? const Color(0xFFFF0050).withOpacity(0.4)
                        : NearfoColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              padding: EdgeInsets.all(_hasActiveStory ? 3.5 : 0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NearfoColors.card,
                  border: _hasActiveStory ? Border.all(color: NearfoColors.card, width: 2) : null,
                ),
                child: avatarUrl.isNotEmpty
                    ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(avatarUrl), fit: BoxFit.cover, placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), errorWidget: (_, __, ___) => Center(child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)))))
                    : Center(child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white))),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                Icon(Icons.verified, color: NearfoColors.accent, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text('@$handle', style: TextStyle(color: NearfoColors.textMuted, fontSize: 15)),

          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(bio, style: TextStyle(color: NearfoColors.textMuted, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
          ],

          if (displayLocation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 14, color: NearfoColors.accent),
                const SizedBox(width: 4),
                Text(displayLocation, style: TextStyle(color: NearfoColors.accent, fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statColumn('$postsCount', 'Posts'),
              Container(width: 1, height: 30, color: NearfoColors.border),
              _userData?['hideFollowersList'] == true
                  ? _statColumn('$_followersCount', 'Followers')
                  : GestureDetector(
                      onTap: () {
                        final uid = (_userData?['_id'] as String?) ?? (_userData?['id'] as String?) ?? widget.userId ?? '';
                        final uname = (_userData?['name'] as String?)?.toString() ?? widget.handle;
                        if (uid.toString().isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => FollowersFollowingScreen(userId: uid.toString(), userName: uname, initialTab: 0),
                          ));
                        }
                      },
                      child: _statColumn('$_followersCount', 'Followers'),
                    ),
              Container(width: 1, height: 30, color: NearfoColors.border),
              _userData?['hideFollowersList'] == true
                  ? _statColumn('$_followingCount', 'Following')
                  : GestureDetector(
                      onTap: () {
                        final uid = (_userData?['_id'] as String?) ?? (_userData?['id'] as String?) ?? widget.userId ?? '';
                        final uname = (_userData?['name'] as String?)?.toString() ?? widget.handle;
                        if (uid.toString().isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => FollowersFollowingScreen(userId: uid.toString(), userName: uname, initialTab: 1),
                          ));
                        }
                      },
                      child: _statColumn('$_followingCount', 'Following'),
                    ),
            ],
          ),
          const SizedBox(height: 20),

          // Nearfo Score
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [NearfoColors.primary.withOpacity(0.15), NearfoColors.accent.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NearfoColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(gradient: NearfoColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('$nearfoScore', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nearfo Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('Local influence & engagement', style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Blocked banner
          if (_isBlocked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NearfoColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NearfoColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: NearfoColors.danger, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('You have blocked this user', style: TextStyle(color: NearfoColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: _toggleBlock,
                    child: Text('Unblock', style: TextStyle(color: NearfoColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ] else if (_amIBlocked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NearfoColors.textDim.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'You can\'t interact with this user',
                style: TextStyle(color: NearfoColors.textDim, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            // Follow / Message buttons
            if (!isMe)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _followLoading ? null : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? NearfoColors.cardHover : NearfoColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        side: _isFollowing ? BorderSide(color: NearfoColors.border) : null,
                      ),
                      child: _followLoading
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _isFollowing ? 'Following' : 'Follow',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _isFollowing ? NearfoColors.textMuted : Colors.white,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final uid = (_userData?['_id'] as String?) ?? (_userData?['id'] as String?);
                        final uname = ((_userData?['name'] as String?) ?? '').toString();
                        final avatar = ((_userData?['avatarUrl'] as String?) ?? '').toString();
                        if (uid != null) {
                          Navigator.pushNamed(context, NearfoRoutes.chatDetail, arguments: {
                            'recipientId': uid,
                            'recipientName': uname.isNotEmpty ? uname : '@${widget.handle}',
                            'recipientAvatar': avatar.isNotEmpty ? avatar : null,
                            'isOnline': (_userData?['isOnline'] as bool?) ?? false,
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: NearfoColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Message', style: TextStyle(color: NearfoColors.primaryLight, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    if (_postsLoading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: NearfoColors.primary, strokeWidth: 2)),
      );
    }
    if (_postsError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: NearfoColors.danger),
            const SizedBox(height: 12),
            Text(_postsError!, style: TextStyle(color: NearfoColors.textDim, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadUserPosts,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  gradient: NearfoColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.article_outlined, size: 48, color: NearfoColors.textDim.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('No posts yet', style: TextStyle(color: NearfoColors.textDim, fontSize: 15)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        ..._posts.map((post) => PostCard(
              post: post,
              onLike: () async {
                final res = await ApiService.toggleLike(post.id);
                if (res.isSuccess) _loadUserPosts();
              },
              onShare: () {
                ShareUtils.sharePost(
                  postId: post.id,
                  content: post.content,
                  authorName: post.author.name.isNotEmpty
                      ? post.author.name
                      : '@${post.author.handle}',
                );
              },
            )),
      ],
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
      ],
    );
  }
}
