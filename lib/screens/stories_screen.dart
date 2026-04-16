import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/l10n_helper.dart';
import 'chat_detail_screen.dart';

class StoriesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> storyGroups;
  final int initialIndex;

  const StoriesScreen({
    Key? key,
    required this.storyGroups,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

// ─── STORY DURATION LIMITS ───
// Instagram-style caps so a long media file can never make a single story
// run past these bounds. The progress bar animation uses these exact values.
const int _kImageStorySeconds = 5;       // Images always play for exactly 5s
const int _kVideoStoryMinSeconds = 3;    // Too-short clips get padded to 3s
const int _kVideoStoryMaxSeconds = 30;   // Long videos truncate at 30s

class _StoriesScreenState extends State<StoriesScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  AnimationController? _progressController;
  int _currentGroupIndex = 0;
  int _currentStoryIndex = 0;
  bool _isPaused = false;
  bool _isReady = false;

  // Story reply
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _isReplying = false;
  bool _isSendingReply = false;

  // Video playback
  VideoPlayerController? _videoController;
  bool _videoInitializing = false;

  // Music playback for stories with background music
  final AudioPlayer _storyMusicPlayer = AudioPlayer();
  String? _currentMusicUrl;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialIndex.clamp(0, widget.storyGroups.length - 1);
    _pageController = PageController(initialPage: _currentGroupIndex);

    // Pre-buffer music for the first story immediately (before UI builds)
    _prebufferFirstStoryMusic();

    // Delay start to avoid build-phase setState issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isReady = true);
        _startStory();
      }
    });
  }

  /// Pre-buffer music for the first story so it plays instantly
  void _prebufferFirstStoryMusic() {
    try {
      if (widget.storyGroups.isEmpty) return;
      final idx = _currentGroupIndex.clamp(0, widget.storyGroups.length - 1);
      final stories = (widget.storyGroups[idx]['stories'] as List?) ?? [];
      if (stories.isEmpty) return;
      final story = stories[0] as Map<String, dynamic>;
      final musicUrl = story['musicUrl']?.toString() ?? story['music_url']?.toString();
      if (musicUrl != null && musicUrl.isNotEmpty) {
        final resolved = musicUrl.startsWith('http') ? musicUrl : NearfoConfig.resolveMediaUrl(musicUrl);
        debugPrint('[Stories] Pre-buffering first story music: $resolved');
        _storyMusicPlayer.setSourceUrl(resolved);
      }
    } catch (e) {
      debugPrint('[Stories] Pre-buffer error: $e');
    }
  }

  // ─── STORY LIFECYCLE ───

  void _startStory() {
    _disposeVideo();
    _disposeProgress();
    // Stop any currently playing music immediately before loading next
    _storyMusicPlayer.stop();

    final story = _getCurrentStory();
    if (story == null) {
      debugPrint('[Stories] No story found at group=$_currentGroupIndex story=$_currentStoryIndex');
      _stopStoryMusic();
      return;
    }

    // ★ Start music loading FIRST (before anything else) so it buffers while UI loads
    _playStoryMusic(story);

    final mediaType = (story['mediaType']?.toString() ?? story['media_type']?.toString())?.toLowerCase() ?? 'image';
    // Support both camelCase and snake_case keys from backend
    final mediaUrl = story['mediaUrl']?.toString() ?? story['media_url']?.toString() ?? story['video']?.toString() ?? story['image']?.toString();

    // Fallback: if mediaUrl is null, try images array
    final String? rawUrl = mediaUrl ?? _getImageUrl(story);
    debugPrint('[Stories] mediaUrl=$mediaUrl rawUrl=$rawUrl keys=${story.keys.toList()}');

    if (rawUrl == null || rawUrl.isEmpty) {
      debugPrint('[Stories] No media URL for story');
      // Still show for _kImageStorySeconds then auto-advance
      _initProgressBar(_kImageStorySeconds);
      return;
    }

    // Resolve relative URLs (e.g. /uploads/...) to absolute
    final resolvedUrl = NearfoConfig.resolveMediaUrl(rawUrl);

    // Update the story map so media widget can use it
    story['_resolvedMediaUrl'] = resolvedUrl;

    if (mediaType == 'video') {
      _initVideoStory(resolvedUrl, story);
    } else {
      // Image stories: fixed 5s (Instagram-standard). Ignore any server-sent
      // `duration` field so a long value can't stretch the progress bar.
      _initProgressBar(_kImageStorySeconds);
    }
    _viewCurrentStory();
  }

  /// Play background music attached to a story (if any)
  /// Called FIRST in _startStory so audio starts buffering immediately
  void _playStoryMusic(Map<String, dynamic> story) {
    final musicUrl = story['musicUrl']?.toString() ?? story['music_url']?.toString();
    if (musicUrl != null && musicUrl.isNotEmpty) {
      final resolved = musicUrl.startsWith('http') ? musicUrl : NearfoConfig.resolveMediaUrl(musicUrl);
      if (_currentMusicUrl != resolved) {
        _currentMusicUrl = resolved;
        debugPrint('[Stories] Loading music FIRST: $resolved');
        // Fire-and-forget: start loading immediately, don't wait for stop() to complete
        _storyMusicPlayer.stop();
        _storyMusicPlayer.setVolume(0.7);
        _storyMusicPlayer.setSourceUrl(resolved).then((_) {
          // Source buffered — start playback immediately
          debugPrint('[Stories] Music buffered, starting playback');
          _storyMusicPlayer.resume();
        }).catchError((e) {
          debugPrint('[Stories] Music buffer error: $e');
          // Fallback: try direct play
          _storyMusicPlayer.play(UrlSource(resolved)).catchError((e2) {
            debugPrint('[Stories] Music fallback play error: $e2');
          });
        });
      }
    } else {
      // No music on this story — stop any playing music
      _stopStoryMusic();
    }
  }

  void _stopStoryMusic() {
    _storyMusicPlayer.stop();
    _currentMusicUrl = null;
  }

  String? _getImageUrl(Map<String, dynamic> story) {
    final images = story['images'];
    if (images is List && images.isNotEmpty) {
      final first = images[0];
      // Handle both string URLs and object format {url: "...", ...}
      if (first is String) return first;
      if (first is Map) return (first['url'] ?? first['secure_url'] ?? first['path'])?.toString();
      return first?.toString();
    }
    return null;
  }

  int? _parseDuration(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  void _initVideoStory(String url, Map<String, dynamic> story) {
    setState(() => _videoInitializing = true);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) return;
      setState(() => _videoInitializing = false);
      controller.play();
      // Cap story video at _kVideoStoryMaxSeconds — anything longer gets
      // truncated to the Instagram-standard 30s window, and the progress
      // bar completes in sync with the clamp so the story auto-advances
      // even if the underlying video is longer.
      final seconds = controller.value.duration.inSeconds;
      final dur = seconds > 0 ? seconds : _kVideoStoryMaxSeconds;
      _initProgressBar(dur.clamp(_kVideoStoryMinSeconds, _kVideoStoryMaxSeconds));
    }).catchError((e) {
      debugPrint('[Stories] Video init error: $e');
      if (!mounted || _videoController != controller) return;
      setState(() => _videoInitializing = false);
      // Video failed to init — fall back to the image-style fixed window so
      // the user isn't stuck on a black screen for up to a minute.
      _initProgressBar(_kImageStorySeconds);
    });
  }

  void _initProgressBar(int durationSeconds) {
    _disposeProgress();
    final controller = AnimationController(
      duration: Duration(seconds: durationSeconds),
      vsync: this,
    );
    _progressController = controller;

    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isPaused && mounted) {
        _nextStory();
      }
    });
    if (!_isPaused) {
      controller.forward();
    }
  }

  // ─── NAVIGATION ───

  Map<String, dynamic>? _getCurrentStory() {
    if (widget.storyGroups.isEmpty) return null;
    if (_currentGroupIndex < 0 || _currentGroupIndex >= widget.storyGroups.length) return null;
    final stories = _getStories(_currentGroupIndex);
    if (_currentStoryIndex < 0 || _currentStoryIndex >= stories.length) return null;
    return stories[_currentStoryIndex] as Map<String, dynamic>;
  }

  List _getStories(int groupIndex) {
    return (widget.storyGroups[groupIndex]['stories'] as List?) ?? [];
  }

  String _getStoryId(Map<String, dynamic> story) {
    // Handle both string and ObjectId formats
    final id = story['_id'];
    if (id is String) return id;
    if (id is Map) return id['\$oid']?.toString() ?? id['_id']?.toString() ?? '';
    return id?.toString() ?? '';
  }

  void _viewCurrentStory() async {
    try {
      final story = _getCurrentStory();
      if (story == null) return;
      final id = _getStoryId(story);
      if (id.isNotEmpty) {
        await ApiService.viewStory(id);
      }
    } catch (e) {
      debugPrint('[Stories] View error: $e');
    }
  }

  void _nextStory() {
    if (widget.storyGroups.isEmpty) return;
    final stories = _getStories(_currentGroupIndex);

    if (_currentStoryIndex < stories.length - 1) {
      setState(() => _currentStoryIndex++);
      _startStory();
    } else {
      _nextGroup();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _startStory();
    } else {
      _previousGroup();
    }
  }

  void _nextGroup() {
    if (_currentGroupIndex < widget.storyGroups.length - 1) {
      setState(() => _currentStoryIndex = 0);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousGroup() {
    if (_currentGroupIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ─── PAUSE / RESUME ───

  void _onPause() {
    if (_isPaused) return;
    setState(() => _isPaused = true);
    _progressController?.stop();
    _videoController?.pause();
    _storyMusicPlayer.pause();
  }

  void _onResume() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    _progressController?.forward();
    _videoController?.play();
    if (_currentMusicUrl != null) _storyMusicPlayer.resume();
  }

  // ─── LIKE ───

  bool _showHeartAnim = false;

  void _toggleLike() async {
    try {
      final story = _getCurrentStory();
      if (story == null) return;
      final id = _getStoryId(story);
      if (id.isEmpty) return;

      // Optimistic UI update
      final wasLiked = story['isLiked'] == true;
      final oldCount = (story['likesCount'] is num) ? (story['likesCount'] as num).toInt() : 0;
      if (mounted) {
        setState(() {
          story['isLiked'] = !wasLiked;
          story['likesCount'] = oldCount + (!wasLiked ? 1 : -1);
        });
      }

      // Show heart animation on like (Instagram-style)
      if (!wasLiked && mounted) {
        setState(() => _showHeartAnim = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showHeartAnim = false);
        });
      }

      final res = await ApiService.toggleStoryLike(id);
      if (res.isSuccess && res.data != null && mounted) {
        // Sync with server data for accurate count
        setState(() {
          story['isLiked'] = res.data!['isLiked'] ?? !wasLiked;
          story['likesCount'] = res.data!['likesCount'] ?? (oldCount + (!wasLiked ? 1 : -1));
        });
      } else if (!res.isSuccess && mounted) {
        // Revert on failure
        setState(() {
          story['isLiked'] = wasLiked;
          story['likesCount'] = oldCount;
        });
      }
    } catch (e) {
      debugPrint('[Stories] Like error: $e');
    }
  }

  // ─── STORY VIEWERS & LIKERS (Instagram-style for own stories) ───

  void _showStoryViewersSheet() async {
    final story = _getCurrentStory();
    if (story == null) return;
    final storyId = _getStoryId(story);
    if (storyId.isEmpty) return;

    _onPause(); // Pause story while viewing

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StoryViewersSheet(storyId: storyId),
    ).whenComplete(() {
      if (mounted) _onResume();
    });
  }

  // ─── HELPERS ───

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (e) {
      return '';
    }
  }

  // ─── DISPOSAL ───

  void _disposeVideo() {
    final vc = _videoController;
    _videoController = null;
    _videoInitializing = false;
    vc?.pause();
    vc?.dispose();
  }

  void _disposeProgress() {
    final pc = _progressController;
    _progressController = null;
    pc?.dispose();
  }

  @override
  void dispose() {
    _disposeProgress();
    _pageController.dispose();
    _disposeVideo();
    _storyMusicPlayer.stop();
    _storyMusicPlayer.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    if (!_isReady || widget.storyGroups.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return PopScope(
      canPop: !_isReplying,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isReplying) {
          _replyController.clear();
          _replyFocusNode.unfocus();
          setState(() => _isReplying = false);
          _onResume();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.storyGroups.length,
        onPageChanged: (index) {
          // Cancel reply mode on page change
          if (_isReplying) {
            _replyController.clear();
            _replyFocusNode.unfocus();
            _isReplying = false;
          }
          setState(() {
            _currentGroupIndex = index;
            _currentStoryIndex = 0;
          });
          _startStory();
        },
        itemBuilder: (context, index) => _buildStoryPage(index),
      ),
    ));
  }

  Widget _buildStoryPage(int groupIndex) {
    final storyGroup = widget.storyGroups[groupIndex];
    final user = (storyGroup['user'] as Map<String, dynamic>?) ?? {};
    final stories = _getStories(groupIndex);

    if (stories.isEmpty || _currentStoryIndex >= stories.length) {
      return const Center(
        child: Text('No stories available', style: TextStyle(color: Colors.white)),
      );
    }

    final currentStory = stories[_currentStoryIndex] as Map<String, dynamic>;

    return GestureDetector(
      onDoubleTap: () {
        // Double-tap to like (Instagram-style)
        final story = _getCurrentStory();
        if (story != null && story['isLiked'] != true) {
          _toggleLike();
        }
      },
      onLongPressStart: (_) => _onPause(),
      onLongPressEnd: (_) => _onResume(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background black
          Container(color: Colors.black),
          // Media
          _buildStoryMedia(currentStory),
          // Progress bars
          _buildProgressBars(stories),
          // Header
          _buildHeader(user, currentStory, isOwn: _isOwnStory(user)),
          // Caption
          _buildCaption(currentStory),
          // Music indicator
          _buildMusicIndicator(currentStory),
          // Footer
          _buildFooter(user, currentStory),
          // Tap areas for navigation
          _buildNavigationAreas(),
          // Heart animation (Instagram-style)
          if (_showHeartAnim)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (_, scale, __) => Transform.scale(
                  scale: scale,
                  child: const Icon(Icons.favorite, color: Colors.red, size: 100),
                ),
              ),
            ),
          // Loading indicator
          if (_videoInitializing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildStoryMedia(Map<String, dynamic> story) {
    final mediaType = (story['mediaType']?.toString() ?? story['media_type']?.toString())?.toLowerCase() ?? 'image';
    final mediaUrl = story['_resolvedMediaUrl']?.toString() ??
        story['mediaUrl']?.toString() ??
        story['media_url']?.toString() ??
        story['video']?.toString() ??
        story['image']?.toString() ??
        _getImageUrl(story);

    // Resolve relative URLs to absolute
    final resolvedMediaUrl = mediaUrl != null ? NearfoConfig.resolveMediaUrl(mediaUrl) : null;

    if (resolvedMediaUrl == null || resolvedMediaUrl.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported, color: Colors.white38, size: 48),
              const SizedBox(height: 8),
              Text('Media not available', style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // ── VIDEO ──
    if (mediaType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        final ar = _videoController!.value.aspectRatio;
        return SizedBox.expand(
          child: Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: (ar.isFinite && ar > 0) ? ar : 9 / 16,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        );
      }
      return Container(color: Colors.black);
    }

    // ── IMAGE ──
    return Container(
      color: Colors.black,
      child: CachedNetworkImage(
        imageUrl: resolvedMediaUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(
          color: Colors.grey[900],
          child: const Center(child: CircularProgressIndicator(color: Colors.white24)),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBars(List<dynamic> stories) {
    final progressValue = _progressController?.value ?? 0.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(
              stories.length,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: index < _currentStoryIndex
                            ? 1.0
                            : (index == _currentStoryIndex ? progressValue : 0.0),
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> user, Map<String, dynamic> story, {bool isOwn = false}) {
    final avatarUrl = user['avatarUrl'] as String?;
    final name = user['name'] as String? ?? 'Unknown';
    final handle = user['handle'] as String?;
    final createdAt = story['createdAt'] as String?;
    final timeAgo = _getTimeAgo(createdAt);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
          child: Row(
            children: [
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatarUrl)),
                  backgroundColor: Colors.grey[800],
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        handle ?? name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (timeAgo.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showStoryOptionsMenu(story, isOwn: isOwn),
                child: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaption(Map<String, dynamic> story) {
    final caption = (story['caption'] as String?) ?? (story['content'] as String?);
    if (caption == null || caption.isEmpty) return const SizedBox();

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            caption,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildMusicIndicator(Map<String, dynamic> story) {
    final musicName = story['musicName']?.toString() ?? story['music_name']?.toString();
    if (musicName == null || musicName.isEmpty) return const SizedBox();

    return Positioned(
      bottom: 130,
      left: 16,
      right: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note, color: Colors.purpleAccent, size: 16),
                const SizedBox(width: 6),
                Text(musicName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Map<String, dynamic> user, Map<String, dynamic> story) {
    final isOwn = _isOwnStory(user);
    final viewsCount = story['viewsCount'] as int? ?? 0;
    final likesCount = story['likesCount'] as int? ?? 0;
    final isLiked = story['isLiked'] as bool? ?? false;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              if (isOwn) ...[
                GestureDetector(
                  onTap: _showStoryViewersSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('$viewsCount', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 14),
                        Icon(Icons.favorite, color: likesCount > 0 ? Colors.red : Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text('$likesCount', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    padding: const EdgeInsets.only(left: 14, right: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            focusNode: _replyFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Send message...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.send,
                            onTap: () {
                              if (!_isReplying) {
                                setState(() => _isReplying = true);
                                _onPause();
                              }
                            },
                            onSubmitted: (_) => _sendStoryReply(user),
                          ),
                        ),
                        if (_isReplying)
                          GestureDetector(
                            onTap: () => _sendStoryReply(user),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _isSendingReply
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                                : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _toggleLike,
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 26,
                  ),
                ),
                if (!_isReplying) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _openChatWithUser(user),
                    child: const Icon(Icons.send_outlined, color: Colors.white, size: 24),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationAreas() {
    return Positioned.fill(
      top: 80,
      bottom: 80,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _previousStory,
              behavior: HitTestBehavior.translucent,
              child: Container(),
            ),
          ),
          Expanded(
            flex: 7,
            child: GestureDetector(
              onTap: _nextStory,
              behavior: HitTestBehavior.translucent,
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STORY OPTIONS MENU (Delete / Report) ───

  void _showStoryOptionsMenu(Map<String, dynamic> story, {bool isOwn = false}) {
    _onPause();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
              if (isOwn) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                  title: Text(context.l10n.storiesDeleteStory, style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteStory(story);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white70, size: 24),
                  title: const Text('Report Story', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onResume();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Story reported'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) _onResume();
    });
  }

  void _confirmDeleteStory(Map<String, dynamic> story) {
    _onPause();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Story?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This story will be permanently deleted. This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onResume();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeDeleteStory(story);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteStory(Map<String, dynamic> story) async {
    final storyId = _getStoryId(story);
    if (storyId.isEmpty) return;

    try {
      final res = await ApiService.deleteStory(storyId);
      if (mounted) {
        if (res.isSuccess) {
          // Remove the story from the current group
          final stories = _getStories(_currentGroupIndex);
          stories.removeWhere((s) {
            final sid = s is Map<String, dynamic> ? _getStoryId(s) : '';
            return sid == storyId;
          });

          if (stories.isEmpty) {
            // No more stories in this group — go back
            Navigator.of(context).pop();
          } else {
            // Move to next story or previous
            setState(() {
              if (_currentStoryIndex >= stories.length) {
                _currentStoryIndex = stories.length - 1;
              }
            });
            _startStory();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story deleted'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        } else {
          _onResume();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.errorMessage ?? 'Failed to delete'), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _onResume();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error, try again'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
        );
      }
    }
  }

  bool _isOwnStory(Map<String, dynamic> user) {
    final myId = context.read<AuthProvider>().user?.id;
    if (myId == null) return false;
    final storyUserId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    return storyUserId == myId;
  }

  /// Send an inline story reply as a DM (like Instagram story replies)
  Future<void> _sendStoryReply(Map<String, dynamic> user) async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSendingReply) return;

    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    if (userId.isEmpty) return;

    setState(() => _isSendingReply = true);

    try {
      // Step 1: Create or get existing 1:1 chat (same pattern as ChatDetailScreen)
      final chatRes = await ApiService.createOrGetChat(userId);
      bool success = false;

      if (chatRes.isSuccess && chatRes.data != null) {
        final chatId = chatRes.data!['_id']?.toString() ?? chatRes.data!['id']?.toString() ?? '';
        if (chatId.isNotEmpty) {
          // Step 2: Send story reply as a DM in that chat
          final msgRes = await ApiService.sendMessage(
            chatId: chatId,
            content: '📖 Story reply: $text',
            type: 'text',
          );
          success = msgRes.isSuccess;
        }
      }

      if (mounted) {
        _replyController.clear();
        _replyFocusNode.unfocus();
        setState(() {
          _isReplying = false;
          _isSendingReply = false;
        });
        _onResume();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Reply sent!' : 'Couldn\'t send reply'),
            backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Network error, try again'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    }
  }

  /// Open DM chat with the story author (like Instagram story replies)
  void _openChatWithUser(Map<String, dynamic> user) {
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    final name = user['name'] as String? ?? 'Unknown';
    final handle = user['handle'] as String?;
    final avatarUrl = user['avatarUrl'] as String?;

    if (userId.isEmpty) return;

    // Pause story while navigating to chat
    _onPause();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          recipientId: userId,
          recipientName: name,
          recipientHandle: handle,
          recipientAvatar: avatarUrl != null ? NearfoConfig.resolveMediaUrl(avatarUrl) : null,
        ),
      ),
    ).then((_) {
      // Resume story when coming back from chat
      if (mounted) _onResume();
    });
  }
}

// ──────────────────────────────────────────────────────────
// Story Viewers & Likers Bottom Sheet (Instagram-style)
// ──────────────────────────────────────────────────────────

class _StoryViewersSheet extends StatefulWidget {
  final String storyId;
  const _StoryViewersSheet({required this.storyId});

  @override
  State<_StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<_StoryViewersSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _viewers = [];
  List<Map<String, dynamic>> _likers = [];
  Set<String> _likerIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Fetch viewers and likers in parallel
      final results = await Future.wait([
        ApiService.getStoryViewers(widget.storyId),
        ApiService.getStoryLikers(widget.storyId),
      ]);

      final viewersRes = results[0];
      final likersRes = results[1];

      if (mounted) {
        final viewers = (viewersRes.isSuccess && viewersRes.data != null) ? viewersRes.data! : <Map<String, dynamic>>[];
        final likers = (likersRes.isSuccess && likersRes.data != null) ? likersRes.data! : <Map<String, dynamic>>[];

        debugPrint('[StoryViewers] Viewers: ${viewers.length}, Likers: ${likers.length}');
        if (viewers.isNotEmpty) debugPrint('[StoryViewers] First viewer keys: ${viewers[0].keys.toList()}');
        if (likers.isNotEmpty) debugPrint('[StoryViewers] First liker keys: ${likers[0].keys.toList()}');

        // Build a set of liker user IDs for cross-referencing
        final likerIdSet = <String>{};
        for (final liker in likers) {
          final id = _getUserId(liker);
          if (id.isNotEmpty) likerIdSet.add(id);
        }

        setState(() {
          _viewers = viewers;
          _likers = likers;
          _likerIds = likerIdSet;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[StoryViewers] Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Extract user ID from various API formats
  String _getUserId(Map<String, dynamic> item) {
    // Direct ID
    final directId = item['_id']?.toString() ?? item['id']?.toString() ?? '';
    if (directId.isNotEmpty) return directId;
    // Nested user object
    final user = item['user'];
    if (user is Map<String, dynamic>) {
      return user['_id']?.toString() ?? user['id']?.toString() ?? '';
    }
    if (user is String) return user;
    return '';
  }

  /// Check if a viewer has liked the story
  bool _hasLiked(Map<String, dynamic> viewer) {
    // Check direct flags first
    if (viewer['liked'] == true || viewer['isLiked'] == true || viewer['hasLiked'] == true) return true;
    // Cross-reference with likers list by user ID
    final viewerId = _getUserId(viewer);
    if (viewerId.isNotEmpty && _likerIds.contains(viewerId)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Use likers from API, fallback to filtered viewers
    final displayLikers = _likers.isNotEmpty ? _likers : _viewers.where(_hasLiked).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Viewers (${_viewers.length})'),
              Tab(text: 'Likes (${displayLikers.length})'),
            ],
          ),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(_viewers, showLikeIcon: true),
                      displayLikers.isEmpty
                          ? const Center(child: Text('No likes yet', style: TextStyle(color: Colors.white54, fontSize: 14)))
                          : _buildUserList(displayLikers, showLikeIcon: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, {required bool showLikeIcon}) {
    if (users.isEmpty) {
      return const Center(child: Text('No viewers yet', style: TextStyle(color: Colors.white54, fontSize: 14)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final viewer = users[i];
        // Support both nested user object and flat format
        final userObj = viewer['user'] is Map<String, dynamic> ? viewer['user'] as Map<String, dynamic> : viewer;
        final name = userObj['name']?.toString() ?? 'Unknown';
        final handle = userObj['handle']?.toString();
        final avatar = userObj['avatarUrl']?.toString() ?? userObj['avatar']?.toString();
        final liked = _hasLiked(viewer);
        final viewedAt = viewer['viewedAt']?.toString() ?? viewer['viewed_at']?.toString() ?? viewer['createdAt']?.toString() ?? viewer['created_at']?.toString();

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[700],
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(NearfoConfig.resolveMediaUrl(avatar))
                : null,
            child: avatar == null || avatar.isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                : null,
          ),
          title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: handle != null
              ? Text('@$handle', style: TextStyle(color: Colors.grey[500], fontSize: 12))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLikeIcon && liked)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.favorite, color: Colors.red, size: 18),
                ),
              if (viewedAt != null)
                Text(
                  _formatTime(viewedAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }
}
