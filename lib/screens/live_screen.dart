import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../l10n/l10n_helper.dart';

// ════════════════════════════════════════════════════════════
// LIVE SCREEN — YouTube-style premium live streaming UI
// Features: Thumbnail cards, pulsing LIVE badges, real-time
// viewer count, live chat, host overlay, animated transitions
// ════════════════════════════════════════════════════════════

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _streams = [];
  bool _loading = true;
  late AnimationController _pulseController;
  late AnimationController _fabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadStreams();
    // Auto-refresh every 15s for live feel
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadStreams(silent: true));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStreams({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final res = await ApiService.getActiveLiveStreams();
    if (res.isSuccess && res.data != null && mounted) {
      setState(() { _streams = res.data!; _loading = false; });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Go Live Flow ──
  void _goLive() async {
    final titleController = TextEditingController();
    try {
      final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _GoLiveSheet(titleController: titleController),
      );

      if (result != null && mounted) {
        final title = result['title'] ?? 'Live';
        final category = result['category'] ?? 'General';
        // Show a countdown overlay
        await _showCountdown();
        final res = await ApiService.startLiveStream(title: title, description: category);
        if (res.isSuccess && mounted) {
          final streamData = res.data;
          _loadStreams();
          if (streamData != null) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => _LiveBroadcasterScreen(stream: streamData),
            )).then((_) => _loadStreams());
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.errorMessage ?? 'Failed to start live'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      titleController.dispose();
    }
  }

  Future<void> _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('$i', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white))),
          backgroundColor: Colors.red.withOpacity(0.9),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.35, vertical: 20),
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void _joinStream(Map<String, dynamic> stream) async {
    final streamId = stream['_id']?.toString() ?? '';
    await ApiService.joinLiveStream(streamId);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _LiveViewerScreen(stream: stream),
      )).then((_) => _loadStreams());
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Premium AppBar ──
          SliverAppBar(
            backgroundColor: NearfoColors.bg,
            floating: true,
            snap: true,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: NearfoColors.text, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3 + _pulseController.value * 0.4),
                          blurRadius: 4 + _pulseController.value * 6,
                          spreadRadius: _pulseController.value * 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Live', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w800, fontSize: 22)),
                const SizedBox(width: 8),
                if (_streams.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_streams.length}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            actions: [
              // Go Live button
              GestureDetector(
                onTap: _goLive,
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF4444)]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(context.l10n.liveGoLive, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Body ──
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)),
            )
          else if (_streams.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildStreamCard(_streams[index], index),
                  childCount: _streams.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.red.withOpacity(0.1 + _pulseController.value * 0.1), Colors.red.withOpacity(0.05)],
                  ),
                ),
                child: Icon(Icons.live_tv_rounded, size: 48, color: Colors.red.withOpacity(0.6 + _pulseController.value * 0.3)),
              ),
            ),
            const SizedBox(height: 24),
            Text('No one is live right now',
              style: TextStyle(color: NearfoColors.text, fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Start a live stream and connect\nwith people near you!',
              style: TextStyle(color: NearfoColors.textMuted, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _goLive,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF4444)]),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(context.l10n.liveStartTitle, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stream Card (YouTube-style) ──
  Widget _buildStreamCard(Map<String, dynamic> stream, int index) {
    final host = stream['host'] as Map<String, dynamic>? ?? {};
    final title = (stream['title'] as String?) ?? 'Live';
    final viewers = (stream['currentViewers'] as int?) ?? 0;
    final avatar = host['avatarUrl']?.toString() ?? '';
    final name = host['name']?.toString() ?? '';
    final handle = host['handle']?.toString() ?? '';
    final isVerified = (host['isVerified'] as bool?) ?? false;
    final startedAt = stream['startedAt']?.toString() ?? stream['createdAt']?.toString();
    final thumbnailUrl = stream['thumbnailUrl']?.toString() ?? '';

    // Calculate duration
    String duration = '';
    if (startedAt != null) {
      try {
        final start = DateTime.parse(startedAt);
        final diff = DateTime.now().toUtc().difference(start);
        if (diff.inHours > 0) {
          duration = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else if (diff.inMinutes > 0) {
          duration = '${diff.inMinutes}m';
        } else {
          duration = 'Just started';
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _joinStream(stream),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: NearfoColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail area ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background — thumbnail or gradient
                    if (thumbnailUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: NearfoConfig.resolveMediaUrl(thumbnailUrl),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildThumbnailPlaceholder(name, index),
                      )
                    else
                      _buildThumbnailPlaceholder(name, index),

                    // Dark gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),

                    // ── LIVE badge (top-left) ──
                    Positioned(
                      top: 12, left: 12,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3 + _pulseController.value * 0.3),
                                blurRadius: 6 + _pulseController.value * 4,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                              SizedBox(width: 4),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Viewer count (top-right) ──
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text(_formatViewers(viewers),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                    // ── Duration badge (bottom-right) ──
                    if (duration.isNotEmpty)
                      Positioned(
                        bottom: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, color: Colors.white70, size: 12),
                              const SizedBox(width: 4),
                              Text(duration, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),

                    // ── Title (bottom-left) ──
                    Positioned(
                      bottom: 12, left: 12, right: 80,
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 8, color: Colors.black54)]),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Host info row ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: NearfoColors.card,
                      backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                      child: avatar.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + handle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified, color: NearfoColors.primary, size: 14),
                            ],
                          ],
                        ),
                        Text('@$handle', style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Join button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF4444)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Watch', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(String name, int index) {
    final gradients = [
      [const Color(0xFF1a1a2e), const Color(0xFF16213e), const Color(0xFF0f3460)],
      [const Color(0xFF2d1b69), const Color(0xFF1b1464), const Color(0xFF11084a)],
      [const Color(0xFF0d0d0d), const Color(0xFF1a1a1a), const Color(0xFF2d2d2d)],
      [const Color(0xFF1B0030), const Color(0xFF3B0062), const Color(0xFF6C0099)],
    ];
    final g = gradients[index % gradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Icon(Icons.live_tv_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
      ),
    );
  }

  String _formatViewers(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count watching';
  }
}

// ════════════════════════════════════════════════════════════
// GO LIVE BOTTOM SHEET — Premium pre-stream setup
// ════════════════════════════════════════════════════════════

class _GoLiveSheet extends StatefulWidget {
  final TextEditingController titleController;
  const _GoLiveSheet({required this.titleController});

  @override
  State<_GoLiveSheet> createState() => _GoLiveSheetState();
}

class _GoLiveSheetState extends State<_GoLiveSheet> {
  String _selectedCategory = 'General';
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = [
      context.l10n.liveCategoryGeneral,
      context.l10n.liveCategoryGaming,
      context.l10n.liveCategoryMusic,
      context.l10n.liveCategoryCooking,
      context.l10n.liveCategoryFitness,
      context.l10n.liveCategoryEducation,
      context.l10n.liveCategoryChat,
      context.l10n.liveCategoryOther,
    ];
    _selectedCategory = _categories[0];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF4444)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.liveGoLive, style: TextStyle(color: NearfoColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('Start streaming to your audience', style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Title input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: widget.titleController,
              style: TextStyle(color: NearfoColors.text, fontSize: 16),
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'Give your live a title...',
                hintStyle: TextStyle(color: NearfoColors.textDim),
                counterStyle: TextStyle(color: NearfoColors.textDim, fontSize: 11),
                filled: true,
                fillColor: NearfoColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
                prefixIcon: Icon(Icons.title, color: NearfoColors.textDim),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Category selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Category', style: TextStyle(color: NearfoColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isSelected = _categories[i] == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = _categories[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red : NearfoColors.bg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isSelected ? Colors.red : NearfoColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(_categories[i],
                      style: TextStyle(
                        color: isSelected ? Colors.white : NearfoColors.textMuted,
                        fontSize: 13, fontWeight: FontWeight.w600,
                      )),
                  ),
                );
              },
            ),
          ),
          const Spacer(),
          // Go Live button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: GestureDetector(
              onTap: () {
                final title = widget.titleController.text.trim().isEmpty
                    ? context.l10n.liveLiveDefault
                    : widget.titleController.text.trim();
                Navigator.pop(context, {'title': title, 'category': _selectedCategory});
              },
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF4444)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
                    SizedBox(width: 10),
                    Text('Go Live Now', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// LIVE VIEWER SCREEN — Full-screen live viewing experience
// ════════════════════════════════════════════════════════════

class _LiveViewerScreen extends StatefulWidget {
  final Map<String, dynamic> stream;
  const _LiveViewerScreen({required this.stream});

  @override
  State<_LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<_LiveViewerScreen> with TickerProviderStateMixin {
  final _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  final _scrollController = ScrollController();
  late AnimationController _heartController;
  bool _showHeart = false;
  int _viewerCount = 0;
  int _likeCount = 0;
  Timer? _refreshTimer;
  Timer? _chatPollTimer;
  bool _streamEnded = false;

  String get _streamId => widget.stream['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _viewerCount = (widget.stream['currentViewers'] as int?) ?? 0;

    // Add initial welcome message
    _chatMessages.add({'user': 'System', 'text': 'Welcome to the live stream!', 'isSystem': true});

    // Refresh viewer/like count every 10s
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshStreamInfo());
    // Poll for new chat messages every 5s
    _chatPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollChat());
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _heartController.dispose();
    _refreshTimer?.cancel();
    _chatPollTimer?.cancel();
    super.dispose();
  }

  /// Refresh viewer count and like count from server
  Future<void> _refreshStreamInfo() async {
    if (_streamEnded || _streamId.isEmpty) return;
    final res = await ApiService.getLiveStreamInfo(_streamId);
    if (res.isSuccess && res.data != null && mounted) {
      final info = res.data!;
      // Check if stream ended
      if (info['status'] == 'ended' || info['isActive'] == false) {
        setState(() => _streamEnded = true);
        _refreshTimer?.cancel();
        _chatPollTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This live stream has ended'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
        return;
      }
      setState(() {
        _viewerCount = (info['currentViewers'] as int?) ?? _viewerCount;
        _likeCount = (info['likes'] as int?) ?? (info['likeCount'] as int?) ?? _likeCount;
      });
    }
  }

  /// Poll for new chat messages
  Future<void> _pollChat() async {
    if (_streamEnded || _streamId.isEmpty) return;
    final res = await ApiService.getLiveComments(_streamId);
    if (res.isSuccess && res.data != null && mounted) {
      final serverMessages = res.data!;
      // Only add messages we don't already have (compare by length — simple dedup)
      final nonSystemCount = _chatMessages.where((m) => m['isSystem'] != true && m['isMe'] != true).length;
      if (serverMessages.length > nonSystemCount) {
        // Add new messages from server
        final newMsgs = serverMessages.skip(nonSystemCount);
        final auth = context.read<AuthProvider>();
        final myId = auth.user?.id ?? '';
        for (final msg in newMsgs) {
          final senderId = msg['userId']?.toString() ?? msg['user']?['_id']?.toString() ?? '';
          if (senderId == myId) continue; // Skip own messages (already shown)
          final senderName = msg['userName']?.toString() ?? msg['user']?['name']?.toString() ?? 'Viewer';
          setState(() {
            _chatMessages.add({'user': senderName, 'text': msg['text']?.toString() ?? ''});
          });
        }
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Leave the stream and go back
  void _leaveStream() async {
    if (_streamId.isNotEmpty) {
      ApiService.leaveLiveStream(_streamId); // fire-and-forget
    }
    if (mounted) Navigator.pop(context);
  }

  /// Share the live stream
  void _shareStream() {
    final host = widget.stream['host'] as Map<String, dynamic>? ?? {};
    final title = (widget.stream['title'] as String?) ?? 'Live';
    final name = host['name']?.toString() ?? '';
    Share.share('$name is live on Nearfo! "$title" — Join now and watch!');
  }

  void _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();

    final auth = context.read<AuthProvider>();
    final myName = auth.user?.name ?? 'You';

    setState(() {
      _chatMessages.add({'user': myName, 'text': text, 'isMe': true});
    });
    _scrollToBottom();

    await ApiService.sendLiveComment(_streamId, text);
  }

  void _doubleTapLike() {
    setState(() {
      _showHeart = true;
      _likeCount++;
    });
    _heartController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  Widget _viewerStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.6), size: 14),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.stream['host'] as Map<String, dynamic>? ?? {};
    final title = (widget.stream['title'] as String?) ?? 'Live';
    final avatar = host['avatarUrl']?.toString() ?? '';
    final name = host['name']?.toString() ?? '';
    final handle = host['handle']?.toString() ?? '';
    final isVerified = (host['isVerified'] as bool?) ?? false;
    final category = (widget.stream['description'] as String?) ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveStream();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onDoubleTap: _doubleTapLike,
          child: Stack(
            children: [
              // ── Premium animated background ──
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0a0a1a), Color(0xFF0f1535), Color(0xFF1a0a2e), Color(0xFF0a0a1a)],
                    stops: [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),

              // ── Host center display (premium) ──
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated ring around avatar
                        Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF0050), Color(0xFFFF4444), Color(0xFFFF8800), Color(0xFFFF0050)],
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 30, spreadRadius: 4),
                              BoxShadow(color: Colors.red.withOpacity(0.15), blurRadius: 60, spreadRadius: 10),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0a0a1a)),
                            padding: const EdgeInsets.all(3),
                            child: CircleAvatar(
                              radius: 63,
                              backgroundColor: const Color(0xFF1a1a2e),
                              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                              child: avatar.isEmpty
                                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white))
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Host name + verified badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                            if (isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.blue, size: 20),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('@$handle', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14)),
                        const SizedBox(height: 14),
                        // Stream title pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(category,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Stats row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _viewerStatChip(Icons.remove_red_eye_outlined, '$_viewerCount watching'),
                            const SizedBox(width: 10),
                            _viewerStatChip(Icons.favorite, '$_likeCount likes'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Top bar (premium glass) ──
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Host chip (compact)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.red, width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                                  child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 11)) : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blue, size: 12),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // LIVE badge (gradient + glow)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF3333)]),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                              SizedBox(width: 4),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Viewer count
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Close button
                        GestureDetector(
                          onTap: _leaveStream,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Chat overlay (bottom) ──
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                  ),
                ),
                child: Column(
                  children: [
                    // Chat messages
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
                        itemCount: _chatMessages.length,
                        itemBuilder: (_, i) {
                          final msg = _chatMessages[i];
                          final isSystem = msg['isSystem'] == true;
                          final isMe = msg['isMe'] == true;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSystem ? Colors.amber.withOpacity(0.08) : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${msg['user']}  ',
                                      style: TextStyle(
                                        color: isSystem ? Colors.amber : isMe ? Colors.cyanAccent : Colors.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text: msg['text'],
                                      style: TextStyle(
                                        color: isSystem ? Colors.amber.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Chat input + actions
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(
                          children: [
                            // Chat input
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: TextField(
                                  controller: _chatController,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Say something...',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  onSubmitted: (_) => _sendChat(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Send button
                            GestureDetector(
                              onTap: _sendChat,
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF4444)]),
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8)],
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Heart button
                            GestureDetector(
                              onTap: _doubleTapLike,
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 20),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Share button
                            GestureDetector(
                              onTap: _shareStream,
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Heart animation ──
            if (_showHeart)
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1.5).animate(
                    CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                      CurvedAnimation(parent: _heartController, curve: const Interval(0.5, 1.0)),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 80),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// LIVE BROADCASTER SCREEN — Host's view while streaming
// ════════════════════════════════════════════════════════════

class _LiveBroadcasterScreen extends StatefulWidget {
  final Map<String, dynamic> stream;
  const _LiveBroadcasterScreen({required this.stream});

  @override
  State<_LiveBroadcasterScreen> createState() => _LiveBroadcasterScreenState();
}

class _LiveBroadcasterScreenState extends State<_LiveBroadcasterScreen> {
  int _viewerCount = 0;
  int _likeCount = 0;
  int _durationSeconds = 0;
  Timer? _durationTimer;
  Timer? _refreshTimer;
  Timer? _chatPollTimer;
  final List<Map<String, dynamic>> _chatMessages = [];
  final _scrollController = ScrollController();
  bool _isEnding = false;

  String get _streamId => widget.stream['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _viewerCount = (widget.stream['currentViewers'] as int?) ?? 0;
    _chatMessages.add({'user': 'System', 'text': 'You are now live! Viewers can join anytime.', 'isSystem': true});
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
    // Refresh viewer/like count every 8s
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshStreamInfo());
    // Poll for new chat messages every 4s
    _chatPollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollChat());
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _refreshTimer?.cancel();
    _chatPollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Refresh viewer count and like count from server
  Future<void> _refreshStreamInfo() async {
    if (_isEnding || _streamId.isEmpty) return;
    final res = await ApiService.getLiveStreamInfo(_streamId);
    if (res.isSuccess && res.data != null && mounted) {
      final info = res.data!;
      setState(() {
        _viewerCount = (info['currentViewers'] as int?) ?? _viewerCount;
        _likeCount = (info['likes'] as int?) ?? (info['likeCount'] as int?) ?? _likeCount;
      });
    }
  }

  /// Poll for new chat messages from viewers
  Future<void> _pollChat() async {
    if (_isEnding || _streamId.isEmpty) return;
    final res = await ApiService.getLiveComments(_streamId);
    if (res.isSuccess && res.data != null && mounted) {
      final serverMessages = res.data!;
      final nonSystemCount = _chatMessages.where((m) => m['isSystem'] != true).length;
      if (serverMessages.length > nonSystemCount) {
        final newMsgs = serverMessages.skip(nonSystemCount);
        for (final msg in newMsgs) {
          final senderName = msg['userName']?.toString() ?? msg['user']?['name']?.toString() ?? 'Viewer';
          setState(() {
            _chatMessages.add({'user': senderName, 'text': msg['text']?.toString() ?? ''});
          });
        }
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String get _formattedDuration {
    final h = _durationSeconds ~/ 3600;
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _endStream() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('End Live Stream?', style: TextStyle(color: NearfoColors.text)),
        content: Text('Your live stream will end and viewers will be disconnected.',
          style: TextStyle(color: NearfoColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('End Stream', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _isEnding = true;
      _refreshTimer?.cancel();
      _chatPollTimer?.cancel();
      _durationTimer?.cancel();
      await ApiService.endLiveStream(_streamId);
      if (mounted) {
        // Show summary
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: NearfoColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Stream Ended', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text('Duration: $_formattedDuration', style: TextStyle(color: NearfoColors.textMuted, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Viewers: $_viewerCount', style: TextStyle(color: NearfoColors.textMuted, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Likes: $_likeCount', style: TextStyle(color: NearfoColors.textMuted, fontSize: 15)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NearfoColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endStream(); // Confirm before leaving
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Background ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF0d0d0d), const Color(0xFF1a1a2e), const Color(0xFF16213e)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_rounded, color: Colors.red, size: 64),
                    const SizedBox(height: 12),
                    const Text('You are Live!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Streaming to your audience', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                  ],
                ),
              ),
            ),

            // ── Top bar ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // LIVE badge with duration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                          const SizedBox(width: 6),
                          Text('LIVE  $_formattedDuration',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Viewer count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // End stream button
                    GestureDetector(
                      onTap: _endStream,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red),
                        ),
                        child: const Text('End', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Chat overlay ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
                      itemCount: _chatMessages.length,
                      itemBuilder: (_, i) {
                        final msg = _chatMessages[i];
                        final isSystem = msg['isSystem'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${msg['user']}  ',
                                  style: TextStyle(color: isSystem ? Colors.amber : Colors.cyanAccent, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                TextSpan(
                                  text: msg['text'],
                                  style: TextStyle(color: isSystem ? Colors.amber.withOpacity(0.8) : Colors.white.withOpacity(0.9), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Stats bar
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statBadge(Icons.remove_red_eye, '$_viewerCount', 'Viewers'),
                          _statBadge(Icons.favorite, '$_likeCount', 'Likes'),
                          _statBadge(Icons.chat_bubble_outline, '${_chatMessages.length}', 'Chats'),
                          _statBadge(Icons.timer_outlined, _formattedDuration, 'Duration'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _statBadge(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
      ],
    );
  }
}
