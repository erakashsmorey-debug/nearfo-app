import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTab; // 0 = Followers, 1 = Following

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.initialTab = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _loadingFollowers = true;
  bool _loadingFollowing = true;
  int _followersPage = 1;
  int _followingPage = 1;
  bool _hasMoreFollowers = false;
  bool _hasMoreFollowing = false;
  int _totalFollowers = 0;
  int _totalFollowing = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadFollowers();
    _loadFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers({bool loadMore = false}) async {
    if (loadMore) _followersPage++;
    final res = await ApiService.getFollowers(widget.userId, page: _followersPage);
    if (res.isSuccess && res.data != null && mounted) {
      setState(() {
        if (loadMore) {
          _followers.addAll(List<Map<String, dynamic>>.from(res.data!['users'] as List<dynamic>));
        } else {
          _followers = List<Map<String, dynamic>>.from(res.data!['users'] as List<dynamic>);
        }
        _totalFollowers = (res.data!['total'] as int?) ?? _followers.length;
        _hasMoreFollowers = (res.data!['hasMore'] as bool?) ?? false;
        _loadingFollowers = false;
      });
    } else if (mounted) {
      setState(() => _loadingFollowers = false);
    }
  }

  Future<void> _loadFollowing({bool loadMore = false}) async {
    if (loadMore) _followingPage++;
    final res = await ApiService.getFollowing(widget.userId, page: _followingPage);
    if (res.isSuccess && res.data != null && mounted) {
      setState(() {
        if (loadMore) {
          _following.addAll(List<Map<String, dynamic>>.from(res.data!['users'] as List<dynamic>));
        } else {
          _following = List<Map<String, dynamic>>.from(res.data!['users'] as List<dynamic>);
        }
        _totalFollowing = (res.data!['total'] as int?) ?? _following.length;
        _hasMoreFollowing = (res.data!['hasMore'] as bool?) ?? false;
        _loadingFollowing = false;
      });
    } else if (mounted) {
      setState(() => _loadingFollowing = false);
    }
  }

  bool _followInProgress = false;

  Future<void> _toggleFollow(Map<String, dynamic> user, int index, bool isFollowerTab) async {
    if (_followInProgress) return; // prevent double-tap
    final userId = user['_id']?.toString() ?? '';
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.userIDMissing), backgroundColor: Colors.red),
        );
      }
      return;
    }

    _followInProgress = true;
    final list = isFollowerTab ? _followers : _following;
    final wasFollowing = (list[index]['isFollowing'] as bool?) == true;
    setState(() => list[index]['isFollowing'] = !wasFollowing);

    try {
      final res = await ApiService.toggleFollow(userId);
      if (!res.isSuccess && mounted) {
        setState(() => list[index]['isFollowing'] = wasFollowing);
      }
    } catch (e) {
      if (mounted) {
        setState(() => list[index]['isFollowing'] = wasFollowing);
      }
    } finally {
      _followInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: NearfoColors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NearfoColors.primary,
          indicatorWeight: 3,
          labelColor: NearfoColors.text,
          unselectedLabelColor: NearfoColors.textDim,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: [
            Tab(text: '${context.l10n.followersTitle} $_totalFollowers'),
            Tab(text: '${context.l10n.followingTitle} $_totalFollowing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_followers, _loadingFollowers, _hasMoreFollowers, true),
          _buildUserList(_following, _loadingFollowing, _hasMoreFollowing, false),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, bool loading, bool hasMore, bool isFollowerTab) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: NearfoColors.primary));
    }
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowerTab ? Icons.people_outline : Icons.person_add_alt_1_outlined,
              size: 56,
              color: NearfoColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              isFollowerTab ? context.l10n.followersNoFollowers : context.l10n.followersNotFollowing,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: NearfoColors.textDim),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (isFollowerTab) {
          _followersPage = 1;
          await _loadFollowers();
        } else {
          _followingPage = 1;
          await _loadFollowing();
        }
      },
      color: NearfoColors.primary,
      backgroundColor: NearfoColors.card,
      child: ListView.builder(
        itemCount: users.length + (hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == users.length) {
            // Load more button
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    if (isFollowerTab) {
                      _loadFollowers(loadMore: true);
                    } else {
                      _loadFollowing(loadMore: true);
                    }
                  },
                  child: Text(context.l10n.loadMore, style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }

          final user = users[i];
          final name = user['name']?.toString() ?? '';
          final handle = user['handle']?.toString() ?? '';
          final avatar = user['avatarUrl']?.toString();
          final isFollowing = user['isFollowing'] == true;
          final bio = user['bio']?.toString() ?? '';
          final city = user['city']?.toString() ?? '';
          final displayName = (name.isNotEmpty && name != 'Nearfo User') ? name : '@$handle';
          final initials = displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
          final subtitle = bio.isNotEmpty ? bio : (city.isNotEmpty ? city : '@$handle');

          return InkWell(
            onTap: () {
              final userHandle = user['handle']?.toString() ?? '';
              final uid = user['_id']?.toString() ?? '';
              if (userHandle.isNotEmpty || uid.isNotEmpty) {
                Navigator.pushNamed(context, NearfoRoutes.userProfile, arguments: {
                  'handle': userHandle,
                  'userId': uid,
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: NearfoColors.primary,
                    backgroundImage: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                    child: avatar == null || avatar.isEmpty
                        ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                            ),
                            if (user['isVerified'] == true) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified, color: NearfoColors.primary, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: NearfoColors.textDim, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () => _toggleFollow(user, i, isFollowerTab),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? NearfoColors.cardHover : NearfoColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        elevation: 0,
                        side: isFollowing ? BorderSide(color: NearfoColors.border) : null,
                      ),
                      child: Text(
                        isFollowing ? context.l10n.userProfileFollowing : context.l10n.userProfileFollow,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isFollowing ? NearfoColors.textMuted : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
