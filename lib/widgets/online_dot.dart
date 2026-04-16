import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';

/// A small green dot indicator to show online status on user avatars.
/// Wrap a CircleAvatar with this widget via Stack.
class OnlineDot extends StatelessWidget {
  final bool isOnline;
  final double size;
  final double borderWidth;

  const OnlineDot({
    super.key,
    required this.isOnline,
    this.size = 12,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NearfoColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: NearfoColors.bg, width: borderWidth),
      ),
    );
  }
}

/// Avatar with online dot — convenience widget
class AvatarWithStatus extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackText;
  final double radius;
  final bool isOnline;

  const AvatarWithStatus({
    super.key,
    this.avatarUrl,
    this.fallbackText = '?',
    this.radius = 22,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: NearfoColors.primary,
          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatarUrl!))
              : null,
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? Text(
                  fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.6, color: Colors.white),
                )
              : null,
        ),
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: OnlineDot(isOnline: true, size: radius * 0.5),
          ),
      ],
    );
  }
}
