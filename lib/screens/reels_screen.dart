import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reel_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/comments_sheet.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../l10n/l10n_helper.dart';
import 'user_profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => ReelsScreenState();
}

class ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final List<ReelModel> _reels = [];
  final Map<int, VideoPlayerController> _controllers = {};
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  int _currentIndex = 0;
  String _feedMode = 'mixed'; // mixed, local, global
  final Set<int> _likeInProgress = <int>{};

  bool _isTabActive = false; // starts false — MainScreen calls resumeCurrent() when user enters Reels tab

  /// Called by MainScreen when switching away from Reels tab
  void pauseAll() {
    _isTabActive = false;
    _controllers[_currentIndex]?.pause();
  }

  /// Called by MainScreen when switching back to Reels tab
  void resumeCurrent() {
    _isTabActive = true;
    _controllers[_currentIndex]?.play();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controllers[_currentIndex]?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_isTabActive) {
        _controllers[_currentIndex]?.play();
      }
    }
  }

  Future<void> _loadReels({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _reels.clear();
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    final response = await ApiService.getReelsFeed(
      mode: _feedMode,
      page: _page,
      limit: 10,
    );

    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _reels.addAll(response.data!);
        _hasMore = response.hasMore;
        _page++;
        _isLoading = false;
      });
      // Preload first 2 videos
      for (int i = 0; i < _reels.length && i < 2; i++) {
        _initController(i);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initController(int index) async {
    if (_controllers.containsKey(index) || index >= _reels.length) return;

    final rawVideoUrl = _reels[index].videoUrl;
    // Resolve relative URLs to absolute before validation
    final videoUrl = NearfoConfig.resolveMediaUrl(rawVideoUrl);
    if (videoUrl.isEmpty || (!videoUrl.startsWith('http://') && !videoUrl.startsWith('https://'))) {
      debugPrint('[ReelsScreen] Invalid video URL at index $index: raw=$rawVideoUrl resolved=$videoUrl');
      return;
    }
    debugPrint('[ReelsScreen] Playing reel $index: $videoUrl');

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
    );
    _controllers[index] = controller;

    try {
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      // Check controller wasn't disposed while we were awaiting
      if (!_controllers.containsKey(index)) return;
      controller.setLooping(true);
      controller.setVolume(1.0);
      if (index == _currentIndex && _isTabActive) {
        controller.play();
        _recordView(index);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[ReelsScreen] Video init error at index $index: $e');
    }
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _reels.length) return;

    // Pause previous
    _controllers[_currentIndex]?.pause();

    _currentIndex = index;

    // Play current
    if (_controllers.containsKey(index)) {
      _controllers[index]!.seekTo(Duration.zero);
      if (_isTabActive) {
        _controllers[index]!.play();
      }
    } else {
      _initController(index);
    }

    // Record view
    _recordView(index);

    // Preload next 2
    _initController(index + 1);
    _initController(index + 2);

    // Dispose controllers that are far away to save memory
    final keysToRemove = _controllers.keys.where((k) => (k - index).abs() > 3).toList();
    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }

    // Load more when near end
    if (index >= _reels.length - 3 && _hasMore && !_isLoading) {
      _loadReels();
    }

    setState(() {});
  }

  void _recordView(int index) {
    if (index < _reels.length) {
      unawaited(ApiService.recordReelView(_reels[index].id));
    }
  }

  void _toggleLike(int index) async {
    if (index < 0 || index >= _reels.length) return;
    if (_likeInProgress.contains(index)) return;
    final reel = _reels[index];
    final reelId = reel.id;
    _likeInProgress.add(index);
    // Optimistic update
    setState(() {
      _reels[index] = reel.copyWith(
        isLiked: !reel.isLiked,
        likesCount: reel.isLiked ? reel.likesCount - 1 : reel.likesCount + 1,
      );
    });

    final response = await ApiService.toggleReelLike(reelId);
    if (!response.isSuccess && mounted) {
      // Revert — re-find by ID since index may have shifted
      final currentIdx = _reels.indexWhere((r) => r.id == reelId);
      if (currentIdx != -1) {
        setState(() {
          _reels[currentIdx] = reel;
        });
      }
    }
    _likeInProgress.remove(index);
  }

  void _toggleBookmark(int index) async {
    if (index < 0 || index >= _reels.length) return;
    final reel = _reels[index];
    final reelId = reel.id;
    setState(() {
      _reels[index] = reel.copyWith(isBookmarked: !reel.isBookmarked);
    });

    final response = await ApiService.toggleReelBookmark(reelId);
    if (!response.isSuccess && mounted) {
      // Revert — re-find by ID since index may have shifted
      final currentIdx = _reels.indexWhere((r) => r.id == reelId);
      if (currentIdx != -1) {
        setState(() {
          _reels[currentIdx] = reel;
        });
      }
    }
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  void _showReelMenu(int index) {
    final reel = _reels[index];
    final myId = context.read<AuthProvider>().user?.id ?? '';
    final isOwner = reel.author.id == myId;
    _controllers[_currentIndex]?.pause();

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
              decoration: BoxDecoration(color: NearfoColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            if (isOwner)
              ListTile(
                leading: Icon(Icons.delete_outline, color: NearfoColors.danger),
                title: Text(context.l10n.reelsDeleteReel, style: TextStyle(color: NearfoColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteReel(index);
                },
              ),
            if (!isOwner)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: NearfoColors.warning),
                title: Text(context.l10n.reelsReportReel, style: TextStyle(color: NearfoColors.warning)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.reelsReportSubmitted), backgroundColor: NearfoColors.success),
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: NearfoColors.textMuted),
              title: Text(context.l10n.reelsShareReel, style: TextStyle(color: NearfoColors.text)),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(context.l10n.reelsCheckOut(reel.videoUrl));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((_) {
      _controllers[_currentIndex]?.play();
    });
  }

  void _confirmDeleteReel(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.reelsDeleteTitle, style: TextStyle(color: NearfoColors.text)),
        content: Text(context.l10n.reelsCannotUndo, style: TextStyle(color: NearfoColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.reelsCancel, style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (index < 0 || index >= _reels.length) return;
              final reel = _reels[index];
              final reelId = reel.id;
              final res = await ApiService.deleteReel(reelId);
              if (res.isSuccess && mounted) {
                // Re-find by ID since index may have shifted during await
                final currentIdx = _reels.indexWhere((r) => r.id == reelId);
                if (currentIdx != -1) {
                  setState(() => _reels.removeAt(currentIdx));
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.reelsDeleted), backgroundColor: NearfoColors.success),
                );
              }
            },
            child: Text(context.l10n.reelsDelete, style: TextStyle(color: NearfoColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showComments(int index) {
    final reel = _reels[index];
    _controllers[_currentIndex]?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(contentId: reel.id, commentsCount: reel.commentsCount, isReel: true),
    ).then((_) {
      _controllers[_currentIndex]?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main vertical swipe feed
          if (_reels.isEmpty && _isLoading)
            Center(
              child: CircularProgressIndicator(color: NearfoColors.primary),
            )
          else if (_reels.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_outlined, size: 64, color: NearfoColors.textDim),
                  const SizedBox(height: 16),
                  Text(context.l10n.reelsNoReels, style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(context.l10n.reelsBeFirst, style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
                ],
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _buildReelItem(index);
              },
            ),

          // Top bar (For You / Nearby toggle)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFeedToggle(context.l10n.reelsFollowing, 'following'),
                  const SizedBox(width: 16),
                  _buildFeedToggle(context.l10n.reelsForYou, 'mixed'),
                  const SizedBox(width: 16),
                  _buildFeedToggle(context.l10n.reelsNearby, 'local'),
                  const Spacer(),
                  // Create reel button
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/createReel').then((result) {
                      if (result == true) _loadReels(refresh: true);
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
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

  Widget _buildFeedToggle(String label, String mode) {
    final isActive = _feedMode == mode;
    return GestureDetector(
      onTap: () {
        if (_feedMode != mode) {
          _feedMode = mode;
          _loadReels(refresh: true);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 16,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelItem(int index) {
    final reel = _reels[index];
    final controller = _controllers[index];
    final isInitialized = controller?.value.isInitialized ?? false;

    return Stack(
        fit: StackFit.expand,
        children: [
          // Portrait frame: blurred background + centered video
          if (isInitialized)
            _buildPortraitFrameVideo(controller!)
          else
            _buildReelLoading(reel),

          // Pause icon overlay
          if (controller != null && !controller.value.isPlaying && isInitialized)
            Center(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 80,
                color: Colors.white.withOpacity(0.6),
              ),
            ),

          // Gradient overlays (top and bottom)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // Tap/double-tap zone — positioned BEFORE action buttons so buttons win hit-test
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _togglePlayPause,
              onDoubleTap: () {
                if (!reel.isLiked) _toggleLike(index);
                _showDoubleTapHeart();
              },
            ),
          ),

          // Right side action buttons
          Positioned(
            right: 12,
            bottom: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Author avatar
                _buildAuthorAvatar(reel),
                const SizedBox(height: 20),
                // Like
                _buildActionButton(
                  icon: reel.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: reel.formattedLikes,
                  color: reel.isLiked ? NearfoColors.danger : Colors.white,
                  onTap: () => _toggleLike(index),
                ),
                const SizedBox(height: 16),
                // Comment
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${reel.commentsCount}',
                  onTap: () => _showComments(index),
                ),
                const SizedBox(height: 16),
                // Share
                _buildActionButton(
                  icon: Icons.send_rounded,
                  label: '${reel.sharesCount}',
                  onTap: () {
                    Share.share('Check out this reel on Nearfo! ${reel.videoUrl}');
                  },
                ),
                const SizedBox(height: 16),
                // Bookmark
                _buildActionButton(
                  icon: reel.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: '',
                  color: reel.isBookmarked ? NearfoColors.warning : Colors.white,
                  onTap: () => _toggleBookmark(index),
                ),
                const SizedBox(height: 16),
                // More options (3-dot menu)
                _buildActionButton(
                  icon: Icons.more_horiz_rounded,
                  label: '',
                  onTap: () => _showReelMenu(index),
                ),
                const SizedBox(height: 16),
                // Audio disc
                _buildAudioDisc(reel),
              ],
            ),
          ),

          // Bottom info: Author name, caption, audio, location
          Positioned(
            bottom: 16,
            left: 12,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Author
                Row(
                  children: [
                    Text(
                      '@${reel.author.handle}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reel.author.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 14, color: NearfoColors.accent),
                    ],
                  ],
                ),
                if (reel.caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ExpandableCaption(caption: reel.caption),
                ],
                const SizedBox(height: 8),
                // Audio marquee
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reel.audioName.isNotEmpty ? reel.audioName : 'Original Audio - ${reel.author.name}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (reel.city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: NearfoColors.accent),
                      const SizedBox(width: 2),
                      Text(
                        reel.city,
                        style: TextStyle(color: NearfoColors.accent, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Progress bar at bottom
          if (isInitialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: NearfoColors.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
        ],
    );
  }

  /// Smooth loading state with thumbnail background + pulse animation + loading text
  Widget _buildReelLoading(ReelModel reel) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail background (blurred)
        if (reel.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: NearfoConfig.resolveMediaUrl(reel.thumbnailUrl),
            fit: BoxFit.cover,
            color: Colors.black45,
            colorBlendMode: BlendMode.darken,
            errorWidget: (_, __, ___) => Container(color: Colors.black),
            placeholder: (_, __) => Container(color: Colors.black),
          )
        else
          Container(color: const Color(0xFF111111)),

        // Blur overlay on thumbnail
        if (reel.thumbnailUrl.isNotEmpty)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

        // Centered loading indicator
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing circle with play icon
              _PulsingLoader(),
              const SizedBox(height: 16),
              // Loading text
              Text(
                context.l10n.reelsLoading,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Portrait frame: if video is portrait (aspect ratio < 0.7), show full screen.
  /// If landscape or square, show blurred zoomed background + crisp centered video.
  Widget _buildPortraitFrameVideo(VideoPlayerController controller) {
    final aspectRatio = controller.value.aspectRatio;
    // Portrait threshold: 9:16 = 0.5625, anything <= ~0.75 is portrait-ish
    final isPortrait = aspectRatio <= 0.75;

    if (isPortrait) {
      // Portrait video — fill the screen naturally
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    // Landscape or square video — show portrait frame with blurred background
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Blurred zoomed-in background
        ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        // Layer 2: Heavy blur + dark overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        // Layer 3: Actual video centered with rounded corners
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        // Layer 4: Subtle vignette around the frame
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorAvatar(ReelModel reel) {
    return GestureDetector(
      onTap: () {
        if (reel.author.handle.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                handle: reel.author.handle,
                userId: reel.author.id,
              ),
            ),
          );
        }
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: reel.author.avatarUrl != null && reel.author.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: NearfoConfig.resolveMediaUrl(reel.author.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: NearfoColors.primary,
                      child: Center(
                        child: Text(
                          reel.author.initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: -6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: NearfoColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(Icons.add, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioDisc(ReelModel reel) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30, width: 8),
        image: reel.author.avatarUrl != null && reel.author.avatarUrl!.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(reel.author.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
        color: NearfoColors.card,
      ),
      child: reel.author.avatarUrl == null || reel.author.avatarUrl!.isEmpty
          ? const Icon(Icons.music_note, size: 12, color: Colors.white)
          : null,
    );
  }

  void _showDoubleTapHeart() {
    // Simple haptic feedback for double-tap like
    HapticFeedback.lightImpact();
  }
}

// Pulsing loader for reel loading state
class _PulsingLoader extends StatefulWidget {
  @override
  State<_PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<_PulsingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Transform.scale(
        scale: _scaleAnim.value,
        child: Opacity(
          opacity: _opacityAnim.value,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white70,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

// Expandable caption widget
class _ExpandableCaption extends StatefulWidget {
  final String caption;
  const _ExpandableCaption({required this.caption});

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: RichText(
        maxLines: _expanded ? 10 : 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          children: _buildCaptionSpans(),
        ),
      ),
    );
  }

  List<TextSpan> _buildCaptionSpans() {
    final spans = <TextSpan>[];
    final words = widget.caption.split(' ');

    for (final word in words) {
      if (word.startsWith('#')) {
        spans.add(TextSpan(
          text: '$word ',
          style: TextStyle(color: NearfoColors.accent, fontWeight: FontWeight.w600),
        ));
      } else if (word.startsWith('@')) {
        spans.add(TextSpan(
          text: '$word ',
          style: TextStyle(color: NearfoColors.primaryLight, fontWeight: FontWeight.w600),
        ));
      } else {
        spans.add(TextSpan(text: '$word '));
      }
    }

    if (!_expanded && widget.caption.length > 80) {
      spans.add(const TextSpan(
        text: '... more',
        style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500),
      ));
    }

    return spans;
  }
}
