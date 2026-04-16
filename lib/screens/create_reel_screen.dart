import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import '../utils/video_compressor.dart';
import '../l10n/l10n_helper.dart';
import 'story_editor_screen.dart';

// ──────────────────────────────────────────────────────────
// CREATE REEL SCREEN — Instagram-style reel creation
// Pick video → Compress to 720p → Open editor with text/draw/stickers/filters
// Then editor handles upload via uploadType: 'reel'
// ──────────────────────────────────────────────────────────

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool _sourcePicked = false; // Track if user tapped a source option
  String _visibility = 'public';

  // Video constraints
  static const int _maxOriginalSize = 1024 * 1024 * 1024; // 1GB
  static const int _maxCompressedSize = 75 * 1024 * 1024; // 75MB
  static const int _maxDurationSeconds = 90; // 90 second max
  static const int _maxImageSize = 20 * 1024 * 1024; // 20MB for photos

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSourcePicker());
  }

  @override
  void dispose() {
    VideoCompressor.cleanUp();
    super.dispose();
  }

  /// Show bottom sheet to pick video source (Camera or Gallery)
  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NearfoColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.createReelTitle,
                  style: TextStyle(
                    color: NearfoColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.createReelSubtitle,
                  style: TextStyle(color: NearfoColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                // Record Video
                _sourceOption(
                  icon: Icons.videocam_rounded,
                  label: context.l10n.createReelRecordVideo,
                  subtitle: context.l10n.createReelRecordSubtitle,
                  color: Colors.red,
                  onTap: () {
                    _sourcePicked = true;
                    Navigator.pop(ctx);
                    _pickVideo(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 12),
                // Pick from Gallery
                _sourceOption(
                  icon: Icons.photo_library_rounded,
                  label: context.l10n.createReelChooseGallery,
                  subtitle: context.l10n.createReelChooseGallerySubtitle,
                  color: NearfoColors.primary,
                  onTap: () {
                    _sourcePicked = true;
                    Navigator.pop(ctx);
                    _pickVideo(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
                // Upload Photo as Reel
                _sourceOption(
                  icon: Icons.photo_camera_rounded,
                  label: context.l10n.createReelUploadPhoto,
                  subtitle: context.l10n.createReelUploadPhotoSubtitle,
                  color: Colors.purple,
                  onTap: () {
                    _sourcePicked = true;
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                const SizedBox(height: 20),
                // Visibility selector — uses setSheetState to rebuild inside bottom sheet
                Row(
                  children: [
                    Text(context.l10n.createReelWhoCanSee, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                    const Spacer(),
                    _buildVisibilityChipSheet('public', Icons.public, context.l10n.createReelEveryone, setSheetState),
                    const SizedBox(width: 6),
                    _buildVisibilityChipSheet('nearby', Icons.location_on, context.l10n.createReelNearby, setSheetState),
                    const SizedBox(width: 6),
                    _buildVisibilityChipSheet('circle', Icons.people, context.l10n.createReelCircle, setSheetState),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // If user dismissed bottom sheet without picking a source, go back
      if (mounted && !_isProcessing && !_sourcePicked) {
        Navigator.pop(context);
      }
    });
  }

  Widget _sourceOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NearfoColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NearfoColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: NearfoColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: NearfoColors.textDim, size: 16),
          ],
        ),
      ),
    );
  }

  /// Visibility chip that works inside StatefulBuilder bottom sheet
  Widget _buildVisibilityChipSheet(String value, IconData icon, String label, StateSetter setSheetState) {
    final isSelected = _visibility == value;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _visibility = value);
        setState(() {}); // Also update parent state
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? NearfoColors.primary.withOpacity(0.2) : NearfoColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? NearfoColors.primary : NearfoColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? NearfoColors.primaryLight : NearfoColors.textDim),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? NearfoColors.primaryLight : NearfoColors.textDim,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityChip(String value, IconData icon, String label) {
    final isSelected = _visibility == value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? NearfoColors.primary.withOpacity(0.2) : NearfoColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? NearfoColors.primary : NearfoColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? NearfoColors.primaryLight : NearfoColors.textDim),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? NearfoColors.primaryLight : NearfoColors.textDim,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Request permissions based on source
  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.createReelCameraPermission),
              backgroundColor: Colors.red,
              action: SnackBarAction(label: context.l10n.createReelSettings, textColor: Colors.white, onPressed: openAppSettings),
            ),
          );
        }
        return false;
      }
      await Permission.microphone.request();
      return true;
    }

    // Gallery
    if (Platform.isAndroid) {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted || photoStatus.isLimited) return true;
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
    } else {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted || photoStatus.isLimited) return true;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.createReelGalleryPermission),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: context.l10n.createReelSettings, textColor: Colors.white, onPressed: openAppSettings),
        ),
      );
    }
    return false;
  }

  Future<void> _pickImage() async {
    // Request gallery permission
    final allowed = await _requestPermission(ImageSource.gallery);
    if (!allowed) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final file = File(image.path);
      final fileSize = await file.length();

      // Check image size
      if (fileSize > _maxImageSize) {
        _showError(context.l10n.createReelImageTooLarge);
        if (mounted) Navigator.pop(context);
        return;
      }

      // Navigate to StoryEditorScreen with reel upload type and image media type
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryEditorScreen(
              mediaFile: file,
              mediaType: 'image',
              uploadType: 'reel',
              visibility: _visibility,
            ),
          ),
        );
        if (mounted) Navigator.pop(context, result);
      }
    } catch (e) {
      _showError(context.l10n.createReelFailedPickImage(e.toString()));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final allowed = await _requestPermission(source);
    if (!allowed) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: Duration(seconds: _maxDurationSeconds),
      );
      if (video == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final file = File(video.path);
      final fileSize = await file.length();

      // Check original size
      if (fileSize > _maxOriginalSize) {
        _showError(context.l10n.createReelVideoTooLarge);
        if (mounted) Navigator.pop(context);
        return;
      }

      // Compress to 720p
      String finalPath = video.path;
      final compressionProgress = ValueNotifier<double>(0);
      bool cancelled = false;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: NearfoColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(context.l10n.createReelOptimizing, style: TextStyle(color: NearfoColors.text)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.createReelConverting,
                    style: TextStyle(color: NearfoColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<double>(
                    valueListenable: compressionProgress,
                    builder: (_, progress, __) => Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 8,
                            backgroundColor: NearfoColors.border,
                            valueColor: AlwaysStoppedAnimation(NearfoColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: TextStyle(color: NearfoColors.primaryLight, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      cancelled = true;
                      VideoCompressor.cancelCompression();
                      Navigator.pop(ctx);
                    },
                    child: Text(context.l10n.createReelCancel, style: TextStyle(color: NearfoColors.danger)),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      try {
        finalPath = await VideoCompressor.compressForReel(
          video.path,
          onProgress: (p) => compressionProgress.value = p,
        );
      } catch (e) {
        debugPrint('[CreateReel] Compression error: $e');
        if (mounted && !cancelled) Navigator.of(context, rootNavigator: true).pop();
        _showError(context.l10n.createReelCompressionFailed(e.toString()));
        if (mounted) Navigator.pop(context);
        return;
      }

      // Close compression dialog
      if (mounted && !cancelled) Navigator.of(context, rootNavigator: true).pop();
      if (cancelled) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // Check compressed size
      final compressedSize = await File(finalPath).length();
      if (compressedSize > _maxCompressedSize) {
        _showError(context.l10n.createReelCompressedTooLarge(compressedSize));
        if (mounted) Navigator.pop(context);
        return;
      }

      // Navigate to StoryEditorScreen with reel upload type
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryEditorScreen(
              mediaFile: File(finalPath),
              mediaType: 'video',
              uploadType: 'reel',
              visibility: _visibility,
            ),
          ),
        );
        if (mounted) Navigator.pop(context, result);
      }
    } catch (e) {
      _showError(context.l10n.createReelFailedPickVideo(e.toString()));
      if (mounted) Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: NearfoColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: NearfoColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.createReelPreparing,
                    style: TextStyle(color: NearfoColors.textMuted, fontSize: 14),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
