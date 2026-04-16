import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
// google_fonts removed — causes AOT compilation crash with FontWeight const map keys
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../utils/image_compressor.dart';
import '../utils/constants.dart';
import '../l10n/l10n_helper.dart';

// ──────────────────────────────────────────────────────────
// STORY EDITOR SCREEN — Instagram-style story editor
// Features: Text overlay, Drawing, Stickers, Filters, Caption
// ──────────────────────────────────────────────────────────

class StoryEditorScreen extends StatefulWidget {
  final File mediaFile;
  final String mediaType; // 'image' or 'video'
  final String uploadType; // 'story' or 'reel' (default: 'story')
  final String visibility; // For reels: 'public', 'nearby', or 'circle' (default: 'public')

  const StoryEditorScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    this.uploadType = 'story',
    this.visibility = 'public',
  });

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

enum EditorMode { normal, text, draw, sticker, filter }

class _StoryEditorScreenState extends State<StoryEditorScreen>
    with TickerProviderStateMixin {
  // ─── Core state ───
  EditorMode _mode = EditorMode.normal;
  final GlobalKey _repaintKey = GlobalKey();
  bool _uploading = false;
  double _progress = 0;
  final _captionController = TextEditingController();
  late String _reelVisibility; // For reel uploads: 'public', 'nearby', 'circle'

  // ─── Text overlays ───
  final List<_TextOverlay> _textOverlays = [];
  int? _activeTextIndex;
  String _currentText = '';
  Color _currentTextColor = Colors.white;
  double _currentTextSize = 28;
  String _currentFontFamily = 'Default';
  bool _textHasBg = false;
  TextAlign _currentTextAlign = TextAlign.center;
  final _textEditController = TextEditingController();

  // ─── Drawing ───
  final List<_DrawStroke> _drawStrokes = [];
  List<Offset> _currentDrawPoints = [];
  Color _drawColor = Colors.white;
  double _drawBrushSize = 4.0;
  bool _isEraser = false;

  // ─── Stickers ───
  final List<_StickerOverlay> _stickerOverlays = [];

  // ─── Interactive sticker overlays ───
  final List<Map<String, dynamic>> _interactiveStickers = [];

  // ─── Music ───
  String? _selectedMusicName;
  String? _selectedMusicUrl;
  final AudioPlayer _musicPreviewPlayer = AudioPlayer();
  String? _previewingTrack; // track name currently being previewed

  // ─── Filters ───
  int _selectedFilterIndex = 0;
  static const List<_StoryFilter> _filters = [
    _StoryFilter('Normal', null),
    _StoryFilter('Clarendon', [
      1.2, 0, 0, 0, 10,
      0, 1.2, 0, 0, 10,
      0, 0, 1.2, 0, 10,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Gingham', [
      1, 0, 0, 0, 20,
      0, 1.05, 0, 0, 10,
      0, 0, 0.9, 0, 30,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Moon', [
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Lark', [
      1.2, 0.1, 0, 0, 0,
      0, 1.1, 0, 0, 10,
      0, 0, 0.95, 0, 20,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Reyes', [
      1.1, 0, 0, 0, 30,
      0, 1.05, 0, 0, 20,
      0, 0, 0.9, 0, 40,
      0, 0, 0, 0.9, 0,
    ]),
    _StoryFilter('Juno', [
      1.3, 0, 0, 0, -20,
      0, 1.1, 0, 0, 10,
      0, 0, 0.8, 0, 30,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Slumber', [
      0.9, 0.1, 0, 0, 20,
      0, 0.9, 0.1, 0, 15,
      0.1, 0, 0.85, 0, 30,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Crema', [
      1.1, 0.05, 0.05, 0, 15,
      0.05, 1.05, 0.05, 0, 15,
      0, 0.05, 0.95, 0, 25,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Ludwig', [
      1.15, 0.05, 0, 0, -5,
      0, 1.1, 0, 0, 5,
      0, 0, 1.2, 0, -10,
      0, 0, 0, 1, 0,
    ]),
    _StoryFilter('Aden', [
      0.95, 0.05, 0.05, 0, 20,
      0.05, 0.95, 0.05, 0, 20,
      0, 0, 0.85, 0, 40,
      0, 0, 0, 0.85, 0,
    ]),
    _StoryFilter('Perpetua', [
      1, 0.1, 0, 0, 10,
      0, 1.1, 0.1, 0, 0,
      0.1, 0, 1, 0, 10,
      0, 0, 0, 1, 0,
    ]),
  ];

  // ─── Video ───
  VideoPlayerController? _videoController;

  // ─── Color palette for tools ───
  static const List<Color> _palette = [
    Colors.white,
    Colors.black,
    Color(0xFFFF0000),
    Color(0xFFFF5722),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF00BCD4),
    Color(0xFF2196F3),
    Color(0xFF3F51B5),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFFFC0CB),
    Color(0xFF00FFFF),
  ];

  // ─── Font families ───
  static const List<String> _fontFamilies = [
    'Default',
    'Lobster',
    'Pacifico',
    'Dancing Script',
    'Oswald',
    'Playfair Display',
    'Caveat',
    'Shadows Into Light',
    'Permanent Marker',
    'Righteous',
  ];

  // ─── Animations ───
  late AnimationController _toolbarAnim;

  @override
  void initState() {
    super.initState();
    _reelVisibility = widget.visibility;
    _toolbarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    if (widget.mediaType == 'video') {
      _videoController = VideoPlayerController.file(widget.mediaFile)
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _textEditController.dispose();
    _toolbarAnim.dispose();
    _videoController?.dispose();
    _musicPreviewPlayer.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────
  // CAPTURE & UPLOAD
  // ──────────────────────────────────────────────────────────

  Future<File> _captureEditorToFile() async {
    final ctx = _repaintKey.currentContext;
    if (ctx == null) {
      throw Exception('Capture context is null — widget may have been disposed');
    }
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    // Use device pixel ratio capped at 2.0 to avoid OOM on high-DPI screens
    final dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.0);
    final image = await boundary.toImage(pixelRatio: dpr);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to capture editor image');
    }
    final pngBytes = byteData.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/story_edited_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes);
    debugPrint('[StoryEditor] Captured editor: ${(pngBytes.length / 1024).toStringAsFixed(0)}KB, pixelRatio=$dpr');
    return file;
  }

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0.05;
      _mode = EditorMode.normal;
    });

    try {
      String? mediaUrl;
      String folder = widget.uploadType == 'reel' ? 'reels' : 'stories';

      if (widget.mediaType == 'video') {
        // For video, upload the original (can't overlay edits on video yet)
        if (mounted) setState(() => _progress = 0.2);
        debugPrint('[StoryEditor] Uploading video: ${widget.mediaFile.path}');
        final videoRes = await ApiService.uploadVideo(widget.mediaFile.path, folder: folder);
        if (!mounted) return;
        if (!videoRes.isSuccess) {
          debugPrint('[StoryEditor] Video upload failed: ${videoRes.errorMessage}');
          _showError(videoRes.errorMessage ?? 'Video upload failed');
          return;
        }
        mediaUrl = videoRes.data;
        debugPrint('[StoryEditor] Video uploaded: $mediaUrl');
      } else {
        // Capture the edited canvas as image
        if (mounted) setState(() => _progress = 0.1);
        debugPrint('[StoryEditor] Capturing editor canvas...');
        final editedFile = await _captureEditorToFile();
        if (!mounted) return;

        if (mounted) setState(() => _progress = 0.25);
        // Compress the captured image
        String uploadPath = editedFile.path;
        try {
          uploadPath = await ImageCompressor.compress(editedFile.path, type: ImageType.story);
          debugPrint('[StoryEditor] Compressed: $uploadPath');
        } catch (e) {
          debugPrint('[StoryEditor] Compression failed, using original: $e');
        }

        if (mounted) setState(() => _progress = 0.4);
        debugPrint('[StoryEditor] Uploading image to folder=$folder...');
        final imgRes = await ApiService.uploadImage(uploadPath, folder: folder);
        if (!mounted) return;
        if (!imgRes.isSuccess) {
          debugPrint('[StoryEditor] Image upload failed: ${imgRes.errorMessage}');
          _showError(imgRes.errorMessage ?? 'Image upload failed');
          return;
        }
        mediaUrl = imgRes.data;
        debugPrint('[StoryEditor] Image uploaded: $mediaUrl');
      }

      if (mediaUrl == null || mediaUrl.isEmpty) {
        debugPrint('[StoryEditor] Upload returned empty/null URL');
        _showError('Upload returned empty URL');
        return;
      }

      if (mounted) setState(() => _progress = 0.7);

      // Get actual video duration if available
      int mediaDuration = 5;
      if (widget.mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized) {
        mediaDuration = _videoController!.value.duration.inSeconds;
        if (mediaDuration <= 0) mediaDuration = 5;
      }

      // Handle reel vs story uploads differently
      if (widget.uploadType == 'reel') {
        debugPrint('[StoryEditor] Creating reel: mediaUrl=$mediaUrl, visibility=$_reelVisibility');
        final res = await ApiService.createReel(
          videoUrl: mediaUrl,
          caption: _captionController.text.trim(),
          duration: mediaDuration,
          visibility: _reelVisibility,
        );

        if (!mounted) return;
        setState(() => _progress = 1.0);

        if (!mounted) return;
        setState(() => _uploading = false);
        if (res.isSuccess) {
          Navigator.pop(context, true);
        } else {
          debugPrint('[StoryEditor] Reel creation failed: ${res.errorMessage}');
          _showError(res.errorMessage ?? 'Reel creation failed');
        }
      } else {
        debugPrint('[StoryEditor] Creating story: mediaUrl=$mediaUrl, type=${widget.mediaType}, visibility=$_reelVisibility, music=$_selectedMusicName');
        final res = await ApiService.createStory(
          mediaUrl: mediaUrl,
          mediaType: widget.mediaType,
          caption: _captionController.text.trim(),
          duration: mediaDuration,
          visibility: _reelVisibility,
          musicName: _selectedMusicName,
          musicUrl: _selectedMusicUrl,
        );

        if (!mounted) return;
        setState(() => _progress = 1.0);

        if (!mounted) return;
        setState(() => _uploading = false);
        if (res.isSuccess) {
          Navigator.pop(context, true);
        } else {
          debugPrint('[StoryEditor] Story creation failed: ${res.errorMessage}');
          _showError(res.errorMessage ?? 'Story creation failed');
        }
      }
    } catch (e) {
      debugPrint('[StoryEditor] Upload error: $e');
      if (mounted) {
        _showError('Error: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}');
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  // ──────────────────────────────────────────────────────────
  // MUSIC PICKER
  // ──────────────────────────────────────────────────────────

  /// All available music tracks with real publicly accessible audio URLs
  /// SoundHelix: free algorithmic music (soundhelix.com/audio-examples)
  /// GitHub samples: public domain test audio files
  static final List<Map<String, String>> _allMusicTracks = [
    // ─── Trending ───
    {'name': 'Chill Vibes', 'artist': 'SoundHelix', 'duration': '5:27', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
    {'name': 'Summer Beat', 'artist': 'SoundHelix', 'duration': '5:09', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'},
    {'name': 'Night Drive', 'artist': 'SoundHelix', 'duration': '4:34', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'},
    {'name': 'Lo-fi Dreams', 'artist': 'SoundHelix', 'duration': '4:58', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3'},
    {'name': 'Midnight Groove', 'artist': 'SoundHelix', 'duration': '4:15', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3'},
    {'name': 'Urban Flow', 'artist': 'SoundHelix', 'duration': '5:42', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3'},
    {'name': 'Golden Hour', 'artist': 'SoundHelix', 'duration': '4:47', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3'},
    {'name': 'Neon Lights', 'artist': 'SoundHelix', 'duration': '5:18', 'category': 'Trending',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3'},
    // ─── Happy ───
    {'name': 'Feel Good', 'artist': 'SoundHelix', 'duration': '4:22', 'category': 'Happy',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3'},
    {'name': 'Sunny Day', 'artist': 'SoundHelix', 'duration': '5:33', 'category': 'Happy',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3'},
    {'name': 'Good Morning', 'artist': 'SoundHelix', 'duration': '4:45', 'category': 'Happy',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3'},
    {'name': 'Happy Claps', 'artist': 'SoundHelix', 'duration': '4:50', 'category': 'Happy',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3'},
    {'name': 'Joy Ride', 'artist': 'SoundHelix', 'duration': '5:06', 'category': 'Happy',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3'},
    {'name': 'Celebration', 'artist': 'SoundHelix', 'duration': '4:38', 'category': 'Happy',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3'},
    // ─── Sad ───
    {'name': 'Rainy Mood', 'artist': 'SoundHelix', 'duration': '5:14', 'category': 'Sad',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3'},
    {'name': 'Missing You', 'artist': 'SoundHelix', 'duration': '5:01', 'category': 'Sad',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3'},
    {'name': 'Alone Tonight', 'artist': 'SoundHelix', 'duration': '5:27', 'category': 'Sad',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
    {'name': 'Broken Strings', 'artist': 'SoundHelix', 'duration': '5:09', 'category': 'Sad',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'},
    // ─── Energetic ───
    {'name': 'Pump It Up', 'artist': 'SoundHelix', 'duration': '4:34', 'category': 'Energetic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'},
    {'name': 'Run Fast', 'artist': 'SoundHelix', 'duration': '4:58', 'category': 'Energetic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3'},
    {'name': 'Bass Drop', 'artist': 'SoundHelix', 'duration': '4:15', 'category': 'Energetic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3'},
    {'name': 'Fire Up', 'artist': 'SoundHelix', 'duration': '5:42', 'category': 'Energetic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3'},
    {'name': 'Beast Mode', 'artist': 'SoundHelix', 'duration': '4:47', 'category': 'Energetic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3'},
    {'name': 'Thunder', 'artist': 'SoundHelix', 'duration': '5:18', 'category': 'Energetic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3'},
    // ─── Romantic ───
    {'name': 'Love Story', 'artist': 'SoundHelix', 'duration': '4:22', 'category': 'Romantic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3'},
    {'name': 'Dreamy Kiss', 'artist': 'SoundHelix', 'duration': '5:33', 'category': 'Romantic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3'},
    {'name': 'Moonlight', 'artist': 'SoundHelix', 'duration': '4:45', 'category': 'Romantic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3'},
    {'name': 'Forever Yours', 'artist': 'SoundHelix', 'duration': '4:50', 'category': 'Romantic',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3'},
    // ─── Desi Vibes ───
    {'name': 'Bollywood Beats', 'artist': 'SoundHelix', 'duration': '5:06', 'category': 'Desi Vibes',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3'},
    {'name': 'Dhol Remix', 'artist': 'SoundHelix', 'duration': '4:38', 'category': 'Desi Vibes',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3'},
    {'name': 'Sufi Soul', 'artist': 'SoundHelix', 'duration': '5:14', 'category': 'Desi Vibes',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3'},
    {'name': 'Jugni Beat', 'artist': 'SoundHelix', 'duration': '5:01', 'category': 'Desi Vibes',
     'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3'},
  ];

  /// Group tracks by category
  static Map<String, List<Map<String, String>>> get _musicCategories {
    final Map<String, List<Map<String, String>>> categories = {};
    for (final track in _allMusicTracks) {
      final cat = track['category'] ?? 'Other';
      categories.putIfAbsent(cat, () => []);
      categories[cat]!.add(track);
    }
    return categories;
  }

  /// Preview a track (play/pause toggle)
  /// [sheetRefresh] is the StatefulBuilder's setState to update the bottom sheet UI
  Future<void> _previewTrack(Map<String, String> track, {void Function(VoidCallback)? sheetRefresh}) async {
    final name = track['name']!;
    final url = track['url']!;

    void refresh(VoidCallback fn) {
      setState(fn);
      sheetRefresh?.call(() {});
    }

    if (_previewingTrack == name) {
      // Stop preview
      await _musicPreviewPlayer.stop();
      refresh(() => _previewingTrack = null);
    } else {
      // Play new preview
      refresh(() => _previewingTrack = name);
      try {
        await _musicPreviewPlayer.stop();
        await _musicPreviewPlayer.setVolume(1.0);
        await _musicPreviewPlayer.play(UrlSource(url));
        debugPrint('[Music] Playing preview: $name from $url');
      } catch (e) {
        debugPrint('[Music] Preview error: $e');
        if (mounted) {
          refresh(() => _previewingTrack = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play "$name"'), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 2)),
          );
        }
      }
    }
  }

  void _showMusicPicker() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Filter tracks based on search query
          final filteredCategories = <String, List<Map<String, String>>>{};
          for (final entry in _musicCategories.entries) {
            final filtered = entry.value.where((t) =>
              searchQuery.isEmpty ||
              (t['name'] ?? '').toLowerCase().contains(searchQuery.toLowerCase()) ||
              (t['category'] ?? '').toLowerCase().contains(searchQuery.toLowerCase())
            ).toList();
            if (filtered.isNotEmpty) filteredCategories[entry.key] = filtered;
          }

          return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
              // Title row with remove button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.storyEditorAddMusic, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_selectedMusicName != null)
                      GestureDetector(
                        onTap: () {
                          _musicPreviewPlayer.stop();
                          setState(() {
                            _selectedMusicName = null;
                            _selectedMusicUrl = null;
                            _previewingTrack = null;
                          });
                          setSheetState(() {});
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.storyEditorMusicRemoved), backgroundColor: Colors.grey, duration: const Duration(seconds: 1)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(8)),
                          child: Text(context.l10n.storyEditorRemove, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
              // Search bar (functional — filters tracks in real-time)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search music...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) => setSheetState(() => searchQuery = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Music list
              Expanded(
                child: filteredCategories.isEmpty
                  ? Center(child: Text(context.l10n.storyEditorNoMusic, style: const TextStyle(color: Colors.white54, fontSize: 14)))
                  : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: filteredCategories.entries.map((category) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(category.key, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        ...category.value.map((track) {
                          final isSelected = _selectedMusicName == track['name'];
                          final isPreviewing = _previewingTrack == track['name'];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: GestureDetector(
                              onTap: () {
                                _previewTrack(track, sheetRefresh: setSheetState);
                              },
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: isPreviewing ? [Colors.purpleAccent, Colors.pink] : [Colors.purple, Colors.deepPurple]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(isPreviewing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 22),
                              ),
                            ),
                            title: Text(track['name']!, style: TextStyle(color: isSelected ? Colors.purpleAccent : Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('${track['artist']} \u2022 ${track['duration']}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            trailing: GestureDetector(
                              onTap: () {
                                _musicPreviewPlayer.stop();
                                setState(() {
                                  _selectedMusicName = track['name'];
                                  _selectedMusicUrl = track['url'];
                                  _previewingTrack = null;
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('\u{1F3B5} ${track['name']} added to story'),
                                    backgroundColor: Colors.deepPurple,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.purpleAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSelected ? Colors.purpleAccent : Colors.grey[700]!),
                                ),
                                child: Text(isSelected ? context.l10n.storyEditorAdded : context.l10n.storyEditorUse, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );},
      ),
    ).whenComplete(() {
      // Stop preview when sheet closes
      _musicPreviewPlayer.stop();
      setState(() => _previewingTrack = null);
    });
  }

  // ──────────────────────────────────────────────────────────
  // SAVE TO GALLERY
  // ──────────────────────────────────────────────────────────

  Future<void> _saveToGallery() async {
    try {
      final file = await _captureEditorToFile();
      // Copy to external directory so it shows in gallery
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final galleryDir = Directory('${extDir.parent.parent.parent.parent.path}/DCIM/Nearfo');
        if (!galleryDir.existsSync()) galleryDir.createSync(recursive: true);
        final savedFile = await file.copy(
            '${galleryDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(context.l10n.storyEditorSavedGallery),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[StoryEditor] Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.storyEditorCouldNotSave), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main editor canvas ──
            _buildEditorCanvas(),

            // ── Upload progress ──
            if (_uploading) _buildUploadOverlay(),

            // ── Top bar (back + done) ──
            if (!_uploading) _buildTopBar(),

            // ── Right-side toolbar (Instagram-style) ──
            if (_mode == EditorMode.normal && !_uploading) _buildRightToolbar(),

            // ── Bottom bar (caption + share) ──
            if (_mode == EditorMode.normal && !_uploading) _buildBottomBar(),

            // ── Text editor overlay ──
            if (_mode == EditorMode.text) _buildTextEditor(),

            // ── Draw toolbar ──
            if (_mode == EditorMode.draw && !_uploading) _buildDrawToolbar(),

            // ── Sticker picker ──
            if (_mode == EditorMode.sticker) _buildStickerPicker(),

            // ── Filter selector ──
            if (_mode == EditorMode.filter) _buildFilterSelector(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // EDITOR CANVAS
  // ──────────────────────────────────────────────────────────

  Widget _buildEditorCanvas() {
    return RepaintBoundary(
      key: _repaintKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Base media with filter ──
              _buildFilteredMedia(),

              // ── Drawing layer ──
              if (_drawStrokes.isNotEmpty || _mode == EditorMode.draw)
                _buildDrawingLayer(),

              // ── Text overlays ──
              ..._textOverlays.asMap().entries.map((e) => _buildDraggableText(e.key, e.value)),

              // ── Sticker overlays ──
              ..._stickerOverlays.asMap().entries.map((e) => _buildDraggableSticker(e.key, e.value)),

              // Interactive sticker overlays
              ..._interactiveStickers.asMap().entries.map((entry) {
                final i = entry.key;
                final sticker = entry.value;
                final pos = sticker['position'] as Offset;
                return Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _interactiveStickers[i]['position'] = Offset(
                          pos.dx + details.delta.dx,
                          pos.dy + details.delta.dy,
                        );
                      });
                    },
                    child: _buildInteractiveStickerWidget(sticker),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredMedia() {
    final filter = _filters[_selectedFilterIndex];
    Widget media;

    if (widget.mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized) {
      media = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );
    } else {
      media = Image.file(
        widget.mediaFile,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (filter.matrix != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(filter.matrix!.map((e) => e.toDouble()).toList()),
        child: media,
      );
    }
    return media;
  }

  // ──────────────────────────────────────────────────────────
  // DRAWING LAYER
  // ──────────────────────────────────────────────────────────

  Widget _buildDrawingLayer() {
    return GestureDetector(
      onPanStart: _mode == EditorMode.draw
          ? (d) {
              setState(() {
                _currentDrawPoints = [d.localPosition];
              });
            }
          : null,
      onPanUpdate: _mode == EditorMode.draw
          ? (d) {
              setState(() {
                _currentDrawPoints = List<Offset>.from(_currentDrawPoints)..add(d.localPosition);
              });
            }
          : null,
      onPanEnd: _mode == EditorMode.draw
          ? (_) {
              setState(() {
                _drawStrokes.add(_DrawStroke(
                  points: List<Offset>.from(_currentDrawPoints),
                  color: _isEraser ? Colors.transparent : _drawColor,
                  width: _drawBrushSize,
                  isEraser: _isEraser,
                ));
                _currentDrawPoints = [];
              });
            }
          : null,
      child: CustomPaint(
        painter: _DrawingPainter(
          strokes: _drawStrokes,
          currentPoints: _currentDrawPoints,
          currentColor: _isEraser ? Colors.transparent : _drawColor,
          currentWidth: _drawBrushSize,
          isEraser: _isEraser,
        ),
        size: Size.infinite,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TEXT OVERLAYS
  // ──────────────────────────────────────────────────────────

  Widget _buildDraggableText(int index, _TextOverlay overlay) {
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          setState(() {
            overlay.position = Offset(
              overlay.position.dx + d.delta.dx,
              overlay.position.dy + d.delta.dy,
            );
          });
        },
        onTap: () {
          // Edit existing text
          setState(() {
            _activeTextIndex = index;
            _currentText = overlay.text;
            _currentTextColor = overlay.color;
            _currentTextSize = overlay.fontSize;
            _currentFontFamily = overlay.fontFamily;
            _textHasBg = overlay.hasBackground;
            _currentTextAlign = overlay.textAlign;
            _textEditController.text = overlay.text;
            _mode = EditorMode.text;
          });
        },
        onLongPress: () {
          // Delete text
          _showDeleteDialog(() {
            setState(() => _textOverlays.removeAt(index));
          });
        },
        child: Transform.rotate(
          angle: overlay.rotation,
          child: Transform.scale(
            scale: overlay.scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: overlay.hasBackground
                  ? BoxDecoration(
                      color: overlay.bgColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Text(
                overlay.text,
                textAlign: overlay.textAlign,
                style: _getTextStyle(
                  overlay.fontFamily,
                  overlay.fontSize,
                  overlay.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _getTextStyle(String fontFamily, double fontSize, Color color) {
    final shadow = [
      Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.8), offset: const Offset(1, 1)),
    ];

    if (fontFamily == 'Default') {
      return TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.bold,
        shadows: shadow,
      );
    }

    // Use fontFamily strings — fonts render if available on device, else fall back to system default
    final fw = fontFamily == 'Oswald' ? FontWeight.bold : null;
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fw ?? FontWeight.bold,
      shadows: shadow,
    );
  }

  // ──────────────────────────────────────────────────────────
  // STICKER OVERLAYS
  // ──────────────────────────────────────────────────────────

  Widget _buildDraggableSticker(int index, _StickerOverlay sticker) {
    return Positioned(
      left: sticker.position.dx,
      top: sticker.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          setState(() {
            sticker.position = Offset(
              sticker.position.dx + d.delta.dx,
              sticker.position.dy + d.delta.dy,
            );
          });
        },
        onScaleUpdate: (d) {
          setState(() {
            sticker.scale = (sticker.scale * d.scale).clamp(0.3, 4.0);
          });
        },
        onLongPress: () {
          _showDeleteDialog(() {
            setState(() => _stickerOverlays.removeAt(index));
          });
        },
        child: Transform.scale(
          scale: sticker.scale,
          child: Text(sticker.emoji, style: const TextStyle(fontSize: 48)),
        ),
      ),
    );
  }

  Widget _buildInteractiveStickerWidget(Map<String, dynamic> sticker) {
    final type = sticker['type'] as String;
    switch (type) {
      case 'poll':
        return Container(
          width: 220, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text((sticker['question'] as String?) ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 10),
              ...(sticker['options'] as List<dynamic>?)?.map((opt) => Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(opt as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
              )) ?? [],
            ],
          ),
        );
      case 'question':
        return Container(
          width: 220, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.purple]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text((sticker['question'] as String?) ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Text('Tap to answer...', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
        );
      case 'countdown':
        final endDate = DateTime.tryParse((sticker['endDate'] as String?) ?? '') ?? DateTime.now();
        final diff = endDate.difference(DateTime.now());
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text((sticker['name'] as String?) ?? 'Countdown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _countdownUnit('${days}', 'DAYS'),
                  const SizedBox(width: 8),
                  _countdownUnit('${hours}', 'HRS'),
                ],
              ),
            ],
          ),
        );
      case 'link':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, color: Colors.blue, size: 18),
              const SizedBox(width: 6),
              Text((sticker['label'] as String?) ?? 'Link', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _countdownUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white70)),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // TOP BAR
  // ──────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          _circleButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
          if (_mode == EditorMode.draw)
            Row(
              children: [
                _circleButton(
                  icon: Icons.undo,
                  onTap: _drawStrokes.isNotEmpty
                      ? () => setState(() => _drawStrokes.removeLast())
                      : null,
                ),
                const SizedBox(width: 8),
                _circleButton(
                  icon: Icons.check,
                  onTap: () => setState(() => _mode = EditorMode.normal),
                  color: Colors.deepPurpleAccent,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // RIGHT TOOLBAR (Instagram-style)
  // ──────────────────────────────────────────────────────────

  Widget _buildRightToolbar() {
    return Positioned(
      right: 12,
      top: 70,
      child: FadeTransition(
        opacity: _toolbarAnim,
        child: Column(
          children: [
            _toolbarButton(
              icon: Icons.text_fields,
              label: context.l10n.storyEditorText,
              onTap: () {
                setState(() {
                  _activeTextIndex = null;
                  _currentText = '';
                  _currentTextColor = Colors.white;
                  _currentTextSize = 28;
                  _currentFontFamily = 'Default';
                  _textHasBg = false;
                  _textEditController.clear();
                  _mode = EditorMode.text;
                });
              },
            ),
            const SizedBox(height: 12),
            _toolbarButton(
              icon: Icons.emoji_emotions_outlined,
              label: context.l10n.storyEditorStickers,
              onTap: () => setState(() => _mode = EditorMode.sticker),
            ),
            const SizedBox(height: 12),
            _toolbarButton(
              icon: Icons.music_note,
              label: context.l10n.storyEditorMusic,
              onTap: () => _showMusicPicker(),
            ),
            const SizedBox(height: 12),
            _toolbarButton(
              icon: Icons.auto_awesome,
              label: context.l10n.storyEditorEffects,
              onTap: () => setState(() => _mode = EditorMode.filter),
            ),
            const SizedBox(height: 12),
            _toolbarButton(
              icon: Icons.alternate_email,
              label: context.l10n.storyEditorMention,
              onTap: () => _showMentionPicker(),
            ),
            const SizedBox(height: 12),
            _toolbarButton(
              icon: Icons.draw_outlined,
              label: context.l10n.storyEditorDraw,
              onTap: () => setState(() => _mode = EditorMode.draw),
            ),
            const SizedBox(height: 12),
            _toolbarButton(
              icon: Icons.download_rounded,
              label: context.l10n.storyEditorSave,
              onTap: _saveToGallery,
            ),
            const SizedBox(height: 12),
            _toolbarButton(
              icon: Icons.more_horiz,
              label: context.l10n.storyEditorMore,
              onTap: _showMoreOptions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // BOTTOM BAR (Caption + Share)
  // ──────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    // Push bottom bar above keyboard when it opens
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardHeight,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Caption input
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Conditional UI based on uploadType
            if (widget.uploadType == 'reel') ...[
              // REEL UI: Visibility selector + Post Reel button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  value: _reelVisibility,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _reelVisibility = value);
                    }
                  },
                  dropdownColor: Colors.grey[850],
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'public',
                      child: Row(
                        children: [
                          const Icon(Icons.public, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(context.l10n.storyEditorEveryone, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'nearby',
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(context.l10n.storyEditorNearby, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'circle',
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(context.l10n.storyEditorCircle, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Post Reel button
              GestureDetector(
                onTap: _upload,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.storyEditorPostReel,
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // STORY UI: "Your Story" + "Close Friends" + Share arrow
              Row(
                children: [
                  // Your Story button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _reelVisibility = 'public');
                        _upload();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.purple, Colors.orange, Colors.pink],
                                ),
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              context.l10n.storyEditorYourStory,
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Close Friends button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _reelVisibility = 'close_friends');
                        _upload();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                              child: const Icon(Icons.star, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              context.l10n.storyEditorCloseFriends,
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Send/Share arrow
                  GestureDetector(
                    onTap: _upload,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurpleAccent,
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TEXT EDITOR OVERLAY
  // ──────────────────────────────────────────────────────────

  Widget _buildTextEditor() {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Column(
        children: [
          // Top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Cancel
                  GestureDetector(
                    onTap: () => setState(() => _mode = EditorMode.normal),
                    child: Text(context.l10n.storyEditorCancel, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const Spacer(),
                  // Text align toggle
                  _circleButton(
                    icon: _currentTextAlign == TextAlign.left
                        ? Icons.format_align_left
                        : _currentTextAlign == TextAlign.center
                            ? Icons.format_align_center
                            : Icons.format_align_right,
                    size: 36,
                    onTap: () {
                      setState(() {
                        if (_currentTextAlign == TextAlign.center) {
                          _currentTextAlign = TextAlign.left;
                        } else if (_currentTextAlign == TextAlign.left) {
                          _currentTextAlign = TextAlign.right;
                        } else {
                          _currentTextAlign = TextAlign.center;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  // Background toggle
                  _circleButton(
                    icon: Icons.format_color_fill,
                    size: 36,
                    color: _textHasBg ? Colors.white : Colors.transparent,
                    iconColor: _textHasBg ? Colors.black : Colors.white,
                    onTap: () => setState(() => _textHasBg = !_textHasBg),
                  ),
                  const Spacer(),
                  // Done
                  GestureDetector(
                    onTap: _addOrUpdateText,
                    child: Text(context.l10n.storyEditorDone, style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

          // Text input
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TextField(
                  controller: _textEditController,
                  autofocus: true,
                  textAlign: _currentTextAlign,
                  style: _getTextStyle(_currentFontFamily, _currentTextSize, _currentTextColor),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Type something...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 28),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) => _currentText = val,
                ),
              ),
            ),
          ),

          // Font family selector
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _fontFamilies.length,
              itemBuilder: (_, i) {
                final isSelected = _fontFamilies[i] == _currentFontFamily;
                return GestureDetector(
                  onTap: () => setState(() => _currentFontFamily = _fontFamilies[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _fontFamilies[i],
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Font size slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.text_fields, color: Colors.white54, size: 16),
                Expanded(
                  child: Slider(
                    value: _currentTextSize,
                    min: 14,
                    max: 64,
                    activeColor: Colors.deepPurpleAccent,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _currentTextSize = v),
                  ),
                ),
                const Icon(Icons.text_fields, color: Colors.white, size: 24),
              ],
            ),
          ),

          // Color palette
          _buildColorPalette(
            selectedColor: _currentTextColor,
            onColorSelected: (c) => setState(() => _currentTextColor = c),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _addOrUpdateText() {
    final text = _textEditController.text.trim();
    if (text.isEmpty) {
      setState(() => _mode = EditorMode.normal);
      return;
    }

    setState(() {
      if (_activeTextIndex != null && _activeTextIndex! < _textOverlays.length) {
        // Update existing
        final overlay = _textOverlays[_activeTextIndex!];
        overlay.text = text;
        overlay.color = _currentTextColor;
        overlay.fontSize = _currentTextSize;
        overlay.fontFamily = _currentFontFamily;
        overlay.hasBackground = _textHasBg;
        overlay.textAlign = _currentTextAlign;
      } else {
        // Add new
        final screenSize = MediaQuery.of(context).size;
        _textOverlays.add(_TextOverlay(
          text: text,
          position: Offset(screenSize.width / 2 - 60, screenSize.height / 3),
          color: _currentTextColor,
          fontSize: _currentTextSize,
          fontFamily: _currentFontFamily,
          hasBackground: _textHasBg,
          textAlign: _currentTextAlign,
        ));
      }
      _mode = EditorMode.normal;
      _activeTextIndex = null;
    });
  }

  // ──────────────────────────────────────────────────────────
  // DRAW TOOLBAR
  // ──────────────────────────────────────────────────────────

  Widget _buildDrawToolbar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Brush size + Eraser
            Row(
              children: [
                // Eraser toggle
                GestureDetector(
                  onTap: () => setState(() => _isEraser = !_isEraser),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isEraser ? Colors.white : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_fix_high,
                      color: _isEraser ? Colors.black : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Brush size
                Expanded(
                  child: Slider(
                    value: _drawBrushSize,
                    min: 1,
                    max: 24,
                    activeColor: _drawColor,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _drawBrushSize = v),
                  ),
                ),
                // Preview circle
                Container(
                  width: _drawBrushSize + 8,
                  height: _drawBrushSize + 8,
                  decoration: BoxDecoration(
                    color: _isEraser ? Colors.grey : _drawColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Color palette
            _buildColorPalette(
              selectedColor: _drawColor,
              onColorSelected: (c) => setState(() {
                _drawColor = c;
                _isEraser = false;
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // STICKER PICKER
  // ──────────────────────────────────────────────────────────

  Widget _buildStickerPicker() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.storyEditorSearch, style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
            // Quick sticker buttons (Instagram-style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _stickerCategoryChip(context.l10n.storyEditorLocation, Icons.location_on, Colors.purple),
                  _stickerCategoryChip(context.l10n.storyEditorMentionCat, Icons.alternate_email, Colors.orange),
                  _stickerCategoryChip(context.l10n.storyEditorMusicCat, Icons.music_note, Colors.pink),
                  _stickerCategoryChip(context.l10n.storyEditorPhoto, Icons.photo, Colors.green),
                  _stickerCategoryChip(context.l10n.storyEditorGif, Icons.gif_box, Colors.green),
                  _stickerCategoryChip(context.l10n.storyEditorPoll, Icons.poll, Colors.purple),
                  _stickerCategoryChip('QUESTIONS', Icons.help_outline, Colors.orange),
                  _stickerCategoryChip('HASHTAG', Icons.tag, Colors.blue),
                  _stickerCategoryChip('COUNTDOWN', Icons.timer, Colors.pink),
                  _stickerCategoryChip('LINK', Icons.link, Colors.green),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            // Emoji grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: _emojiList.length,
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () {
                      final screenSize = MediaQuery.of(context).size;
                      setState(() {
                        _stickerOverlays.add(_StickerOverlay(
                          emoji: _emojiList[i],
                          position: Offset(
                            screenSize.width / 2 - 24,
                            screenSize.height / 3,
                          ),
                        ));
                        _mode = EditorMode.normal;
                      });
                    },
                    child: Center(
                      child: Text(_emojiList[i], style: const TextStyle(fontSize: 28)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stickerCategoryChip(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _addInteractiveSticker(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[850] ?? Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[700]!, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _addInteractiveSticker(String type) {
    final screenSize = MediaQuery.of(context).size;
    switch (type) {
      case 'Poll':
        _showPollCreator();
        break;
      case 'Questions':
        _showQuestionCreator();
        break;
      case 'Countdown':
        _showCountdownCreator();
        break;
      case 'Link':
        _showLinkCreator();
        break;
      case 'Hashtag':
        setState(() {
          _textOverlays.add(_TextOverlay(
            text: '#nearfo',
            position: Offset(screenSize.width / 2 - 40, screenSize.height / 3),
            color: Colors.white,
            fontSize: 24,
            fontFamily: 'Roboto',
            textAlign: TextAlign.center,
            hasBackground: true,
            bgColor: Colors.blue.withOpacity(0.8),
          ));
          _mode = EditorMode.normal;
        });
        break;
      default:
        // GIF and others - add emoji
        break;
    }
  }

  void _showPollCreator() {
    final questionCtrl = TextEditingController(text: 'Ask a question...');
    final option1Ctrl = TextEditingController(text: 'Yes');
    final option2Ctrl = TextEditingController(text: 'No');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create Poll', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: questionCtrl, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'Your question', hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: option1Ctrl, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'Option 1', hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: option2Ctrl, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'Option 2', hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final screenSize = MediaQuery.of(context).size;
                    setState(() {
                      _interactiveStickers.add({
                        'type': 'poll',
                        'question': questionCtrl.text,
                        'options': [option1Ctrl.text, option2Ctrl.text],
                        'position': Offset(screenSize.width / 2 - 100, screenSize.height / 3),
                      });
                      _mode = EditorMode.normal;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Add Poll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuestionCreator() {
    final questionCtrl = TextEditingController(text: 'Ask me anything...');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ask a Question', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: questionCtrl, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'Type your question', hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final screenSize = MediaQuery.of(context).size;
                    setState(() {
                      _interactiveStickers.add({
                        'type': 'question',
                        'question': questionCtrl.text,
                        'position': Offset(screenSize.width / 2 - 100, screenSize.height / 3),
                      });
                      _mode = EditorMode.normal;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Add Question', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountdownCreator() {
    final nameCtrl = TextEditingController(text: 'Countdown');
    DateTime endDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Countdown Timer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'Event name', hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: endDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setSheetState(() => endDate = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(12)),
                  child: Text('End: ${endDate.day}/${endDate.month}/${endDate.year}', style: const TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final screenSize = MediaQuery.of(context).size;
                    setState(() {
                      _interactiveStickers.add({
                        'type': 'countdown',
                        'name': nameCtrl.text,
                        'endDate': endDate.toIso8601String(),
                        'position': Offset(screenSize.width / 2 - 80, screenSize.height / 3),
                      });
                      _mode = EditorMode.normal;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Add Countdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkCreator() {
    final urlCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Swipe Up');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Link', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: urlCtrl, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'https://...', hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: labelCtrl, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'Link label', hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (urlCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final screenSize = MediaQuery.of(context).size;
                    setState(() {
                      _interactiveStickers.add({
                        'type': 'link',
                        'url': urlCtrl.text.trim(),
                        'label': labelCtrl.text.trim().isEmpty ? 'Link' : labelCtrl.text.trim(),
                        'position': Offset(screenSize.width / 2 - 60, screenSize.height * 0.7),
                      });
                      _mode = EditorMode.normal;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Add Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateAILabels() {
    // Smart label suggestions based on content type and time of day
    final hour = DateTime.now().hour;
    final timeLabels = hour < 12 ? ['#GoodMorning', '#MorningVibes'] :
                       hour < 17 ? ['#Afternoon', '#DayTime'] :
                       hour < 21 ? ['#EveningVibes', '#GoldenHour'] :
                                   ['#NightOwl', '#LateNight'];

    final contentLabels = widget.mediaType == 'video'
        ? ['#VideoOfTheDay', '#Reels', '#Trending']
        : ['#PhotoOfTheDay', '#InstaStyle', '#Nearfo'];

    final moodLabels = ['#Vibes', '#Mood', '#Life', '#Explore', '#NearfoMoment'];

    final allLabels = [...timeLabels, ...contentLabels, ...moodLabels];
    allLabels.shuffle();
    final suggested = allLabels.take(6).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Text('AI Suggested Labels', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Tap to add labels to your story', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggested.map((label) => GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  final screenSize = MediaQuery.of(context).size;
                  setState(() {
                    _textOverlays.add(_TextOverlay(
                      text: label,
                      position: Offset(screenSize.width / 2 - 40, screenSize.height * 0.6 + (_textOverlays.length * 30)),
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Roboto',
                      textAlign: TextAlign.center,
                      hasBackground: true,
                      bgColor: Colors.blue.withOpacity(0.7),
                    ));
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.3), Colors.purple.withOpacity(0.3)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.5)),
                  ),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // FILTER SELECTOR
  // ──────────────────────────────────────────────────────────

  Widget _buildFilterSelector() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.only(bottom: 16, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Done button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _mode = EditorMode.normal),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            // Filter thumbnails
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filters.length,
                itemBuilder: (_, i) {
                  final isSelected = _selectedFilterIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilterIndex = i),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          // Thumbnail
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: Colors.deepPurpleAccent, width: 2.5)
                                  : Border.all(color: Colors.white24, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _filters[i].matrix != null
                                  ? ColorFiltered(
                                      colorFilter: ColorFilter.matrix(
                                        _filters[i].matrix!.map((e) => e.toDouble()).toList(),
                                      ),
                                      child: Image.file(
                                        widget.mediaFile,
                                        fit: BoxFit.cover,
                                        width: 64,
                                        height: 64,
                                      ),
                                    )
                                  : Image.file(
                                      widget.mediaFile,
                                      fit: BoxFit.cover,
                                      width: 64,
                                      height: 64,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Name
                          Text(
                            _filters[i].name,
                            style: TextStyle(
                              color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // UPLOAD OVERLAY
  // ──────────────────────────────────────────────────────────

  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: _progress > 0 ? _progress : null,
                color: Colors.deepPurpleAccent,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.uploadType == 'reel' ? 'Posting your reel...' : 'Sharing your story...',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ──────────────────────────────────────────────────────────

  Widget _circleButton({
    required IconData icon,
    VoidCallback? onTap,
    double size = 40,
    Color? color,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _buildColorPalette({
    required Color selectedColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _palette.length,
        itemBuilder: (_, i) {
          final isSelected = _palette[i] == selectedColor;
          return GestureDetector(
            onTap: () => onColorSelected(_palette[i]),
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _palette[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.deepPurpleAccent : Colors.white30,
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.deepPurpleAccent.withOpacity(0.5), blurRadius: 6)]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete?', style: TextStyle(color: Colors.white)),
        content: const Text('Remove this element?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.white),
              title: const Text('Save to Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _saveToGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline, color: Colors.white),
              title: const Text('AI Labels', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _generateAILabels();
              },
            ),
            ListTile(
              leading: const Icon(Icons.comments_disabled_outlined, color: Colors.white),
              title: const Text('Turn off commenting', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMentionPicker() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Mention Someone', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[850] ?? Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search users...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) async {
                            if (val.length < 2) return;
                            setSheetState(() => searching = true);
                            final res = await ApiService.searchUsers(val);
                            if (res.isSuccess && res.data != null) {
                              setSheetState(() {
                                results = res.data!;
                                searching = false;
                              });
                            } else {
                              setSheetState(() => searching = false);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: searching
                    ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                    : results.isEmpty
                        ? Center(child: Text('Search for a user to mention', style: TextStyle(color: Colors.grey[600], fontSize: 14)))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (ctx, i) {
                              final user = results[i];
                              final handle = user['handle']?.toString() ?? '';
                              final name = user['name']?.toString() ?? '';
                              final avatar = user['avatarUrl']?.toString() ?? '';
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                                  child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white)) : null,
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text('@$handle', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  final screenSize = MediaQuery.of(context).size;
                                  setState(() {
                                    _textOverlays.add(_TextOverlay(
                                      text: '@$handle',
                                      position: Offset(screenSize.width / 2 - 50, screenSize.height / 3),
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontFamily: 'Roboto',
                                      textAlign: TextAlign.center,
                                      hasBackground: true,
                                      bgColor: Colors.deepPurple.withOpacity(0.8),
                                    ));
                                  });
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Emoji list ──
  static const List<String> _emojiList = [
    '😀', '😂', '🥰', '😍', '🤩', '😎', '🥳',
    '😇', '🤗', '🤔', '😏', '😴', '🤮', '🥶',
    '👋', '🤝', '👍', '👎', '✌️', '🤞', '👊',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤',
    '🔥', '⭐', '🌈', '☀️', '🌙', '⚡', '💫',
    '🎉', '🎊', '🎈', '🎁', '🏆', '🥇', '🎯',
    '🌸', '🌺', '🌻', '🌹', '🍀', '🌴', '🌊',
    '🦋', '🐱', '🐶', '🐻', '🦄', '🐼', '🦊',
    '🍕', '🍔', '🍟', '🌮', '🍰', '🍩', '☕',
    '📸', '🎵', '🎶', '🎤', '🎸', '🎬', '📱',
    '💪', '🧠', '👑', '💎', '🎭', '🌍', '🚀',
    '💯', '✅', '❌', '⚠️', '💡', '🔔', '📌',
    '👻', '💀', '👽', '🤖', '🎃', '🧿', '🪬',
    '🏠', '🏖️', '🏔️', '🌃', '🎡', '🛫', '🚗',
  ];
}

// ──────────────────────────────────────────────────────────
// DATA MODELS
// ──────────────────────────────────────────────────────────

class _TextOverlay {
  String text;
  Offset position;
  Color color;
  double fontSize;
  String fontFamily;
  bool hasBackground;
  Color bgColor;
  TextAlign textAlign;
  double rotation;
  double scale;

  _TextOverlay({
    required this.text,
    required this.position,
    this.color = Colors.white,
    this.fontSize = 28,
    this.fontFamily = 'Default',
    this.hasBackground = false,
    this.bgColor = Colors.black,
    this.textAlign = TextAlign.center,
    this.rotation = 0,
    this.scale = 1.0,
  });
}

class _StickerOverlay {
  String emoji;
  Offset position;
  double scale;
  double rotation;

  _StickerOverlay({
    required this.emoji,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0,
  });
}

class _DrawStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  _DrawStroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });
}

class _StoryFilter {
  final String name;
  final List<num>? matrix;

  const _StoryFilter(this.name, this.matrix);
}

// ──────────────────────────────────────────────────────────
// DRAWING PAINTER
// ──────────────────────────────────────────────────────────

class _DrawingPainter extends CustomPainter {
  final List<_DrawStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;

  _DrawingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.isEraser ? Colors.transparent : stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke;

      if (stroke.isEraser) {
        paint.blendMode = BlendMode.clear;
      }

      _drawSmoothLine(canvas, stroke.points, paint);
    }

    // Current stroke being drawn
    if (currentPoints.isNotEmpty) {
      final paint = Paint()
        ..color = isEraser ? Colors.transparent : currentColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = currentWidth
        ..style = PaintingStyle.stroke;

      if (isEraser) {
        paint.blendMode = BlendMode.clear;
      }

      _drawSmoothLine(canvas, currentPoints, paint);
    }
  }

  void _drawSmoothLine(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points[0], paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length - 1; i++) {
      final midX = (points[i].dx + points[i + 1].dx) / 2;
      final midY = (points[i].dy + points[i + 1].dy) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, midX, midY);
    }

    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
