import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:light_compressor/light_compressor.dart';
import 'package:path_provider/path_provider.dart';

class VideoCompressor {
  static final LightCompressor _compressor = LightCompressor();
  static StreamSubscription<dynamic>? _progressSub;

  /// Compress video to 720p quality for optimal upload.
  /// Returns compressed file path, or original path if compression fails.
  static Future<String> compressTo720p(
    String inputPath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final inputFile = File(inputPath);
      final inputSize = await inputFile.length();

      // If already under 5MB, skip compression
      if (inputSize < 5 * 1024 * 1024) {
        onProgress?.call(100.0);
        return inputPath;
      }

      await _progressSub?.cancel();
      if (onProgress != null) {
        _progressSub = _compressor.onProgressUpdated.listen((progress) {
          onProgress(progress);
        });
      }

      final videoName =
          'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final Result result = await _compressor.compressVideo(
        path: inputPath,
        videoQuality: VideoQuality.medium,
        isMinBitrateCheckEnabled: false,
        video: Video(videoName: videoName),
        android: AndroidConfig(isSharedStorage: false),
        ios: IOSConfig(saveInGallery: false),
      );

      await _progressSub?.cancel();
      _progressSub = null;

      if (result is OnSuccess) {
        final compressedSize =
            await File(result.destinationPath).length();
        final savingsPercent =
            ((inputSize - compressedSize) / inputSize * 100)
                .toStringAsFixed(0);
        debugPrint(
            '[VideoCompressor] Compressed: ${_formatSize(inputSize)} -> ${_formatSize(compressedSize)} ($savingsPercent% saved)');
        return result.destinationPath;
      }

      debugPrint('[VideoCompressor] Compression returned non-success');
      return inputPath;
    } catch (e) {
      await _progressSub?.cancel();
      _progressSub = null;
      debugPrint('[VideoCompressor] Compression failed: $e');
      return inputPath;
    }
  }

  /// Compress video to 720p specifically for Reels — ALWAYS compresses.
  static Future<String> compressForReel(
    String inputPath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final inputFile = File(inputPath);
      final inputSize = await inputFile.length();

      await _progressSub?.cancel();
      if (onProgress != null) {
        _progressSub = _compressor.onProgressUpdated.listen((progress) {
          onProgress(progress);
        });
      }

      final videoName = 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final Result result = await _compressor.compressVideo(
        path: inputPath,
        videoQuality: VideoQuality.medium,
        isMinBitrateCheckEnabled: false,
        video: Video(videoName: videoName),
        android: AndroidConfig(isSharedStorage: false),
        ios: IOSConfig(saveInGallery: false),
      );

      await _progressSub?.cancel();
      _progressSub = null;

      if (result is OnSuccess) {
        final compressedSize =
            await File(result.destinationPath).length();
        final savingsPercent =
            ((inputSize - compressedSize) / inputSize * 100)
                .toStringAsFixed(0);
        debugPrint(
            '[VideoCompressor] Reel compressed: ${_formatSize(inputSize)} -> ${_formatSize(compressedSize)} ($savingsPercent% saved)');
        return result.destinationPath;
      }

      debugPrint('[VideoCompressor] Reel compression returned non-success');
      return inputPath;
    } catch (e) {
      await _progressSub?.cancel();
      _progressSub = null;
      debugPrint('[VideoCompressor] Reel compression failed: $e');
      return inputPath;
    }
  }

  /// Cancel any ongoing compression
  static Future<void> cancelCompression() async {
    await LightCompressor.cancelCompression();
  }

  /// Clean up temp compressed files
  static Future<void> cleanUp() async {
    try {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        if (file.path.contains('compressed_') ||
            file.path.contains('reel_')) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[VideoCompressor] Cleanup failed: $e');
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
