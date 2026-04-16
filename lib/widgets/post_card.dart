import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../models/post_model.dart';
import '../l10n/l10n_helper.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onRepostToStory;
  final bool isOwner;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBookmark,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onRepostToStory,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [NearfoColors.primary.withOpacity(0.15), NearfoColors.accent.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: NearfoColors.primary.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(color: NearfoColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF12121E).withOpacity(0.92),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User row
            Row(
              children: [
                // Tappable avatar + name → opens user profile
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, NearfoRoutes.userProfile, arguments: {
                      'handle': post.author.handle,
                      'userId': post.author.id,
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFFF0050), Color(0xFFFF8800)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF12121E),
                          ),
                          padding: const EdgeInsets.all(1.5),
                          child: (post.author.avatarUrl?.isNotEmpty ?? false)
                              ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(post.author.avatarUrl!), fit: BoxFit.cover, width: 36, height: 36))
                              : Center(child: Text(post.author.initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white))),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, NearfoRoutes.userProfile, arguments: {
                        'handle': post.author.handle,
                        'userId': post.author.id,
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.author.name.isNotEmpty ? post.author.name : '@${post.author.handle}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (post.author.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified, color: NearfoColors.accent, size: 16),
                            ],
                          ],
                        ),
                        Text(
                          '@${post.author.handle} · ${post.timeAgo}',
                          style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                // Distance badge — gradient pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: post.feedType == 'local'
                          ? [NearfoColors.accent.withOpacity(0.25), NearfoColors.accent.withOpacity(0.1)]
                          : [NearfoColors.pink.withOpacity(0.25), NearfoColors.pink.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: post.feedType == 'local'
                          ? NearfoColors.accent.withOpacity(0.5)
                          : NearfoColors.pink.withOpacity(0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (post.feedType == 'local' ? NearfoColors.accent : NearfoColors.pink).withOpacity(0.2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    post.feedType == 'local' ? '${post.formattedDistance}' : 'Global',
                    style: TextStyle(
                      color: post.feedType == 'local' ? NearfoColors.accent : NearfoColors.pink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 3-dot menu
                GestureDetector(
                  onTap: () => _showPostMenu(context),
                  child: Icon(Icons.more_vert, size: 20, color: NearfoColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Content
            if (post.content.isNotEmpty)
              Text(post.content, style: const TextStyle(fontSize: 15, height: 1.5)),

            // Hashtags (tappable → opens hashtag feed)
            if (post.hashtags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: post.hashtags.take(3).map((tag) => GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/hashtag', arguments: tag),
                  child: Text(
                    '#$tag',
                    style: TextStyle(color: NearfoColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                )).toList(),
              ),
            ],

            // Images
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final rawImg = post.images.first;
                final resolvedImg = NearfoConfig.resolveMediaUrl(rawImg);
                debugPrint('[PostCard] raw=$rawImg resolved=$resolvedImg');
                return const SizedBox.shrink();
              }),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: NearfoConfig.resolveMediaUrl(post.images.first),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: NearfoColors.cardHover,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: NearfoColors.primary)),
                  ),
                  errorWidget: (_, url, error) {
                    debugPrint('[PostCard] Image FAILED: url=$url error=$error');
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: NearfoColors.cardHover,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, color: NearfoColors.textDim, size: 32),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                url.length > 60 ? '${url.substring(0, 60)}...' : url,
                                style: TextStyle(color: NearfoColors.textDim, fontSize: 9),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Video
            if ((post.video ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _PostVideoPlayer(videoUrl: NearfoConfig.resolveMediaUrl(post.video!)),
            ],

            // Mood
            if ((post.mood ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NearfoColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Feeling ${post.mood}', style: TextStyle(fontSize: 12, color: NearfoColors.primaryLight)),
              ),
            ],

            // ══════════════════════════════════════
            // 📍 LOCATION TAG — COMPULSORY (USP)
            // ══════════════════════════════════════
            if ((post.author.city ?? '').isNotEmpty || post.formattedDistance.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NearfoColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: NearfoColors.primary.withOpacity(0.2)),
                  ),
                  child: Text(
                    '📍 ${post.author.city ?? post.city}${post.formattedDistance.isNotEmpty ? ' • ${post.formattedDistance}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: NearfoColors.primaryLight,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // Action bar with pill-style buttons
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: NearfoColors.primary.withOpacity(0.2), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _pillActionButton(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    '${post.likesCount}',
                    color: post.isLiked ? NearfoColors.danger : NearfoColors.textMuted,
                    isActive: post.isLiked,
                    onTap: onLike,
                  ),
                  _pillActionButton(
                    Icons.chat_bubble_outline,
                    '${post.commentsCount}',
                    color: NearfoColors.textMuted,
                    isActive: false,
                    onTap: onComment,
                  ),
                  _pillActionButton(
                    Icons.repeat,
                    '${post.sharesCount}',
                    color: NearfoColors.textMuted,
                    isActive: false,
                    onTap: onShare,
                  ),
                  _pillActionButton(
                    post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    '',
                    color: post.isBookmarked ? NearfoColors.warning : NearfoColors.textMuted,
                    isActive: post.isBookmarked,
                    onTap: onBookmark,
                  ),
                  if (post.viewsCount > 0)
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: NearfoColors.textDim),
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(post.viewsCount),
                          style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showPostMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: NearfoColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isOwner) ...[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: NearfoColors.text),
                title: Text(context.l10n.postCardEditPost, style: TextStyle(color: NearfoColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit?.call();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: NearfoColors.danger),
                title: Text(context.l10n.postCardDeletePost, style: TextStyle(color: NearfoColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
            ],
            if (!isOwner)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: NearfoColors.warning),
                title: Text(context.l10n.postCardReportPost, style: TextStyle(color: NearfoColors.warning)),
                onTap: () {
                  Navigator.pop(ctx);
                  onReport?.call();
                },
              ),
            if (post.images.isNotEmpty || (post.video ?? '').isNotEmpty)
              ListTile(
                leading: Icon(Icons.amp_stories_outlined, color: NearfoColors.primary),
                title: Text(context.l10n.postCardShareToStory, style: TextStyle(color: NearfoColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  onRepostToStory?.call();
                },
              ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: NearfoColors.textMuted),
              title: Text('Share Post', style: TextStyle(color: NearfoColors.text)),
              onTap: () {
                Navigator.pop(ctx);
                onShare?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text('Delete Post?', style: TextStyle(color: NearfoColors.text)),
        content: Text('This action cannot be undone.', style: TextStyle(color: NearfoColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: Text('Delete', style: TextStyle(color: NearfoColors.danger)),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _actionButton(IconData icon, String count, {Color? color, VoidCallback? onTap}) {
    final c = color ?? NearfoColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: c),
          if (count.isNotEmpty && count != '0') ...[
            const SizedBox(width: 4),
            Text(count, style: TextStyle(color: c, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _pillActionButton(IconData icon, String count, {Color? color, bool isActive = false, VoidCallback? onTap}) {
    final c = color ?? NearfoColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? (c == NearfoColors.danger ? NearfoColors.danger.withOpacity(0.15) : NearfoColors.warning.withOpacity(0.15))
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? c.withOpacity(0.4)
                : NearfoColors.primary.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(color: c.withOpacity(0.2), blurRadius: 6, spreadRadius: 0),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: c),
            if (count.isNotEmpty && count != '0') ...[
              const SizedBox(width: 5),
              Text(count, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stateful video player widget for post cards
class _PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _PostVideoPlayer({required this.videoUrl});

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(NearfoConfig.resolveMediaUrl(widget.videoUrl)));
    try {
      await _controller.initialize().timeout(const Duration(seconds: 15));
      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: false,
        looping: false,
        showControls: true,
        aspectRatio: _controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: NearfoColors.primary,
          handleColor: NearfoColors.primaryLight,
          backgroundColor: NearfoColors.border,
          bufferedColor: NearfoColors.textDim,
        ),
        placeholder: Container(color: NearfoColors.cardHover),
        errorBuilder: (context, errorMessage) => Container(
          height: 200,
          decoration: BoxDecoration(
            color: NearfoColors.cardHover,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: NearfoColors.danger, size: 36),
                const SizedBox(height: 8),
                Text('Video failed to load', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: NearfoColors.cardHover,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, color: NearfoColors.textDim, size: 36),
              const SizedBox(height: 8),
              Text('Video unavailable', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_chewieController == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: NearfoColors.cardHover,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: CircularProgressIndicator(color: NearfoColors.primary, strokeWidth: 2),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio.clamp(0.5, 2.0),
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
