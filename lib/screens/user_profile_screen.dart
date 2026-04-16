import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_utils.dart';
import 'followers_following_screen.dart';
import '../services/ad_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

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

  // User posts
  List<PostModel> _posts = [];
  bool _postsLoading = false;

  @override
  void initState() {
    super.initState();
    // Record action for non-intrusive interstitial
    AdService.instance.recordAction();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      ApiResponse<Map<String, dynamic>> res;

      // Try handle first if available
      if (widget.handle.isNotEmpty) {
        res = await ApiService.getUserProfile(widget.handle);
        // If handle lookup fails but we have userId, try userId as fallback
        if (!res.isSuccess && widget.userId != null) {
          res = await ApiService.getUserProfileById(widget.userId!);
        }
      } else if (widget.userId != null) {
        res = await ApiService.getUserProfileById(widget.userId!);
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
      } else {
        debugPrint('[UserProfile] Failed to load: handle=${widget.handle}, userId=${widget.userId}');
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('[UserProfile] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUserPosts() async {
    final uid = ((_userData?['_id'] as String?) ?? (_userData?['id'] as String?)) ?? widget.userId;
    final handle = ((_userData?['handle'] as String?) ?? widget.handle);
    if (uid == null && handle.isEmpty) return;
    if (!mounted) return;
    setState(() => _postsLoading = true);

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
      if (mounted) setState(() => _postsLoading = false);
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
          SnackBar(content: Text(context.l10n.userProfileFollowStatusFailed), backgroundColor: NearfoColors.danger),
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
          _isBlocked ? context.l10n.userProfileUnblockUser : context.l10n.userProfileBlockUser,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _isBlocked
              ? context.l10n.userProfileUnblockDesc
              : context.l10n.userProfileBlockDesc,
          style: TextStyle(color: NearfoColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _isBlocked ? context.l10n.unblock : context.l10n.block,
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
                if (value == 'report') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.userProfileReportSubmitted), backgroundColor: NearfoColors.warning),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(_isBlocked ? Icons.check_circle_outline : Icons.block, color: _isBlocked ? NearfoColors.success : NearfoColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Text(_isBlocked ? context.l10n.userProfileUnblockUser : context.l10n.userProfileBlockUser, style: TextStyle(color: _isBlocked ? NearfoColors.success : NearfoColors.danger)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: NearfoColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Text(context.l10n.userProfileReportUser, style: TextStyle(color: NearfoColors.warning)),
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
              ? Center(child: Text(context.l10n.userProfileNotFound, style: TextStyle(color: NearfoColors.textMuted)))
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
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: NearfoColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: NearfoColors.primary.withOpacity(0.3), blurRadius: 20)],
            ),
            child: avatarUrl.isNotEmpty
                ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(avatarUrl), fit: BoxFit.cover, placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), errorWidget: (_, __, ___) => Center(child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)))))
                : Center(child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white))),
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
              _statColumn('$postsCount', context.l10n.userProfilePosts),
              Container(width: 1, height: 30, color: NearfoColors.border),
              _userData?['hideFollowersList'] == true
                  ? _statColumn('$_followersCount', context.l10n.userProfileFollowers)
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
                      child: _statColumn('$_followersCount', context.l10n.userProfileFollowers),
                    ),
              Container(width: 1, height: 30, color: NearfoColors.border),
              _userData?['hideFollowersList'] == true
                  ? _statColumn('$_followingCount', context.l10n.userProfileFollowing)
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
                      child: _statColumn('$_followingCount', context.l10n.userProfileFollowing),
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
                      Text(context.l10n.userProfileNearfoScore, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(context.l10n.userProfileNearfoScoreDesc, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
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
                    child: Text(context.l10n.userProfileYouBlockedUser, style: TextStyle(color: NearfoColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: _toggleBlock,
                    child: Text(context.l10n.unblock, style: TextStyle(color: NearfoColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
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
                context.l10n.userProfileCantInteract,
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
                              _isFollowing ? context.l10n.userProfileFollowing : context.l10n.userProfileFollow,
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
                      child: Text(context.l10n.userProfileMessage, style: TextStyle(color: NearfoColors.primaryLight, fontWeight: FontWeight.w600)),
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
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.article_outlined, size: 48, color: NearfoColors.textDim.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(context.l10n.userProfileNoPosts, style: TextStyle(color: NearfoColors.textDim, fontSize: 15)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(context.l10n.userProfilePosts, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
