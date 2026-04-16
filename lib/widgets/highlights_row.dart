import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../utils/json_helpers.dart';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

/// Horizontal scrolling story highlights row for profile screens (like Instagram)
class HighlightsRow extends StatefulWidget {
  final String userId;
  final bool isOwner;

  const HighlightsRow({super.key, required this.userId, this.isOwner = false});

  @override
  State<HighlightsRow> createState() => _HighlightsRowState();
}

class _HighlightsRowState extends State<HighlightsRow> {
  List<Map<String, dynamic>> _highlights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getHighlights(widget.userId);
    if (res.isSuccess && res.data != null && mounted) {
      setState(() { _highlights = res.data!; _loading = false; });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createHighlight() async {
    final controller = TextEditingController();
    try {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.highlightsNewHighlight, style: TextStyle(color: NearfoColors.text)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: NearfoColors.text),
          maxLength: 30,
          decoration: InputDecoration(
            hintText: context.l10n.highlightsNameHint,
            hintStyle: TextStyle(color: NearfoColors.textDim),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.create, style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ApiService.createHighlight(title: result);
      _load();
    }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 0);
    if (_highlights.isEmpty && !widget.isOwner) return const SizedBox(height: 0);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _highlights.length + (widget.isOwner ? 1 : 0),
        itemBuilder: (context, index) {
          // "New" button for owner
          if (widget.isOwner && index == 0) {
            return _buildNewHighlightButton();
          }
          final hlIndex = widget.isOwner ? index - 1 : index;
          return _buildHighlightItem(_highlights[hlIndex]);
        },
      ),
    );
  }

  Widget _buildNewHighlightButton() {
    return GestureDetector(
      onTap: _createHighlight,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NearfoColors.border, width: 1.5),
              ),
              child: Icon(Icons.add, color: NearfoColors.textMuted, size: 28),
            ),
            const SizedBox(height: 6),
            Text(context.l10n.highlightsNew, style: TextStyle(fontSize: 11, color: NearfoColors.textMuted), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightItem(Map<String, dynamic> highlight) {
    final title = highlight.asString('title', '');
    final coverUrl = highlight.asString('coverUrl', '');
    final stories = highlight.asList('stories');
    // Use first story's image as cover if no cover set
    String displayCover = coverUrl;
    if (displayCover.isEmpty && stories.isNotEmpty) {
      final firstStory = stories[0];
      if (firstStory is Map) {
        final firstStoryMap = (firstStory as Map<String, dynamic>);
        final images = firstStoryMap.asList('images');
        if (images.isNotEmpty) displayCover = images[0].toString();
      }
    }

    return GestureDetector(
      onTap: () {
        // Could open highlight viewer — for now show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title: ${stories.length} stories'), backgroundColor: NearfoColors.primary),
        );
      },
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NearfoColors.textDim.withOpacity(0.3), width: 1.5),
              ),
              child: ClipOval(
                child: displayCover.isNotEmpty
                    ? CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(displayCover), fit: BoxFit.cover, width: 64, height: 64)
                    : Container(
                        color: NearfoColors.cardHover,
                        child: Center(child: Icon(Icons.auto_stories, color: NearfoColors.textDim, size: 24)),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: NearfoColors.text, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
