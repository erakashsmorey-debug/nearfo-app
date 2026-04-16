import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../utils/constants.dart';
import '../models/reel_model.dart';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

class SavedReelsScreen extends StatefulWidget {
  const SavedReelsScreen({super.key});

  @override
  State<SavedReelsScreen> createState() => _SavedReelsScreenState();
}

class _SavedReelsScreenState extends State<SavedReelsScreen> {
  List<ReelModel> _reels = [];
  bool _isLoading = true;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadSavedReels();
  }

  Future<void> _loadSavedReels({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _isLoading = true;
      });
    }

    final res = await ApiService.getSavedReels(page: _page);
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() {
        if (refresh || _page == 1) {
          _reels = res.data!;
        } else {
          _reels.addAll(res.data!);
        }
        _hasMore = res.hasMore;
        _page++;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBookmark(String reelId) async {
    final res = await ApiService.toggleReelBookmark(reelId);
    if (res.isSuccess && mounted) {
      setState(() {
        _reels.removeWhere((r) => r.id == reelId);
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
        title: Text(context.l10n.savedReelsTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _reels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: NearfoColors.accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.video_library_rounded, size: 56, color: NearfoColors.accent),
                      ),
                      const SizedBox(height: 24),
                      Text(context.l10n.savedReelsNoReelsYet, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: NearfoColors.text)),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.savedReelsBookmarkAppearHere,
                        style: TextStyle(color: NearfoColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadSavedReels(refresh: true),
                  color: NearfoColors.primary,
                  backgroundColor: NearfoColors.card,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 9 / 16,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: _reels.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _reels.length) {
                        // Load more trigger
                        if (!_isLoading) {
                          _loadSavedReels();
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: NearfoColors.primary, strokeWidth: 2),
                          ),
                        );
                      }
                      final reel = _reels[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _SavedReelPlayer(reel: reel),
                          ));
                        },
                        onLongPress: () => _showRemoveDialog(reel),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Thumbnail
                              reel.thumbnailUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: NearfoConfig.resolveMediaUrl(reel.thumbnailUrl),
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: NearfoColors.card,
                                        child: Center(child: Icon(Icons.videocam, color: NearfoColors.textDim, size: 32)),
                                      ),
                                    )
                                  : Container(
                                      color: NearfoColors.card,
                                      child: Center(child: Icon(Icons.videocam, color: NearfoColors.textDim, size: 32)),
                                    ),
                              // Gradient overlay
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (reel.caption.isNotEmpty)
                                        Text(
                                          reel.caption,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.play_arrow, size: 14, color: Colors.white70),
                                          const SizedBox(width: 2),
                                          Text(reel.formattedViews, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                          const Spacer(),
                                          const Icon(Icons.favorite, size: 14, color: Colors.white70),
                                          const SizedBox(width: 2),
                                          Text(reel.formattedLikes, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Bookmark icon
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.bookmark, size: 16, color: NearfoColors.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showRemoveDialog(ReelModel reel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.savedReelsRemoveFromSaved, style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(context.l10n.savedReelsWillBeRemoved, style: TextStyle(color: NearfoColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeBookmark(reel.id);
            },
            child: Text(context.l10n.savedReelsRemove, style: TextStyle(color: NearfoColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _SavedReelPlayer extends StatefulWidget {
  final ReelModel reel;
  const _SavedReelPlayer({required this.reel});
  @override
  State<_SavedReelPlayer> createState() => _SavedReelPlayerState();
}

class _SavedReelPlayerState extends State<_SavedReelPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(NearfoConfig.resolveMediaUrl(widget.reel.videoUrl)))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
          _controller.setLooping(true);
        }
      });
    unawaited(ApiService.recordReelView(widget.reel.id));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
          // Info overlay
          Positioned(
            bottom: 60,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reel.authorName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (widget.reel.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      widget.reel.caption,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          // Side actions
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                _sideAction(Icons.favorite, widget.reel.formattedLikes, () async {
                  await ApiService.toggleReelLike(widget.reel.id);
                }),
                const SizedBox(height: 16),
                _sideAction(Icons.play_arrow, widget.reel.formattedViews, null),
                const SizedBox(height: 16),
                _sideAction(Icons.bookmark, context.l10n.savedReelsSave, () async {
                  await ApiService.toggleReelBookmark(widget.reel.id);
                  if (mounted) Navigator.pop(context);
                }),
              ],
            ),
          ),
          // Tap to pause/play
          GestureDetector(
            onTap: () {
              setState(() {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              });
            },
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _sideAction(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
