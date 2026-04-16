import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../utils/constants.dart';
import '../providers/feed_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/video_compressor.dart';
import '../utils/image_compressor.dart';
import '../l10n/l10n_helper.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _contentController = TextEditingController();
  String _selectedMood = '';
  bool _isPosting = false;
  final List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();

  late List<Map<String, String>> _moods;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _moods = [
      {'emoji': '😊', 'label': context.l10n.composeMoodHappy},
      {'emoji': '😎', 'label': context.l10n.composeMoodCool},
      {'emoji': '🔥', 'label': context.l10n.composeMoodFire},
      {'emoji': '😴', 'label': context.l10n.composeMoodSleepy},
      {'emoji': '🤔', 'label': context.l10n.composeMoodThinking},
      {'emoji': '😤', 'label': context.l10n.composeMoodAngry},
      {'emoji': '🥳', 'label': context.l10n.composeMoodParty},
      {'emoji': '❤️', 'label': context.l10n.composeMoodLove},
    ];
  }

  @override
  void dispose() {
    _contentController.dispose();
    _videoController?.dispose();
    VideoCompressor.cleanUp(); // Clean temp compressed video files
    ImageCompressor.cleanUp(); // Clean temp compressed image files
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedVideo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.composeRemoveVideoFirst), backgroundColor: NearfoColors.warning),
      );
      return;
    }
    final images = await _picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (images.isNotEmpty) {
      setState(() {
        final remaining = 5 - _selectedImages.length;
        _selectedImages.addAll(images.take(remaining));
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_selectedImages.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.composeRemovePhotosFirst), backgroundColor: NearfoColors.warning),
      );
      return;
    }
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video != null) {
      // Check original file size (reject if over 1GB)
      final originalFile = File(video.path);
      final originalSize = await originalFile.length();
      if (originalSize > 1024 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.composeVideoTooLarge), backgroundColor: NearfoColors.danger),
          );
        }
        return;
      }

      // Show compression progress dialog
      final progressNotifier = ValueNotifier<double>(0);
      String? compressedPath;
      bool cancelled = false;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: NearfoColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (ctx, progress, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Icon(Icons.video_settings, color: NearfoColors.primary, size: 40),
                  const SizedBox(height: 16),
                  Text(context.l10n.composeOptimizingVideo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: NearfoColors.text)),
                  const SizedBox(height: 4),
                  Text(context.l10n.composeConverting720p, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                  SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: NearfoColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(NearfoColors.primary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${progress.toStringAsFixed(0)}%', style: TextStyle(color: NearfoColors.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      cancelled = true;
                      VideoCompressor.cancelCompression();
                      Navigator.pop(ctx);
                    },
                    child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.danger)),
                  ),
                ],
              ),
            ),
          ),
        );

        // Run compression
        compressedPath = await VideoCompressor.compressTo720p(
          video.path,
          onProgress: (progress) {
            if (!cancelled) {
              progressNotifier.value = progress;
            }
          },
        );

        // Close progress dialog
        if (mounted && !cancelled) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        progressNotifier.dispose();
      }

      if (cancelled || compressedPath == null) return;

      // Check compressed file size (max 75MB after compression)
      final compressedFile = File(compressedPath);
      final compressedSize = await compressedFile.length();
      if (compressedSize > 75 * 1024 * 1024) {
        if (mounted) {
          final sizeMB = (compressedSize / (1024 * 1024)).toStringAsFixed(1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.composeVideoStillLarge(sizeMB: sizeMB)), backgroundColor: NearfoColors.danger),
          );
        }
        return;
      }

      _videoController?.dispose();
      final controller = VideoPlayerController.file(compressedFile);
      try {
        await controller.initialize();
      } catch (e) {
        controller.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.composeVideoPreviewError(error: e.toString())), backgroundColor: NearfoColors.danger),
          );
        }
        return;
      }
      if (mounted) {
        final savedMB = ((originalSize - compressedSize) / (1024 * 1024)).toStringAsFixed(1);
        setState(() {
          _selectedVideo = XFile(compressedPath!);
          _videoController = controller;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.composeVideoOptimized(savedMB: savedMB)),
            backgroundColor: NearfoColors.success,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _removeVideo() {
    _videoController?.dispose();
    setState(() {
      _selectedVideo = null;
      _videoController = null;
    });
  }

  void _post() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty && _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.composeEmptyPost), backgroundColor: NearfoColors.danger),
      );
      return;
    }

    setState(() => _isPosting = true);

    // Compress & upload images (with 60s timeout)
    List<String> imageUrls = [];
    if (_selectedImages.isNotEmpty) {
      try {
        // Compress all images before upload
        final rawPaths = _selectedImages.map((x) => x.path).toList();
        final paths = await ImageCompressor.compressMultiple(rawPaths, type: ImageType.post);
        final uploadRes = await ApiService.uploadImages(paths, folder: 'posts')
            .timeout(const Duration(seconds: 60));
        if (uploadRes.isSuccess && uploadRes.data != null) {
          imageUrls = uploadRes.data!;
          debugPrint('[Compose] Uploaded image URLs: $imageUrls');
        } else {
          if (mounted) {
            setState(() => _isPosting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(uploadRes.errorMessage ?? context.l10n.composeImageUploadFailed), backgroundColor: NearfoColors.danger),
            );
          }
          return;
        }
      } on TimeoutException {
        if (mounted) {
          setState(() => _isPosting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.composeUploadTimeout), backgroundColor: NearfoColors.danger),
          );
        }
        return;
      }
    }

    // Upload video if any (with 2min timeout for larger files)
    String? videoUrl;
    if (_selectedVideo != null) {
      try {
        debugPrint('[Compose] Uploading video: ${_selectedVideo!.path}');
        final uploadRes = await ApiService.uploadVideo(_selectedVideo!.path, folder: 'posts')
            .timeout(const Duration(seconds: 180));
        if (uploadRes.isSuccess && uploadRes.data != null) {
          videoUrl = uploadRes.data!;
          debugPrint('[Compose] Video uploaded: $videoUrl');
        } else {
          if (mounted) {
            setState(() => _isPosting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(uploadRes.errorMessage ?? context.l10n.composeVideoUploadFailed), backgroundColor: NearfoColors.danger),
            );
          }
          return;
        }
      } on TimeoutException {
        if (mounted) {
          setState(() => _isPosting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.composeVideoUploadTimeout), backgroundColor: NearfoColors.danger),
          );
        }
        return;
      }
    }

    // Build a non-empty content string — backend requires it
    String postContent = content;
    if (postContent.isEmpty && _selectedMood.isNotEmpty) {
      postContent = _selectedMood;
    }
    if (postContent.isEmpty) {
      // Image/video-only post — backend rejects empty/whitespace content
      if (_selectedVideo != null || videoUrl != null) {
        postContent = '🎬';
      } else if (imageUrls.isNotEmpty || _selectedImages.isNotEmpty) {
        postContent = '📷';
      } else {
        postContent = '✨';
      }
    }

    final error = await context.read<FeedProvider>().createPost(
      content: postContent,
      mood: _selectedMood.isNotEmpty ? _selectedMood : null,
      images: imageUrls,
      video: videoUrl,
    );
    setState(() => _isPosting = false);

    if (!mounted) return;
    if (error == null) {
      // DEBUG: Show actual image URLs so we can diagnose blank images
      if (imageUrls.isNotEmpty) {
        debugPrint('[Compose] SUCCESS with images: $imageUrls');
        final resolvedUrls = imageUrls.map((u) => NearfoConfig.resolveMediaUrl(u)).toList();
        debugPrint('[Compose] Resolved URLs: $resolvedUrls');
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.composePosted), backgroundColor: NearfoColors.success),
      );
    } else {
      debugPrint('[Compose] Post failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: NearfoColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: NearfoColors.text),
        ),
        title: Text(context.l10n.composeTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: NearfoColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton(
                onPressed: _isPosting ? null : _post,
                child: _isPosting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(context.l10n.post, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: NearfoColors.primary,
                        child: Text(user?.initials ?? '?', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'You', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: NearfoColors.accent),
                              const SizedBox(width: 2),
                              Text(user?.displayLocation ?? 'Your location', style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Content input
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 4,
                    maxLength: NearfoConfig.maxPostLength,
                    autofocus: true,
                    style: TextStyle(color: NearfoColors.text, fontSize: 18, height: 1.5),
                    decoration: InputDecoration(
                      hintText: context.l10n.composeHint,
                      hintStyle: TextStyle(color: NearfoColors.textDim, fontSize: 18),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: NearfoColors.textDim),
                    ),
                  ),

                  // Image previews
                  if (_selectedImages.isNotEmpty) ...[
                    SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_selectedImages[i].path),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Video preview
                  if (_selectedVideo != null && _videoController != null) ...[
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio.clamp(0.5, 2.0),
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: _removeVideo,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 32, color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Mood selector
                  Text(context.l10n.composeMood, style: TextStyle(fontWeight: FontWeight.w600, color: NearfoColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moods.map((mood) {
                      final isSelected = _selectedMood == mood['label'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMood = isSelected ? '' : mood['label']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? NearfoColors.primary.withOpacity(0.2) : NearfoColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? NearfoColors.primary : NearfoColors.border,
                            ),
                          ),
                          child: Text(
                            '${mood['emoji']} ${mood['label']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? NearfoColors.primaryLight : NearfoColors.textMuted,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Fixed bottom attachment bar - always visible above keyboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              border: Border(top: BorderSide(color: NearfoColors.border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImages,
                    child: _attachButton(Icons.photo_library_rounded, '${context.l10n.composePhoto}${_selectedImages.isNotEmpty ? ' (${_selectedImages.length})' : ''}', NearfoColors.success),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _pickVideo,
                    child: _attachButton(Icons.videocam_rounded, _selectedVideo != null ? '${context.l10n.composeVideo} (1)' : context.l10n.composeVideo, NearfoColors.pink),
                  ),
                  const SizedBox(width: 12),
                  _attachButton(Icons.location_on_rounded, context.l10n.composeLocation, NearfoColors.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachButton(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
