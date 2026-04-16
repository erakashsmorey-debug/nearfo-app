import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../utils/json_helpers.dart';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

class CommentsSheet extends StatefulWidget {
  final String contentId;
  final int commentsCount;
  final bool isReel;

  const CommentsSheet({
    super.key,
    required this.contentId,
    required this.commentsCount,
    this.isReel = false,
  });

  /// Show the comments bottom sheet — works for both posts and reels
  static void show(BuildContext context, {
    required String postId,
    required int commentsCount,
    bool isReel = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        contentId: postId,
        commentsCount: commentsCount,
        isReel: isReel,
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  // Reply state
  String? _replyToCommentId;
  String? _replyToName;

  // Track liked comments locally for instant UI feedback
  final Set<String> _likedCommentIds = {};
  final Map<String, int> _likesCountMap = {};

  // Track expanded reply sections
  final Set<String> _expandedReplies = {};
  final Map<String, List<dynamic>> _repliesMap = {};
  final Set<String> _loadingReplies = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _likedCommentIds.clear();
    _likesCountMap.clear();
    _expandedReplies.clear();
    _repliesMap.clear();
    _loadingReplies.clear();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getComments(widget.contentId, isReel: widget.isReel);
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() {
        _comments = res.data!;
        // Initialize like state from server data
        for (final comment in _comments) {
          final commentMap = (comment as Map<String, dynamic>?) ?? {};
          final id = commentMap.asStringOrNull('_id') ?? '';
          if (id.isEmpty) continue;
          _likesCountMap[id] = commentMap.asInt('likesCount', 0);
          // Check if current user has liked this comment
          if (commentMap.asBool('isLiked', false)) {
            _likedCommentIds.add(id);
          }
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final res = await ApiService.addComment(
      contentId: widget.contentId,
      content: text,
      isReel: widget.isReel,
      parentComment: _replyToCommentId,
    );

    if (res.isSuccess) {
      _commentController.clear();
      // Save the reply target BEFORE cancelling so we can refresh replies
      final repliedToId = _replyToCommentId;
      _cancelReply();
      await _loadComments();
      // Auto-expand and load replies for the parent comment after replying
      if (repliedToId != null) {
        _expandedReplies.add(repliedToId);
        unawaited(_loadReplies(repliedToId));
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _toggleCommentLike(String commentId) async {
    // Store original state for revert
    final wasLiked = _likedCommentIds.contains(commentId);
    final originalCount = _likesCountMap[commentId] ?? 0;

    // Optimistic UI update
    setState(() {
      if (_likedCommentIds.contains(commentId)) {
        _likedCommentIds.remove(commentId);
        _likesCountMap[commentId] = (_likesCountMap[commentId] ?? 1) - 1;
      } else {
        _likedCommentIds.add(commentId);
        _likesCountMap[commentId] = (_likesCountMap[commentId] ?? 0) + 1;
      }
    });

    final res = await ApiService.toggleCommentLike(commentId);
    if (res.isSuccess && res.data != null) {
      setState(() {
        final resData = res.data!;
        final isLiked = resData.asBool('isLiked', false);
        final count = resData.asInt('likesCount', 0);
        if (isLiked) {
          _likedCommentIds.add(commentId);
        } else {
          _likedCommentIds.remove(commentId);
        }
        _likesCountMap[commentId] = count;
      });
    } else {
      // Revert optimistic update on API failure
      setState(() {
        if (wasLiked) {
          _likedCommentIds.add(commentId);
        } else {
          _likedCommentIds.remove(commentId);
        }
        _likesCountMap[commentId] = originalCount;
      });
    }
  }

  void _startReply(String commentId, String authorName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToName = authorName;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToName = null;
    });
  }

  Future<void> _loadReplies(String commentId) async {
    setState(() => _loadingReplies.add(commentId));
    final res = await ApiService.getCommentReplies(widget.contentId, commentId);
    if (res.isSuccess && res.data != null) {
      setState(() {
        _repliesMap[commentId] = res.data!;
        _expandedReplies.add(commentId);
        _loadingReplies.remove(commentId);
      });
    } else {
      setState(() => _loadingReplies.remove(commentId));
    }
  }

  void _toggleReplies(String commentId, int replyCount) {
    if (_expandedReplies.contains(commentId)) {
      setState(() => _expandedReplies.remove(commentId));
    } else if (replyCount > 0) {
      _loadReplies(commentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: NearfoColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.commentsTitle(widget.commentsCount),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, color: NearfoColors.textMuted),
                    ),
                  ],
                ),
              ),
              Divider(color: NearfoColors.border, height: 1),

              // Comments list
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
                    : _comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 48, color: NearfoColors.textDim.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text('No comments yet', style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Be the first to comment!', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = (_comments[index] as Map<String, dynamic>?) ?? {};
                              final author = comment.asMap('author');
                              final commentId = comment.asStringOrNull('_id') ?? '';
                              final replyCount = comment.asInt('totalReplies', 0);
                              return _buildCommentTile(
                                commentId: commentId,
                                name: author.asString('name', 'Unknown'),
                                handle: author.asString('handle', 'unknown'),
                                avatarUrl: author.asStringOrNull('avatarUrl'),
                                content: comment.asString('content', ''),
                                createdAt: comment['createdAt'] != null
                                    ? (DateTime.tryParse(comment.asString('createdAt', '')) ?? DateTime.now()).toLocal()
                                    : DateTime.now(),
                                isVerified: author.asBool('isVerified', false),
                                replyCount: replyCount,
                              );
                            },
                          ),
              ),

              // Reply indicator bar
              if (_replyToName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: NearfoColors.card,
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: NearfoColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Replying to $_replyToName',
                        style: TextStyle(color: NearfoColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(Icons.close, size: 18, color: NearfoColors.textDim),
                      ),
                    ],
                  ),
                ),

              // Input bar
              Container(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 10,
                  bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: BoxDecoration(
                  color: NearfoColors.card,
                  border: Border(top: BorderSide(color: NearfoColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: NearfoColors.bg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: NearfoColors.border),
                          ),
                          child: TextField(
                            controller: _commentController,
                            focusNode: _focusNode,
                            style: TextStyle(color: NearfoColors.text, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: _replyToName != null
                                  ? 'Reply to $_replyToName...'
                                  : 'Add a comment...',
                              hintStyle: TextStyle(color: NearfoColors.textDim),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isSending ? null : _sendComment,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: NearfoColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentTile({
    required String commentId,
    required String name,
    required String handle,
    String? avatarUrl,
    required String content,
    required DateTime createdAt,
    bool isVerified = false,
    int replyCount = 0,
    bool isReply = false,
  }) {
    final isLiked = _likedCommentIds.contains(commentId);
    final likesCount = _likesCountMap[commentId] ?? 0;
    final isRepliesExpanded = _expandedReplies.contains(commentId);
    final isLoadingReplies = _loadingReplies.contains(commentId);
    final replies = _repliesMap[commentId] ?? [];

    return Padding(
      padding: EdgeInsets.only(
        top: isReply ? 8 : 12,
        bottom: isReply ? 4 : 12,
        left: isReply ? 36 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundColor: NearfoColors.primary,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(avatarUrl), fit: BoxFit.cover,
                        width: isReply ? 28 : 36, height: isReply ? 28 : 36))
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: isReply ? 11 : 14,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isReply ? 13 : 14,
                        )),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, size: 14, color: NearfoColors.accent),
                        ],
                        const SizedBox(width: 6),
                        Text('@$handle', style: TextStyle(
                          color: NearfoColors.textDim,
                          fontSize: isReply ? 11 : 12,
                        )),
                        Spacer(),
                        Text(_timeAgo(createdAt), style: TextStyle(color: NearfoColors.textDim, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(content, style: TextStyle(fontSize: isReply ? 13 : 14, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Like button — functional
                        GestureDetector(
                          onTap: () => _toggleCommentLike(commentId),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isLiked ? Colors.redAccent : NearfoColors.textDim,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                likesCount > 0 ? '$likesCount' : 'Like',
                                style: TextStyle(
                                  color: isLiked ? Colors.redAccent : NearfoColors.textDim,
                                  fontSize: 12,
                                  fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Reply button — functional
                        if (!isReply)
                          GestureDetector(
                            onTap: () => _startReply(commentId, name),
                            child: Row(
                              children: [
                                Icon(Icons.reply, size: 16, color: NearfoColors.textDim),
                                const SizedBox(width: 4),
                                Text('Reply', style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // View replies toggle
          if (!isReply && replyCount > 0) ...[
            GestureDetector(
              onTap: () => _toggleReplies(commentId, replyCount),
              child: Padding(
                padding: const EdgeInsets.only(left: 48, top: 8),
                child: Row(
                  children: [
                    Container(width: 24, height: 1, color: NearfoColors.textDim),
                    const SizedBox(width: 8),
                    if (isLoadingReplies)
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: NearfoColors.primary),
                      )
                    else
                      Text(
                        isRepliesExpanded
                            ? 'Hide replies'
                            : 'View $replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                        style: TextStyle(
                          color: NearfoColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          // Expanded replies
          if (!isReply && isRepliesExpanded && replies.isNotEmpty)
            ...replies.map((reply) {
              final replyMap = (reply as Map<String, dynamic>?) ?? {};
              final rAuthor = replyMap.asMap('author');
              final replyId = replyMap.asStringOrNull('_id') ?? '';
              // Initialize like data for replies
              if (!_likesCountMap.containsKey(replyId)) {
                _likesCountMap[replyId] = replyMap.asInt('likesCount', 0);
                if (replyMap.asBool('isLiked', false)) {
                  _likedCommentIds.add(replyId);
                }
              }
              return _buildCommentTile(
                commentId: replyId,
                name: rAuthor.asString('name', 'Unknown'),
                handle: rAuthor.asString('handle', 'unknown'),
                avatarUrl: rAuthor.asStringOrNull('avatarUrl'),
                content: replyMap.asString('content', ''),
                createdAt: replyMap['createdAt'] != null
                    ? (DateTime.tryParse(replyMap.asString('createdAt', '')) ?? DateTime.now()).toLocal()
                    : DateTime.now(),
                isVerified: rAuthor.asBool('isVerified', false),
                isReply: true,
              );
            }),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
