import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../screens/call_screen.dart';
import '../services/socket_service.dart';
import '../services/call_sound_service.dart';

class IncomingCallOverlay extends StatefulWidget {
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final Map<String, dynamic> offer;
  final String myUserId;
  final String myName;

  const IncomingCallOverlay({
    super.key,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.isVideo,
    required this.offer,
    required this.myUserId,
    required this.myName,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> {
  @override
  void initState() {
    super.initState();
    // Play ringtone when incoming call overlay is shown
    CallSoundService.instance.playRingtone();
  }

  @override
  void dispose() {
    // Stop ringtone when overlay is dismissed
    CallSoundService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Pulsing ring animation around avatar
            _PulsingRingAvatar(
              avatar: widget.callerAvatar,
              name: widget.callerName,
            ),
            const SizedBox(height: 24),
            Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isVideo ? 'Incoming video call...' : 'Incoming audio call...',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const Spacer(flex: 3),
            // Accept / Reject buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject
                  GestureDetector(
                    onTap: () {
                      CallSoundService.instance.stop();
                      SocketService.instance.rejectCall(callerId: widget.callerId);
                      Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 10),
                        const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  // Accept
                  GestureDetector(
                    onTap: () {
                      CallSoundService.instance.stop(); // Stop ringtone
                      Navigator.pop(context); // Close overlay
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(
                            recipientId: widget.callerId,
                            recipientName: widget.callerName,
                            recipientAvatar: widget.callerAvatar,
                            callerId: widget.myUserId,
                            callerName: widget.myName,
                            isVideo: widget.isVideo,
                            isIncoming: true,
                            incomingOffer: widget.offer,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

/// Pulsing ring animation around avatar for incoming call
class _PulsingRingAvatar extends StatefulWidget {
  final String? avatar;
  final String name;

  const _PulsingRingAvatar({this.avatar, required this.name});

  @override
  State<_PulsingRingAvatar> createState() => _PulsingRingAvatarState();
}

class _PulsingRingAvatarState extends State<_PulsingRingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NearfoColors.primary.withOpacity(_opacity.value),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: NearfoColors.primary.withOpacity(0.3),
            child: widget.avatar != null && widget.avatar!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: NearfoConfig.resolveMediaUrl(widget.avatar!),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(
                        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  )
                : Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
