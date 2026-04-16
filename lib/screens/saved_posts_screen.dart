import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_utils.dart';
import '../l10n/l10n_helper.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _isLoading = true;
      });
    }

    final res = await ApiService.getSavedPosts(page: _page);
    if (res.isSuccess && res.data != null) {
      setState(() {
        if (refresh || _page == 1) {
          _posts = res.data!;
        } else {
          _posts.addAll(res.data!);
        }
        _hasMore = res.hasMore;
        _page++;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBookmark(String postId) async {
    final res = await ApiService.togglePostBookmark(postId);
    if (res.isSuccess) {
      setState(() {
        _posts.removeWhere((p) => p.id == postId);
      });
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
          icon: Icon(Icons.arrow_back_ios_rounded, color: NearfoColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.l10n.savedPostsTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: NearfoColors.warning.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bookmark_rounded, size: 56, color: NearfoColors.warning),
                      ),
                      const SizedBox(height: 24),
                      Text(context.l10n.savedPostsNoPostsYet, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: NearfoColors.text)),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.savedPostsAppearHere,
                        style: TextStyle(color: NearfoColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadSavedPosts(refresh: true),
                  color: NearfoColors.primary,
                  backgroundColor: NearfoColors.card,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        _loadSavedPosts();
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(color: NearfoColors.primary)),
                        );
                      }
                      final post = _posts[index];
                      return PostCard(
                        post: post,
                        onLike: () {},
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
                        onBookmark: () => _toggleBookmark(post.id),
                      );
                    },
                  ),
                ),
    );
  }
}
