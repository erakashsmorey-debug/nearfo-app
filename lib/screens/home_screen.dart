import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../models/post_model.dart';
import '../providers/feed_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_utils.dart';
import '../widgets/story_row.dart';
import '../widgets/banner_ad_widget.dart';
import '../l10n/l10n_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _unreadNotifCount = 0;
  StreamSubscription? _notifSub;
  final GlobalKey<StoryRowState> _storyRowKey = GlobalKey<StoryRowState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadFeed();
      _loadUnreadCount();
    });
    _scrollController.addListener(_onScroll);
    // Listen for real-time notifications via socket
    _notifSub = SocketService.instance.onNewNotification.listen((_) {
      if (mounted) _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    final res = await ApiService.getUnreadCount();
    if (res.isSuccess && res.data != null && mounted) {
      setState(() => _unreadNotifCount = res.data!);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<FeedProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await feed.loadFeed();
          _storyRowKey.currentState?.loadStories();
        },
        color: NearfoColors.primary,
        backgroundColor: NearfoColors.card,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            gradient: NearfoColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: NearfoColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Center(child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
                        ),
                        const SizedBox(width: 10),
                        Text(context.l10n.homeAppName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: NearfoColors.text, letterSpacing: -0.5)),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pushNamed(context, NearfoRoutes.notifications).then((_) => _loadUnreadCount());
                      },
                      icon: Badge(
                        isLabelVisible: _unreadNotifCount > 0,
                        label: Text(
                          _unreadNotifCount > 99 ? '99+' : '$_unreadNotifCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                        backgroundColor: NearfoColors.danger,
                        child: Icon(Icons.notifications_outlined, color: NearfoColors.textMuted, size: 26),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stories Row
            SliverToBoxAdapter(
              child: StoryRow(key: _storyRowKey),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Feed Mode Toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF12121E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NearfoColors.primary.withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: NearfoColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _feedToggleButton(feed, 'following', context.l10n.homeFollowing),
                      _feedToggleButton(feed, 'local', context.l10n.homeLocal),
                      _feedToggleButton(feed, 'global', context.l10n.homeGlobal),
                      _feedToggleButton(feed, 'mixed', context.l10n.homeMixed),
                    ],
                  ),
                ),
              ),
            ),

            // Location Bar
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF8B5CF6).withOpacity(0.12), const Color(0xFF06B6D4).withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayLocation ?? 'Getting location...',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            '${LocationService.nearfoRadiusKm.round()}km radius active',
                            style: TextStyle(color: NearfoColors.textDim, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [NearfoColors.success, NearfoColors.success.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(context.l10n.homeLive, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            // Posts
            if (feed.isLoading && feed.posts.isEmpty)
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: NearfoColors.primary)),
              )
            else if (feed.error != null && feed.posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 48, color: NearfoColors.textDim),
                      const SizedBox(height: 16),
                      Text(feed.error!, style: TextStyle(color: NearfoColors.textMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => feed.loadFeed(),
                        style: ElevatedButton.styleFrom(backgroundColor: NearfoColors.primary),
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                ),
              )
            else if (feed.posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(context.l10n.homeNoVibes, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(context.l10n.homeBeFirst, style: TextStyle(color: NearfoColors.textMuted)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Calculate actual post index (accounting for ad slots)
                    // Ad appears after every 4 posts (at positions 4, 9, 14, ...)
                    final adInterval = 5; // every 5th item is an ad (after 4 posts)
                    final isAd = index > 0 && (index + 1) % adInterval == 0;

                    if (isAd) {
                      return const StyledBannerAd();
                    }

                    // Calculate real post index (subtract number of ads before this index)
                    final adsBeforeThis = index ~/ adInterval;
                    final postIndex = index - adsBeforeThis;

                    if (postIndex >= feed.posts.length) {
                      return feed.hasMore
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator(color: NearfoColors.primary)),
                            )
                          : const SizedBox(height: 100);
                    }
                    final currentPost = feed.posts[postIndex];
                    // Record view when post appears in feed
                    feed.recordView(currentPost.id);
                    final myId = context.read<AuthProvider>().user?.id ?? '';
                    return PostCard(
                      post: currentPost,
                      isOwner: currentPost.author.id == myId,
                      onLike: () => feed.toggleLike(currentPost.id),
                      onComment: () => CommentsSheet.show(
                        context,
                        postId: currentPost.id,
                        commentsCount: currentPost.commentsCount,
                      ),
                      onShare: () {
                        feed.recordShare(currentPost.id);
                        ShareUtils.sharePost(
                          postId: currentPost.id,
                          content: currentPost.content,
                          authorName: currentPost.author.name.isNotEmpty
                              ? currentPost.author.name
                              : '@${currentPost.author.handle}',
                        );
                      },
                      onBookmark: () => feed.toggleBookmark(currentPost.id),
                      onEdit: () => _showEditDialog(context, currentPost, feed),
                      onRepostToStory: () async {
                        final res = await ApiService.repostToStory(currentPost.id);
                        if (res.isSuccess && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.homeSharedToStory), backgroundColor: NearfoColors.success),
                          );
                        }
                      },
                      onDelete: () async {
                        final res = await ApiService.deletePost(currentPost.id);
                        if (res.isSuccess && mounted) {
                          feed.removePost(currentPost.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.homePostDeleted), backgroundColor: NearfoColors.success),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.homeDeleteFailed), backgroundColor: NearfoColors.danger),
                          );
                        }
                      },
                    );
                  },
                  // Total items = posts + loading indicator + ads inserted
                  childCount: feed.posts.length + 1 + (feed.posts.length ~/ 4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, PostModel post, FeedProvider feed) {
    final controller = TextEditingController(text: post.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.homeEditPost, style: TextStyle(color: NearfoColors.text)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: NearfoColors.text),
          decoration: InputDecoration(
            hintText: context.l10n.homeEditPostHint,
            hintStyle: TextStyle(color: NearfoColors.textDim),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: NearfoColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: NearfoColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final newContent = controller.text.trim();
              if (newContent.isEmpty || newContent == post.content) return;
              final res = await ApiService.editPost(post.id, content: newContent);
              if (res.isSuccess && mounted) {
                feed.loadFeed();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.homePostUpdated), backgroundColor: NearfoColors.success),
                );
              }
            },
            child: Text(context.l10n.save, style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _feedToggleButton(FeedProvider feed, String mode, String label) {
    final isActive = feed.feedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => feed.setFeedMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]) : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isActive ? null : Border.all(color: const Color(0xFF1E1E30)),
            boxShadow: isActive ? [
              BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.35), blurRadius: 10, spreadRadius: 0, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}
