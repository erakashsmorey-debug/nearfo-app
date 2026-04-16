import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_utils.dart';
import '../widgets/comments_sheet.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class HashtagScreen extends StatefulWidget {
  final String hashtag;
  const HashtagScreen({super.key, required this.hashtag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  List<PostModel> _posts = [];
  bool _loading = true;
  int _totalPosts = 0;
  String _sort = 'recent';
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() { _page = 1; _posts = []; _hasMore = true; });
    }
    setState(() => _loading = true);

    final res = await ApiService.getHashtagFeed(widget.hashtag, page: _page, sort: _sort);
    if (res.isSuccess && res.data != null && mounted) {
      final data = res.data!;
      final postsList = ((data['posts'] as List?) ?? []);
      final posts = postsList.map((p) => PostModel.fromJson(Map<String, dynamic>.from((p as Map<dynamic, dynamic>)))).toList();
      setState(() {
        if (refresh || _page == 1) {
          _posts = posts;
        } else {
          _posts.addAll(posts);
        }
        _totalPosts = ((data['totalPosts'] as int?) ?? 0);
        _hasMore = ((data['hasMore'] as bool?) ?? false);
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#${widget.hashtag}', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(context.l10n.hashtagPosts(_totalPosts), style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: NearfoColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Trending hashtags carousel
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['nearfo', 'trending', 'explore', 'local', 'viral', 'reels'].map((tag) =>
                GestureDetector(
                  onTap: () {
                    if (tag != widget.hashtag) {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (_) => HashtagScreen(hashtag: tag),
                      ));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: tag == widget.hashtag ? NearfoColors.primary.withOpacity(0.2) : NearfoColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: tag == widget.hashtag ? NearfoColors.primary : NearfoColors.border),
                    ),
                    child: Text('#$tag', style: TextStyle(
                      color: tag == widget.hashtag ? NearfoColors.primary : NearfoColors.textMuted,
                      fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Sort toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _sortChip(context.l10n.hashtagRecent, 'recent'),
                const SizedBox(width: 8),
                _sortChip(context.l10n.hashtagTop, 'top'),
              ],
            ),
          ),
          // Posts
          Expanded(
            child: _loading && _posts.isEmpty
                ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
                : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tag, size: 48, color: NearfoColors.textDim),
                            const SizedBox(height: 12),
                            Text(context.l10n.hashtagNoPosts(widget.hashtag), style: TextStyle(color: NearfoColors.textMuted)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadPosts(refresh: true),
                        child: ListView.builder(
                          itemCount: _posts.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _posts.length) {
                              if (!_loading) {
                                _page++;
                                _loadPosts();
                              }
                              return Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(child: CircularProgressIndicator(color: NearfoColors.primary, strokeWidth: 2)),
                              );
                            }
                            final post = _posts[index];
                            final myId = context.read<AuthProvider>().user?.id ?? '';
                            return PostCard(
                              post: post,
                              isOwner: post.author.id == myId,
                              onLike: () async {
                                await ApiService.toggleLike(post.id);
                                _loadPosts(refresh: true);
                              },
                              onComment: () => CommentsSheet.show(context, postId: post.id, commentsCount: post.commentsCount),
                              onShare: () => ShareUtils.sharePost(
                                postId: post.id,
                                content: post.content,
                                authorName: post.author.name.isNotEmpty
                                    ? post.author.name
                                    : '@${post.author.handle}',
                              ),
                              onBookmark: () async {
                                await ApiService.togglePostBookmark(post.id);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final isActive = _sort == value;
    return GestureDetector(
      onTap: () {
        if (_sort != value) {
          setState(() => _sort = value);
          _loadPosts(refresh: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? NearfoColors.primary : NearfoColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? NearfoColors.primary : NearfoColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : NearfoColors.textMuted,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
