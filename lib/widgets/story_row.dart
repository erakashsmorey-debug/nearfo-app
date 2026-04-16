import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../utils/json_helpers.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../screens/stories_screen.dart';
import '../screens/create_story_screen.dart';
import '../l10n/l10n_helper.dart';

class StoryRow extends StatefulWidget {
  const StoryRow({super.key});

  @override
  State<StoryRow> createState() => StoryRowState();
}

class StoryRowState extends State<StoryRow> {
  List<Map<String, dynamic>> _storyFeed = [];
  bool _loading = true;
  bool _hasOwnStory = false;
  int _ownStoryIndex = -1;

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  /// Extract user ID from a story group's user object (handles various formats)
  String _extractUserId(Map<String, dynamic>? user) {
    if (user == null) return '';
    // Try _id first (standard MongoDB), then id
    final id = (user['_id'] as String?) ?? (user['id'] as String?);
    if (id == null || id.isEmpty) return '';
    return id;
  }

  Future<void> loadStories() async {
    try {
      final res = await ApiService.getStoryFeed();
      if (res.isSuccess && res.data != null && mounted) {
        final myId = context.read<AuthProvider>().user?.id ?? '';
        final feed = res.data!;

        debugPrint('[StoryRow] Feed loaded: ${feed.length} groups, myId=$myId');

        int ownIdx = -1;
        bool hasOwn = false;

        for (int i = 0; i < feed.length; i++) {
          final user = feed[i].asMapOrNull('user');
          final uid = _extractUserId(user);
          final userName = user?.asStringOrNull('name') ?? '';
          debugPrint('[StoryRow] Group $i: userId=$uid name=$userName');
          if (uid.isNotEmpty && uid == myId) {
            hasOwn = true;
            ownIdx = i;
          }
        }

        debugPrint('[StoryRow] hasOwnStory=$hasOwn ownIndex=$ownIdx');

        setState(() {
          _storyFeed = feed;
          _hasOwnStory = hasOwn;
          _ownStoryIndex = ownIdx;
          _loading = false;
        });
      } else {
        debugPrint('[StoryRow] Feed failed or empty: ${res.errorMessage}');
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('[StoryRow] Feed error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateStory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    );
    // Always reload stories when coming back, regardless of result
    if (mounted) loadStories();
  }

  void _openStoryViewer(int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StoriesScreen(
          storyGroups: _storyFeed,
          initialIndex: index,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ).then((_) {
      if (mounted) loadStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 110,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NearfoColors.primary,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _storyFeed.length + 1, // +1 for "Add Story"
        itemBuilder: (context, index) {
          if (index == 0) return _buildAddStoryItem();
          return _buildStoryItem(index - 1);
        },
      ),
    );
  }

  Widget _buildAddStoryItem() {
    final user = context.watch<AuthProvider>().user;
    return GestureDetector(
      // Instagram-like: tap opens viewer when story exists, otherwise opens create
      onTap: _hasOwnStory && _ownStoryIndex >= 0
          ? () => _openStoryViewer(_ownStoryIndex)
          : _openCreateStory,
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Outer ring container
                Container(
                  width: 68,
                  height: 68,
                  decoration: _hasOwnStory
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: NearfoColors.primaryGradient,
                        )
                      : BoxDecoration(
                          shape: BoxShape.circle,
                          color: NearfoColors.card,
                          border: Border.all(color: NearfoColors.border, width: 2),
                        ),
                  padding: EdgeInsets.all(_hasOwnStory ? 3 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NearfoColors.bg,
                      border: _hasOwnStory
                          ? Border.all(color: NearfoColors.bg, width: 2)
                          : null,
                    ),
                    child: ClipOval(
                      child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: NearfoConfig.resolveMediaUrl(user.avatarUrl!),
                              fit: BoxFit.cover,
                              width: 64,
                              height: 64,
                            )
                          : Container(
                              color: NearfoColors.card,
                              child: Center(
                                child: Text(
                                  user?.initials ?? '?',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _hasOwnStory ? NearfoColors.primary : NearfoColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                // + badge — always opens create story (separate GestureDetector)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _openCreateStory,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: NearfoColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: NearfoColors.bg, width: 2),
                        boxShadow: [BoxShadow(color: NearfoColors.primary.withOpacity(0.3), blurRadius: 6)],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _hasOwnStory ? context.l10n.storyRowYourStory : context.l10n.storyRowAddStory,
              style: TextStyle(
                fontSize: 11,
                color: _hasOwnStory ? NearfoColors.text : NearfoColors.textMuted,
                fontWeight: _hasOwnStory ? FontWeight.w600 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(int index) {
    final group = _storyFeed[index];
    final user = group.asMap('user');
    final hasUnviewed = group.asBool('hasUnviewed', false);
    final avatarUrl = user.asStringOrNull('avatarUrl');
    final name = user.asString('name', '');
    final firstName = name.split(' ').first;

    // Skip own story in the list (shown as "Your Story" at position 0)
    final myId = context.read<AuthProvider>().user?.id ?? '';
    final storyUserId = _extractUserId(user);
    if (storyUserId.isNotEmpty && storyUserId == myId) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _openStoryViewer(index),
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnviewed ? NearfoColors.primaryGradient : null,
                border: hasUnviewed
                    ? null
                    : Border.all(color: NearfoColors.textDim.withOpacity(0.4), width: 2),
                boxShadow: hasUnviewed ? [
                  BoxShadow(color: NearfoColors.primary.withOpacity(0.5), blurRadius: 12, spreadRadius: 2),
                  BoxShadow(color: NearfoColors.accent.withOpacity(0.3), blurRadius: 20, spreadRadius: 1),
                ] : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: NearfoColors.bg, width: 2),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: NearfoConfig.resolveMediaUrl(avatarUrl),
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          placeholder: (_, __) => Container(
                            color: NearfoColors.cardHover,
                            child: Icon(Icons.person, color: NearfoColors.textDim),
                          ),
                        )
                      : Container(
                          color: NearfoColors.cardHover,
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: NearfoColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              firstName,
              style: TextStyle(
                fontSize: 11,
                color: hasUnviewed ? NearfoColors.text : NearfoColors.textMuted,
                fontWeight: hasUnviewed ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
