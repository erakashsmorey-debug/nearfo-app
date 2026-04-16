import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import '../l10n/l10n_helper.dart';
import 'story_editor_screen.dart';
import 'create_reel_screen.dart';
import 'live_screen.dart';

// ──────────────────────────────────────────────────────────
// CREATE STORY SCREEN — Instagram-style story camera/picker
// Shows camera preview with POST | STORY | REEL tabs at bottom
// Supports: single photo, 20-sec video, multiple stories batch
// ──────────────────────────────────────────────────────────

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});
  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  int _selectedTab = 1; // 0=POST, 1=STORY, 2=REEL
  bool _isFlashOn = false;
  bool _isFrontCamera = true;

  // Multi-story queue
  final List<_StoryQueueItem> _storyQueue = [];
  bool _isProcessingQueue = false;
  int _currentQueueIndex = 0;

  // Consecutive story upload counter (max 10)
  int _storiesUploadedCount = 0;
  static const int _maxConsecutiveStories = 10;

  /// Request gallery/camera permissions before picking
  Future<bool> _requestPermission(ImageSource source, {bool video = false}) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.createStoryCamera),
              backgroundColor: Colors.red,
              action: SnackBarAction(label: context.l10n.createStorySettings, textColor: Colors.white, onPressed: openAppSettings),
            ),
          );
        }
        return false;
      }
      if (video) {
        await Permission.microphone.request();
      }
      return true;
    }

    // Gallery
    if (Platform.isAndroid) {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted || photoStatus.isLimited) return true;
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.createStoryGallery),
            backgroundColor: Colors.red,
            action: SnackBarAction(label: context.l10n.createStorySettings, textColor: Colors.white, onPressed: openAppSettings),
          ),
        );
      }
      return false;
    }

    // iOS
    final photoStatus = await Permission.photos.request();
    if (photoStatus.isGranted || photoStatus.isLimited) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.createStoryPhotoLib),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: context.l10n.createStorySettings, textColor: Colors.white, onPressed: openAppSettings),
        ),
      );
    }
    return false;
  }

  // ────────────────────────────────────────
  // SINGLE MEDIA PICK (Photo / Video)
  // ────────────────────────────────────────

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    final allowed = await _requestPermission(source, video: video);
    if (!allowed) return;

    try {
      final picker = ImagePicker();
      final XFile? file;
      String mediaType;

      if (video) {
        // 30-second max for story videos
        file = await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 30));
        mediaType = 'video';
      } else {
        file = await picker.pickImage(source: source, imageQuality: 90);
        mediaType = 'image';
      }

      if (file != null && mounted) {
        _navigateToEditor(File(file.path), mediaType);
      }
    } catch (e) {
      debugPrint('[Story] Pick media error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.createStoryCouldNotSelect('${e.toString().length > 60 ? e.toString().substring(0, 60) : e}')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ────────────────────────────────────────
  // MULTIPLE STORIES PICK (Batch upload)
  // ────────────────────────────────────────

  Future<void> _pickMultipleStories() async {
    final allowed = await _requestPermission(ImageSource.gallery);
    if (!allowed) return;

    try {
      final picker = ImagePicker();
      final List<XFile> files = await picker.pickMultiImage(imageQuality: 90);

      if (files.isEmpty) return;

      if (files.length > 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.createStoryMax10),
              backgroundColor: NearfoColors.warning,
            ),
          );
        }
        return;
      }

      // Build queue
      _storyQueue.clear();
      for (final f in files) {
        _storyQueue.add(_StoryQueueItem(file: File(f.path), mediaType: 'image'));
      }

      if (mounted) {
        setState(() {
          _isProcessingQueue = true;
          _currentQueueIndex = 0;
        });
        unawaited(_processStoryQueue());
      }
    } catch (e) {
      debugPrint('[Story] Multi pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.createStoryCouldNotSelectImages('${e.toString().length > 60 ? e.toString().substring(0, 60) : e}')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Process each story in the queue one by one through the editor
  Future<void> _processStoryQueue() async {
    if (_currentQueueIndex >= _storyQueue.length) {
      // All done
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.createStoryStoriesUploaded(_storyQueue.length)),
              ],
            ),
            backgroundColor: NearfoColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
      return;
    }

    final item = _storyQueue[_currentQueueIndex];

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryEditorScreen(
            mediaFile: item.file,
            mediaType: item.mediaType,
            uploadType: 'story',
          ),
        ),
      );

      if (result == true) {
        // Story uploaded successfully, move to next
        setState(() => _currentQueueIndex++);
        unawaited(_processStoryQueue());
      } else {
        // User cancelled or error — ask if they want to skip or stop
        if (mounted && _currentQueueIndex < _storyQueue.length - 1) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: NearfoColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.l10n.createStoryContinueUploading,
                style: TextStyle(color: NearfoColors.text),
              ),
              content: Text(
                context.l10n.createStoryProgress(_currentQueueIndex, _storyQueue.length),
                style: TextStyle(color: NearfoColors.textMuted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.l10n.createStoryStop, style: TextStyle(color: NearfoColors.danger)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.l10n.createStoryContinue, style: TextStyle(color: NearfoColors.primary)),
                ),
              ],
            ),
          );

          if (shouldContinue == true) {
            setState(() => _currentQueueIndex++);
            unawaited(_processStoryQueue());
          } else {
            if (mounted) Navigator.pop(context, _currentQueueIndex > 0);
          }
        } else {
          if (mounted) Navigator.pop(context, _currentQueueIndex > 0);
        }
      }
    }
  }

  void _navigateToEditor(File file, String mediaType) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryEditorScreen(
          mediaFile: file,
          mediaType: mediaType,
          uploadType: 'story',
        ),
      ),
    );
    if (result == true && mounted) {
      _storiesUploadedCount++;

      // Check if max limit reached
      if (_storiesUploadedCount >= _maxConsecutiveStories) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.createStoryMaxReached(_storiesUploadedCount)),
              ],
            ),
            backgroundColor: NearfoColors.success,
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      // Ask user if they want to add another story
      final addMore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NearfoColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(context.l10n.createStoryUploaded, style: TextStyle(color: NearfoColors.text, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.createStoryAddAnother,
                style: TextStyle(color: NearfoColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.createStoryCount(_storiesUploadedCount, _maxConsecutiveStories),
                style: TextStyle(color: NearfoColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.createStoryDone, style: TextStyle(color: NearfoColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: NearfoColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(context.l10n.createStoryAddAnotherBtn, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (addMore == true && mounted) {
        // Stay on create story screen — user can pick another photo/video
        // No action needed, user is back on the camera/picker screen
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _takePhoto() => _pickMedia(ImageSource.camera);
  void _recordVideo() => _pickMedia(ImageSource.camera, video: true);
  void _pickFromGallery() => _pickMedia(ImageSource.gallery);
  void _pickVideoFromGallery() => _pickMedia(ImageSource.gallery, video: true);

  @override
  Widget build(BuildContext context) {
    // If processing multi-story queue, show progress
    if (_isProcessingQueue) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: NearfoColors.primary),
              const SizedBox(height: 20),
              Text(
                context.l10n.createStoryProcessing(_currentQueueIndex + 1, _storyQueue.length),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.createStoryEditEach,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Camera preview placeholder ──
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(bottom: 200),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, size: 60, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      Text(
                        'Tap the button to take a photo\nLong press for 30s video\nor select from gallery below',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Top bar: Close + Flash + Settings ──
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                  // Flash
                  GestureDetector(
                    onTap: () => setState(() => _isFlashOn = !_isFlashOn),
                    child: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  // Settings — open app settings for camera/storage permissions
                  GestureDetector(
                    onTap: () => openAppSettings(),
                    child: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            // ── Left side: Create, Boomerang, Layout, Multi ──
            Positioned(
              left: 16,
              bottom: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sideOption(Icons.text_fields, context.l10n.createStoryCreate, _sideOptionTapCreate),
                  const SizedBox(height: 16),
                  _sideOption(Icons.collections, context.l10n.createStoryMultiple, () {
                    _pickMultipleStories();
                  }),
                  const SizedBox(height: 16),
                  _sideOption(Icons.videocam, context.l10n.createStoryVideoLabel, () {
                    _pickVideoFromGallery();
                  }),
                  const SizedBox(height: 16),
                  _sideOption(Icons.all_inclusive, context.l10n.createStoryBoomerang, () async {
                    final picker = ImagePicker();
                    final video = await picker.pickVideo(
                      source: ImageSource.gallery,
                      maxDuration: const Duration(seconds: 3),
                    );
                    if (video != null && mounted) {
                      unawaited(Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StoryEditorScreen(
                          mediaFile: File(video.path),
                          mediaType: 'video',
                          uploadType: 'story',
                        ),
                      )));
                    }
                  }),
                  const SizedBox(height: 16),
                  _sideOption(Icons.grid_view_rounded, context.l10n.createStoryLayout, () async {
                    final picker = ImagePicker();
                    final images = await picker.pickMultiImage(imageQuality: 85);
                    if (images.isNotEmpty && mounted) {
                      // Use first image as the main story with others as grid
                      unawaited(Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StoryEditorScreen(
                          mediaFile: File(images.first.path),
                          mediaType: 'image',
                          uploadType: 'story',
                        ),
                      )));
                    }
                  }),
                ],
              ),
            ),

            // ── Right side: Video record hint ──
            if (_selectedTab == 1)
              Positioned(
                right: 16,
                bottom: 260,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                          const SizedBox(height: 2),
                          Text(context.l10n.createStory30s, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(context.l10n.createStoryVideo, style: const TextStyle(color: Colors.white60, fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Bottom section: Gallery + Camera button + Tabs ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Action hint ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _selectedTab == 2
                            ? context.l10n.createStoryTapReel
                            : context.l10n.createStoryTapPhoto,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ),

                    // ── Gallery + Camera + Flip row ──
                    SizedBox(
                      height: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gallery button
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 2),
                                color: Colors.grey[800],
                              ),
                              child: const Icon(Icons.photo_library, color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Multi-select button
                          GestureDetector(
                            onTap: _pickMultipleStories,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: NearfoColors.primary, width: 2),
                                color: NearfoColors.primary.withOpacity(0.2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.collections, color: Colors.white, size: 18),
                                  Text(context.l10n.createStoryMulti, style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ── Camera button ──
                          GestureDetector(
                            onTap: _selectedTab == 2 ? _recordVideo : _takePhoto,
                            onLongPress: _recordVideo,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selectedTab == 2 ? Colors.red : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ── Video from gallery button ──
                          GestureDetector(
                            onTap: _pickVideoFromGallery,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange, width: 2),
                                color: Colors.orange.withOpacity(0.15),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam, color: Colors.orange, size: 18),
                                  Text(context.l10n.createStory30s, style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ── Flip camera ──
                          GestureDetector(
                            onTap: () => setState(() => _isFrontCamera = !_isFrontCamera),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[800],
                              ),
                              child: const Icon(Icons.cameraswitch, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── POST | STORY | REEL | LIVE tabs ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile pic
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[700],
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                        _tabButton(context.l10n.createStoryPost, 0),
                        const SizedBox(width: 16),
                        _tabButton(context.l10n.storyLabel, 1),
                        const SizedBox(width: 16),
                        _tabButton(context.l10n.reelLabel, 2),
                        const SizedBox(width: 16),
                        _tabButton(context.l10n.createStoryLive, 3),
                      ],
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

  Widget _tabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (index == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveScreen()));
          return;
        }
        if (index == 0) {
          // POST mode — go back to compose screen
          Navigator.pop(context);
          return;
        }
        if (index == 2) {
          // REEL mode — open dedicated reel creation screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateReelScreen()),
          ).then((result) {
            if (result == true && mounted) {
              Navigator.pop(context, true);
            }
          });
          return;
        }
        setState(() => _selectedTab = index);
      },
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[600],
          fontSize: isSelected ? 16 : 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _sideOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _sideOptionTapCreate() async {
    // Text story — create a blank dark image and open editor
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1080, 1920),
        Paint()..color = const Color(0xFF1A1A2E),
      );
      final picture = recorder.endRecording();
      final img = await picture.toImage(1080, 1920);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      final tempDir = await getTemporaryDirectory();
      final blankFile = File('${tempDir.path}/text_story_${DateTime.now().millisecondsSinceEpoch}.png');
      await blankFile.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      unawaited(Navigator.push(context, MaterialPageRoute(
        builder: (_) => StoryEditorScreen(
          mediaFile: blankFile,
          mediaType: 'image',
          uploadType: 'story',
        ),
      )));
    } catch (e) {
      debugPrint('[CreateStory] Create text story error: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Internal model for multi-story queue
class _StoryQueueItem {
  final File file;
  final String mediaType;

  _StoryQueueItem({required this.file, required this.mediaType});
}
