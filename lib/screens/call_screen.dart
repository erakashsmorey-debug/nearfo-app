import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/call_sound_service.dart';
import '../services/callkit_service.dart';
import '../utils/json_helpers.dart';

class CallScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final String callerId;
  final String callerName;
  final bool isVideo;
  final bool isIncoming;
  final Map<String, dynamic>? incomingOffer;
  final List<Map<String, dynamic>> bufferedIceCandidates;

  const CallScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    required this.callerId,
    required this.callerName,
    required this.isVideo,
    this.isIncoming = false,
    this.incomingOffer,
    this.bufferedIceCandidates = const [],
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isCameraOff = false;
  bool _isConnected = false;
  bool _isHungUp = false; // Guard against double hangup
  bool _isRinging = true;
  bool _remoteDescriptionSet = false;
  int _unavailableRetries = 0;
  String _callStatus = 'Calling...';
  Timer? _callTimer;
  Timer? _ringTimer;
  Timer? _disconnectTimer;
  int _callDuration = 0;
  final List<RTCIceCandidate> _pendingCandidates = [];

  final CallSoundService _soundService = CallSoundService.instance;

  StreamSubscription? _answeredSub;
  StreamSubscription? _rejectedSub;
  StreamSubscription? _endedSub;
  StreamSubscription? _iceSub;
  StreamSubscription? _unavailableSub;

  // ICE config — loaded dynamically from backend (TURN + STUN)
  Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _requestPermissions();

    // Fetch TURN/STUN credentials from backend (dynamic, not hardcoded)
    try {
      final iceServers = await ApiService.getTurnCredentials();
      _iceConfig = {
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
      };
      final hasTurn = iceServers.any((s) {
        final urls = s['urls']?.toString() ?? '';
        return urls.startsWith('turn:') || urls.startsWith('turns:');
      });
      debugPrint('[Call] ICE servers loaded: ${iceServers.length} servers, TURN available: $hasTurn');
      for (final s in iceServers) {
        debugPrint('[Call]   ICE: ${s['urls']} ${s['username'] != null ? '(auth)' : '(no-auth)'}');
      }
      if (!hasTurn && mounted) {
        debugPrint('[Call] WARNING: No TURN servers — calls will fail on mobile networks!');
      }
    } catch (e) {
      debugPrint('[Call] Failed to fetch TURN credentials, using STUN fallback: $e');
    }

    // Ensure socket is connected before starting call signaling
    if (!SocketService.instance.isConnected) {
      debugPrint('[Call] Socket not connected — waiting for reconnect...');
      if (mounted) setState(() => _callStatus = 'Connecting to server...');
      // Wait up to 5 seconds for socket to reconnect
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (SocketService.instance.isConnected) break;
      }
      if (!SocketService.instance.isConnected) {
        debugPrint('[Call] Socket still not connected — call cannot proceed');
        if (mounted) {
          setState(() => _callStatus = 'No connection');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Cannot connect to server. Check your internet.'), backgroundColor: NearfoColors.danger),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        }
        return;
      }
    }

    _setupSocketListeners();

    // Drain any ICE candidates that were buffered before CallScreen opened
    // (these arrived via socket while CallKit was showing, before our listener was active)
    if (widget.bufferedIceCandidates.isNotEmpty) {
      debugPrint('[Call] Draining ${widget.bufferedIceCandidates.length} buffered ICE candidates');
      for (final data in widget.bufferedIceCandidates) {
        final candidateData = data.asMapOrNull('candidate');
        if (candidateData != null && candidateData['candidate'] != null) {
          final sdpMLineIdx = candidateData['sdpMLineIndex'];
          final candidate = RTCIceCandidate(
            candidateData['candidate']?.toString(),
            candidateData['sdpMid']?.toString(),
            sdpMLineIdx is int ? sdpMLineIdx : null,
          );
          _pendingCandidates.add(candidate);
          debugPrint('[Call] Buffered ICE candidate queued for later application');
        }
      }
    }

    if (!mounted) return;

    if (widget.isIncoming) {
      if (mounted) setState(() => _callStatus = 'Connecting...');
      await _handleIncomingCall();
    } else {
      await _startOutgoingCall();
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      if (widget.isVideo) Permission.camera,
    ].request();
  }

  void _setupSocketListeners() {
    final socket = SocketService.instance;

    _answeredSub = socket.onCallAnswered.listen((data) async {
      if (!mounted) return;
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final answerData = d.asMapOrNull('answer');
      if (answerData != null && answerData['sdp'] != null && answerData['type'] != null) {
        try {
          final answer = RTCSessionDescription(
            answerData['sdp'].toString(),
            answerData['type'].toString(),
          );
          if (_peerConnection == null) {
            debugPrint('[Call] PeerConnection is null, cannot set remote description');
            return;
          }
          await _peerConnection!.setRemoteDescription(answer);
          _remoteDescriptionSet = true;
          // Flush any ICE candidates that arrived before remote description was set
          for (final candidate in _pendingCandidates) {
            await _peerConnection?.addCandidate(candidate);
          }
          _pendingCandidates.clear();
        } catch (e) {
          debugPrint('[Call] Set remote description error: $e');
        }
        if (!mounted) return;
        _ringTimer?.cancel(); // Stop the ring timeout
        _soundService.stop(); // Stop ringback/ringtone
        setState(() {
          _isRinging = false;
          _callStatus = 'Connecting...'; // Wait for ICE to confirm actual media connectivity
        });
        // Call timer will start when ICE state changes to connected/completed
      }
    });

    _rejectedSub = socket.onCallRejected.listen((_) {
      if (!mounted) return;
      _soundService.stop();
      _soundService.playEnded();
      setState(() => _callStatus = 'Call declined');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    });

    _endedSub = socket.onCallEnded.listen((_) {
      if (!mounted) return;
      _soundService.stop();
      _soundService.playEnded();
      setState(() => _callStatus = 'Call ended');
      _cleanup();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
    });

    _iceSub = socket.onIceCandidate.listen((data) async {
      if (!mounted) return;
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final candidateData = d.asMapOrNull('candidate');
      if (candidateData != null && candidateData['candidate'] != null) {
        try {
          final sdpMLineIdx = candidateData['sdpMLineIndex'];
          final candidate = RTCIceCandidate(
            candidateData['candidate']?.toString(),
            candidateData['sdpMid']?.toString(),
            sdpMLineIdx is int ? sdpMLineIdx : null,
          );
          // Queue candidates if remote description not yet set
          if (!_remoteDescriptionSet) {
            _pendingCandidates.add(candidate);
            debugPrint('[Call] Queued ICE candidate (remote desc not set yet)');
          } else {
            await _peerConnection?.addCandidate(candidate);
          }
        } catch (e) {
          debugPrint('[Call] Add ICE candidate error: $e');
        }
      }
    });

    _unavailableSub = socket.onCallUnavailable.listen((data) {
      if (!mounted || _isHungUp) return;
      _unavailableRetries++;
      debugPrint('[Call] call_unavailable received (retry $_unavailableRetries/3)');

      if (_unavailableRetries <= 3) {
        // Don't give up! FCM push is still in transit and may wake the receiver.
        // The receiver's socket might be connecting (race condition on fresh app open).
        // Retry call_initiate after 3 seconds — by then the socket is likely up.
        if (mounted) setState(() => _callStatus = 'Ringing...');
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted || _isConnected || _isHungUp) return;
          debugPrint('[Call] Retrying call_initiate via socket (attempt ${_unavailableRetries + 1})');
          _retryCallInitiate();
        });
      } else {
        // After 3 retries (~9 seconds), if still unavailable, user is truly offline
        debugPrint('[Call] User still unavailable after 3 retries — giving up');
        _soundService.stop();
        _soundService.playEnded();
        if (mounted) setState(() => _callStatus = 'User offline');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _hangUp();
        });
      }
    });
  }

  Future<void> _startOutgoingCall() async {
    setState(() => _callStatus = 'Calling...');

    // Play ringback tone so the caller hears ringing
    _soundService.playRingback();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.isVideo
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      });
    } catch (e) {
      debugPrint('[Call] getUserMedia error: $e');
      if (mounted) {
        setState(() => _callStatus = 'Microphone access failed');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
      return;
    }

    if (widget.isVideo && _localStream != null) {
      _localRenderer.srcObject = _localStream;
    }

    _peerConnection = await createPeerConnection(_iceConfig);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty && mounted) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      SocketService.instance.sendIceCandidate(
        recipientId: widget.recipientId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('[Call] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _hangUp();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Disconnected is temporary — give ICE time to recover (don't hang up)
        if (mounted) setState(() => _callStatus = 'Reconnecting...');
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 10), () {
          if (mounted && !_isConnected) _hangUp();
        });
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('[Call] ICE connection state: $state');
      if (mounted) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          if (!_isConnected) {
            _soundService.stop(); // Stop ringback
            _soundService.playConnected(); // Play connected beep
            // Set audio routing: earpiece for voice calls, speaker for video calls
            _localStream?.getAudioTracks().forEach((track) {
              track.enableSpeakerphone(widget.isVideo);
            });
            setState(() {
              _isConnected = true;
              _isSpeaker = widget.isVideo; // Video defaults to speaker
              _callStatus = 'Connected';
            });
            _startCallTimer();
          }
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          debugPrint('[Call] ICE connection FAILED — attempting ICE restart');
          if (mounted && !_isConnected) {
            _attemptIceRestart();
          }
        }
      }
    };

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    final offerMap = {'sdp': offer.sdp, 'type': offer.type};

    // 1) Socket path — instant delivery if recipient is online
    SocketService.instance.initiateCall(
      callerId: widget.callerId,
      callerName: widget.callerName,
      recipientId: widget.recipientId,
      offer: offerMap,
      isVideo: widget.isVideo,
    );

    // 2) REST API path — triggers FCM push + stores pending offer on server
    //    This ensures recipient gets notification even if app is backgrounded/killed
    unawaited(ApiService.initiateCallPush(
      recipientId: widget.recipientId,
      callerName: widget.callerName,
      offer: offerMap,
      isVideo: widget.isVideo,
    ).then((res) {
      if (!res.isSuccess) {
        debugPrint('[Call] Push initiation failed: ${res.errorMessage} — relying on socket only');
      } else {
        debugPrint('[Call] Push notification sent to recipient');
      }
    }));

    // Timeout: if no answer within 45 seconds, end the call
    _ringTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && _isRinging) {
        _soundService.stop();
        _soundService.playEnded();
        setState(() => _callStatus = 'No answer');
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _hangUp();
        });
      }
    });
  }

  Future<void> _handleIncomingCall() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.isVideo
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      });
    } catch (e) {
      debugPrint('[Call] getUserMedia error: $e');
      if (mounted) {
        setState(() => _callStatus = 'Microphone access failed');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
      return;
    }

    if (widget.isVideo && _localStream != null) {
      _localRenderer.srcObject = _localStream;
    }

    _peerConnection = await createPeerConnection(_iceConfig);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty && mounted) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };

    _peerConnection?.onIceCandidate = (candidate) {
      SocketService.instance.sendIceCandidate(
        recipientId: widget.recipientId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection?.onConnectionState = (state) {
      debugPrint('[Call] Incoming — connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _hangUp();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (mounted) setState(() => _callStatus = 'Reconnecting...');
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 10), () {
          if (mounted && !_isConnected) _hangUp();
        });
      }
    };

    _peerConnection?.onIceConnectionState = (state) {
      debugPrint('[Call] Incoming — ICE connection state: $state');
      if (mounted) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          if (!_isConnected) {
            _soundService.stop(); // Stop ringtone
            _soundService.playConnected(); // Play connected beep
            // Set audio routing: earpiece for voice calls, speaker for video calls
            _localStream?.getAudioTracks().forEach((track) {
              track.enableSpeakerphone(widget.isVideo);
            });
            setState(() {
              _isConnected = true;
              _isSpeaker = widget.isVideo;
              _callStatus = 'Connected';
            });
            _startCallTimer();
          }
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          debugPrint('[Call] Incoming — ICE connection FAILED — waiting for caller ICE restart');
          if (mounted && !_isConnected) {
            setState(() => _callStatus = 'Reconnecting...');
            // Give the caller 8 seconds to send ICE restart, then hang up
            Future.delayed(const Duration(seconds: 8), () {
              if (mounted && !_isConnected) _hangUp();
            });
          }
        }
      }
    };

    // Set the remote offer — try widget data first, then fetch from backend
    Map<String, dynamic>? offerData = widget.incomingOffer;

    // If offer is empty/null (push notification wake-up), fetch from backend
    if (offerData == null || offerData['sdp'] == null || offerData['type'] == null) {
      debugPrint('[Call] No offer in widget data — fetching from backend (push wake-up flow)...');
      if (mounted) setState(() => _callStatus = 'Retrieving call data...');

      // Retry up to 5 times with 2-second intervals (give socket time to deliver or backend to respond)
      for (int attempt = 0; attempt < 5; attempt++) {
        try {
          final res = await ApiService.getPendingCall();
          if (res.isSuccess && res.data != null) {
            final pending = res.data!;
            if (pending['offer'] is Map) {
              final offerMap = Map<String, dynamic>.from(pending['offer'] as Map);
              if (offerMap['sdp'] != null) {
                offerData = offerMap;
                debugPrint('[Call] Got pending offer from backend on attempt ${attempt + 1}');
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('[Call] Fetch pending call attempt ${attempt + 1} failed: $e');
        }
        // Wait 2 seconds before retrying (backend might not have stored it yet)
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
    }

    if (offerData != null && offerData['sdp'] != null && offerData['type'] != null) {
      try {
        final offer = RTCSessionDescription(
          offerData['sdp'].toString(),
          offerData['type'].toString(),
        );
        if (_peerConnection == null) {
          debugPrint('[Call] PeerConnection is null, cannot set remote offer');
          return;
        }
        await _peerConnection!.setRemoteDescription(offer);
        _remoteDescriptionSet = true;
        // Flush any ICE candidates that arrived before remote description was set
        for (final candidate in _pendingCandidates) {
          await _peerConnection?.addCandidate(candidate);
        }
        _pendingCandidates.clear();
      } catch (e) {
        debugPrint('[Call] Set remote offer error: $e');
      }

      // Auto-answer (user already accepted by opening this screen)
      if (_peerConnection == null) return;
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      SocketService.instance.answerCall(
        callerId: widget.recipientId,
        answer: {'sdp': answer.sdp, 'type': answer.type},
      );

      if (!mounted) return;
      setState(() {
        _isRinging = false;
        _callStatus = 'Connecting...'; // Wait for ICE to confirm actual connectivity
      });
      // Call timer will start when ICE state changes to connected/completed
    } else {
      // Offer data still missing after all retries
      debugPrint('[Call] No valid offer data after retries — cannot establish call');
      if (mounted) {
        setState(() => _callStatus = 'Connection failed');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  Future<void> _attemptIceRestart() async {
    try {
      final offer = await _peerConnection!.createOffer({'iceRestart': true});
      await _peerConnection!.setLocalDescription(offer);
      SocketService.instance.initiateCall(
        callerId: widget.callerId,
        callerName: widget.callerName,
        recipientId: widget.recipientId,
        offer: {'sdp': offer.sdp, 'type': offer.type},
        isVideo: widget.isVideo,
      );
      if (mounted) setState(() => _callStatus = 'Reconnecting...');
      debugPrint('[Call] ICE restart offer sent');
    } catch (e) {
      debugPrint('[Call] ICE restart failed: $e');
      _soundService.stop();
      if (mounted) setState(() => _callStatus = 'Connection failed (network)');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _hangUp();
      });
    }
  }

  /// Retry call_initiate via socket — used when call_unavailable fires quickly
  /// (receiver's socket might still be connecting, FCM push might still be in transit)
  Future<void> _retryCallInitiate() async {
    try {
      final currentOffer = await _peerConnection?.getLocalDescription();
      if (currentOffer != null && mounted && !_isHungUp) {
        SocketService.instance.initiateCall(
          callerId: widget.callerId,
          callerName: widget.callerName,
          recipientId: widget.recipientId,
          offer: {'sdp': currentOffer.sdp, 'type': currentOffer.type},
          isVideo: widget.isVideo,
        );
      }
    } catch (e) {
      debugPrint('[Call] Retry call_initiate failed: $e');
    }
  }

  void _startCallTimer() {
    // Prevent duplicate timers
    if (_callTimer != null) return;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleMute() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() => _isMuted = !audioTrack.enabled);
    }
  }

  void _toggleSpeaker() {
    setState(() => _isSpeaker = !_isSpeaker);
    _localStream?.getAudioTracks().forEach((track) {
      track.enableSpeakerphone(_isSpeaker);
    });
  }

  void _toggleCamera() {
    if (_localStream != null && widget.isVideo && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
      setState(() => _isCameraOff = !videoTrack.enabled);
    }
  }

  Future<void> _switchCamera() async {
    if (_localStream != null && widget.isVideo && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks().first;
      // switchCamera() is available directly on MediaStreamTrack in newer flutter_webrtc
      try {
        await videoTrack.switchCamera();
      } catch (e) {
        debugPrint('[Call] switchCamera error: $e');
      }
    }
  }

  void _hangUp() {
    if (_isHungUp) return; // Prevent double hangup
    _isHungUp = true;
    debugPrint('[Call] Hanging up — wasConnected=$_isConnected duration=${_callDuration}s');
    try {
      _soundService.stop();
      _soundService.playEnded();
      // End any lingering CallKit notifications
      unawaited(CallKitService.instance.endAllCalls());
      // Log call for history (fire-and-forget, don't block hangup)
      unawaited(ApiService.logCall(
        receiverId: widget.recipientId,
        type: widget.isVideo ? 'video' : 'audio',
        status: _isConnected ? 'completed' : 'missed',
        duration: _callDuration,
      ));
      // recipientId is always the remote peer (the other person)
      SocketService.instance.endCall(recipientId: widget.recipientId);
    } catch (e) {
      debugPrint('[Call] Error during hangup: $e');
    } finally {
      _cleanup();
      if (mounted) Navigator.pop(context);
    }
  }

  bool _cleanedUp = false;
  void _cleanup() {
    if (_cleanedUp) return; // Prevent double cleanup
    _cleanedUp = true;
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _disconnectTimer?.cancel();
    _soundService.stop();
    _pendingCandidates.clear();
    try {
      _peerConnection?.close();
    } catch (e) {
      debugPrint('[Call] Error closing peer connection: $e');
    }
    _peerConnection = null;
    try {
      _localStream?.getTracks().forEach((t) {
        try { t.stop(); } catch (_) {}
      });
      _localStream?.dispose();
    } catch (e) {
      debugPrint('[Call] Error disposing stream: $e');
    }
    _localStream = null;
  }

  @override
  void dispose() {
    _answeredSub?.cancel();
    _rejectedSub?.cancel();
    _endedSub?.cancel();
    _iceSub?.cancel();
    _unavailableSub?.cancel();
    _cleanup();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (widget.isVideo && _isConnected)
            // Remote video (full screen)
            RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            // Audio call or connecting background
            _buildAudioBackground(),

          // Local video (small pip in corner)
          if (widget.isVideo && _isConnected && !_isCameraOff)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Top status
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (!widget.isVideo || !_isConnected) ...[
                  Text(
                    widget.isVideo ? 'Video Call' : 'Audio Call',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  _isConnected ? _formatDuration(_callDuration) : _callStatus,
                  style: TextStyle(
                    color: _isConnected ? NearfoColors.success : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      isActive: _isMuted,
                      onTap: _toggleMute,
                    ),

                    // Speaker
                    _buildControlButton(
                      icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      label: 'Speaker',
                      isActive: _isSpeaker,
                      onTap: _toggleSpeaker,
                    ),

                    // Camera toggle (only for video)
                    if (widget.isVideo)
                      _buildControlButton(
                        icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        label: _isCameraOff ? 'Camera On' : 'Camera Off',
                        isActive: _isCameraOff,
                        onTap: _toggleCamera,
                      ),

                    // Switch camera (only for video)
                    if (widget.isVideo)
                      _buildControlButton(
                        icon: Icons.flip_camera_android_rounded,
                        label: 'Flip',
                        onTap: _switchCamera,
                      ),
                  ],
                ),
                const SizedBox(height: 30),
                // Hang up button
                GestureDetector(
                  onTap: _hangUp,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a1a2e), Color(0xFF0A0A0A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 56,
              backgroundColor: NearfoColors.primary.withOpacity(0.3),
              child: widget.recipientAvatar != null && widget.recipientAvatar!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: NearfoConfig.resolveMediaUrl(widget.recipientAvatar!),
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildInitial(),
                      ),
                    )
                  : _buildInitial(),
            ),
            const SizedBox(height: 20),
            Text(
              widget.recipientName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (_isRinging)
              _buildPulsingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial() {
    return Text(
      widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPulsingDots() {
    return const SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RingingDot(delay: 0),
          const SizedBox(width: 6),
          _RingingDot(delay: 200),
          const SizedBox(width: 6),
          _RingingDot(delay: 400),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Animated ringing dots
class _RingingDot extends StatefulWidget {
  final int delay;
  const _RingingDot({required this.delay});

  @override
  State<_RingingDot> createState() => _RingingDotState();
}

class _RingingDotState extends State<_RingingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_opacity.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
