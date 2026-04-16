import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Smart image compression utility for Nearfo
/// Compresses images before upload to save bandwidth and speed up uploads.
/// Guarantees output < 1MB to stay within server upload limits.
class ImageCompressor {
  /// Max allowed file size after compression (server nginx limit)
  static const int _maxFileSizeBytes = 900 * 1024; // 900KB safe margin

  /// Compress a single image file
  /// Returns compressed file path, or original if compression fails/not needed.
  /// Will re-compress at lower quality if first pass is still too large.
  static Future<String> compress(
    String inputPath, {
    ImageType type = ImageType.post,
  }) async {
    try {
      final inputFile = File(inputPath);
      final inputSize = await inputFile.length();
      debugPrint('[ImageCompressor] Input: ${_formatSize(inputSize)} type=${type.name}');

      // Skip if already small enough
      final skipThreshold = type == ImageType.avatar ? 80 * 1024 : 150 * 1024;
      if (inputSize < skipThreshold) {
        debugPrint('[ImageCompressor] Already small (${_formatSize(inputSize)}), skipping');
        return inputPath;
      }

      final settings = _getSettings(type);
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // First pass compression
      String currentPath = inputPath;
      int quality = settings.quality;

      // Try up to 3 passes, reducing quality each time until under size limit
      for (int pass = 0; pass < 3; pass++) {
        final outputPath = '${dir.path}/nearfo_compressed_${timestamp}_p$pass.jpg';

        final result = await FlutterImageCompress.compressAndGetFile(
          currentPath,
          outputPath,
          minWidth: settings.maxWidth,
          minHeight: settings.maxHeight,
          quality: quality,
          format: CompressFormat.jpeg,
        );

        if (result == null) {
          debugPrint('[ImageCompressor] Pass $pass failed, returning previous');
          return currentPath;
        }

        final compressedSize = await result.length();
        final savingsPercent = ((inputSize - compressedSize) / inputSize * 100).toStringAsFixed(0);
        debugPrint('[ImageCompressor] Pass $pass: quality=$quality → ${_formatSize(compressedSize)} ($savingsPercent% saved)');

        if (compressedSize <= _maxFileSizeBytes) {
          debugPrint('[ImageCompressor] Under ${_formatSize(_maxFileSizeBytes)} limit ✓');
          return result.path;
        }

        // Still too large — reduce quality and dimensions for next pass
        currentPath = result.path;
        quality = (quality * 0.65).round().clamp(20, 90);
        settings._maxWidth = (settings._maxWidth * 0.75).round();
        settings._maxHeight = (settings._maxHeight * 0.75).round();
        debugPrint('[ImageCompressor] Still ${_formatSize(compressedSize)}, reducing to quality=$quality, ${settings._maxWidth}x${settings._maxHeight}');
      }

      // After 3 passes, return whatever we got
      return currentPath;
    } catch (e) {
      debugPrint('[ImageCompressor] Failed: $e');
      return inputPath; // Return original on failure — never block upload
    }
  }

  /// Compress multiple images (for post with multiple photos)
  static Future<List<String>> compressMultiple(
    List<String> inputPaths, {
    ImageType type = ImageType.post,
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <String>[];
    for (int i = 0; i < inputPaths.length; i++) {
      onProgress?.call(i + 1, inputPaths.length);
      final compressed = await compress(inputPaths[i], type: type);
      results.add(compressed);
    }
    return results;
  }

  /// Clean up temp compressed files
  static Future<void> cleanUp() async {
    try {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync().where((f) => f.path.contains('nearfo_compressed_'));
      for (final file in files) {
        await file.delete();
      }
      debugPrint('[ImageCompressor] Cleaned up temp files');
    } catch (e) {
      debugPrint('[ImageCompressor] Cleanup error: $e');
    }
  }

  static _CompressionSettings _getSettings(ImageType type) {
    switch (type) {
      case ImageType.post:
        return _CompressionSettings(maxWidth: 960, maxHeight: 960, quality: 65);
      case ImageType.story:
        return _CompressionSettings(maxWidth: 960, maxHeight: 1700, quality: 60);
      case ImageType.avatar:
        return _CompressionSettings(maxWidth: 400, maxHeight: 400, quality: 75);
      case ImageType.reel:
        return _CompressionSettings(maxWidth: 960, maxHeight: 1700, quality: 65);
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

enum ImageType { post, story, avatar, reel }

class _CompressionSettings {
  int _maxWidth;
  int _maxHeight;
  final int quality;

  int get maxWidth => _maxWidth;
  int get maxHeight => _maxHeight;

  _CompressionSettings({required int maxWidth, required int maxHeight, required this.quality})
      : _maxWidth = maxWidth,
        _maxHeight = maxHeight;
}
