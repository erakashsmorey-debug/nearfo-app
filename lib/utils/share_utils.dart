import 'package:share_plus/share_plus.dart';

/// Centralized share utilities for Nearfo app
class ShareUtils {
  static const String _appUrl = 'https://nearfo.app';
  static const String _tagline = 'Nearfo - Know Your Circle';

  /// Share a post to external apps (WhatsApp, Twitter, etc.)
  static Future<void> sharePost({
    required String postId,
    String? content,
    String? authorName,
    String? imageUrl,
  }) async {
    final buffer = StringBuffer();
    if (content != null && content.isNotEmpty) {
      buffer.writeln(content);
      buffer.writeln();
    }
    if (authorName != null) {
      buffer.writeln('- $authorName on $_tagline');
    }
    buffer.writeln();
    buffer.write('$_appUrl/post/$postId');

    await Share.share(
      buffer.toString(),
      subject: '${authorName ?? 'Someone'} shared a post on Nearfo',
    );
  }

  /// Share a reel
  static Future<void> shareReel({
    required String reelId,
    String? caption,
    String? authorName,
  }) async {
    final text = caption != null && caption.isNotEmpty
        ? '$caption\n\n$_appUrl/reel/$reelId'
        : 'Check out this reel on Nearfo!\n$_appUrl/reel/$reelId';

    await Share.share(text, subject: 'Reel on Nearfo');
  }

  /// Share a user profile
  static Future<void> shareProfile({
    required String handle,
    String? name,
  }) async {
    final displayName = name ?? handle;
    await Share.share(
      'Check out $displayName on Nearfo!\n$_appUrl/@$handle',
      subject: '$displayName on Nearfo',
    );
  }

  /// Share app download link
  static Future<void> shareApp() async {
    await Share.share(
      'Join me on Nearfo - discover people and stories nearby! '
      'Download now: $_appUrl/download',
      subject: 'Join Nearfo - Know Your Circle',
    );
  }

  /// Share a story (screenshot/link)
  static Future<void> shareStory({
    required String userId,
    String? authorName,
  }) async {
    await Share.share(
      'Check out ${authorName ?? 'this'} story on Nearfo!\n$_appUrl/story/$userId',
      subject: 'Story on Nearfo',
    );
  }
}
