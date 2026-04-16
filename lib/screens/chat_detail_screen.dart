import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../utils/image_compressor.dart';
import '../utils/video_compressor.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';
import 'call_screen.dart';
import 'chat_settings_screen.dart';
import 'group_info_screen.dart';
import '../services/ad_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_chat_storage.dart';
import '../services/offline_message_queue.dart';
import 'package:screenshot_callback/screenshot_callback.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import '../utils/json_helpers.dart';
import '../widgets/gif_picker.dart';
import '../services/giphy_service.dart';
import '../l10n/l10n_helper.dart';

class ChatDetailScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientHandle;
  final String? recipientAvatar;
  final bool isOnline;
  final String lastSeenText;
  final String? existingChatId; // For group chats that already have a chatId
  final bool isGroup;

  const ChatDetailScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientHandle,
    this.recipientAvatar,
    this.isOnline = false,
    this.lastSeenText = '',
    this.existingChatId,
    this.isGroup = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  String? _chatId;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _messagesPage = 1;
  bool _hasMoreMessages = true;
  static const int _messagesLimit = 30;
  final ValueNotifier<bool> _isSending = ValueNotifier(false);
  final ValueNotifier<bool> _recipientOnline = ValueNotifier(false);
  final ValueNotifier<bool> _recipientTyping = ValueNotifier(false);
  bool _isEncrypted = true;
  bool _isRecipientRestricted = false;
  bool _isRecipientBlocked = false;
  int _pendingRestrictedCount = 0; // Count of restricted messages waiting to be accepted
  bool _restrictedMessagesAccepted = false; // User tapped "Accept" on message request
  bool _showOnlineStatus = true; // Global online status visibility
  String? _myUserId;
  Color _chatThemeColor = const Color(0xFF6C5CE7); // Default theme color
  final ValueNotifier<bool> _isRecording = ValueNotifier(false);
  final ValueNotifier<bool> _showEmojiPicker = ValueNotifier(false);
  final ValueNotifier<bool> _showGifPicker = ValueNotifier(false);
  final ValueNotifier<int> _recordingSeconds = ValueNotifier(0);

  static const Map<String, Color> _themeColors = {
    'Default': Color(0xFF6C5CE7),
    'Ocean': Color(0xFF0984E3),
    'Sunset': Color(0xFFE17055),
    'Forest': Color(0xFF00B894),
    'Berry': Color(0xFFE84393),
    'Midnight': Color(0xFF2D3436),
    'Gold': Color(0xFFFDAA00),
    'Lavender': Color(0xFFA29BFE),
  };

  StreamSubscription? _newMessageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _stopTypingSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _messagesReadSub;
  StreamSubscription? _messageEditedSub;
  StreamSubscription? _messageReactionSub;
  StreamSubscription? _messageReactionRemovedSub;
  StreamSubscription? _messageDeletedSub;
  StreamSubscription? _screenshotSub;
  StreamSubscription? _queueUpdateSub;
  StreamSubscription? _reconnectedSub;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _userBlockedSub;
  StreamSubscription? _userRestrictedSub;
  Timer? _typingTimer;
  bool _allRead = false; // Whether recipient has read all messages
  bool _isOffline = false; // Connectivity state for UI banner

  // Reply state
  Map<String, dynamic>? _replyingToMessage;
  // Edit state
  Map<String, dynamic>? _editingMessage;
  final FocusNode _messageFocusNode = FocusNode();

  // Voice recording state
  bool _isRecordingLocked = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  String? _recordingPath;
  aw.RecorderController? _recorderController;

  // Screenshot detection
  ScreenshotCallback? _screenshotCallback;

  @override
  void initState() {
    super.initState();
    _recipientOnline.value = widget.isOnline;
    final authUser = context.read<AuthProvider>().user;
    _myUserId = authUser?.id;
    _showOnlineStatus = authUser?.showOnlineStatus ?? true;
    // Record action for non-intrusive interstitial (shows every 5th transition)
    AdService.instance.recordAction();
    // Scroll listener for loading older messages when scrolling to top
    _scrollController.addListener(_onScrollForPagination);
    // Close emoji/gif picker when keyboard opens
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        _showEmojiPicker.value = false;
        _showGifPicker.value = false;
      }
    });
    // Load cached theme instantly (prevents flash of default theme on app update)
    _loadCachedTheme();
    _initChat();
  }

  /// Unique cache key for this chat (use existingChatId for groups, recipientId for 1:1)
  String get _themeCacheKey => widget.existingChatId ?? widget.recipientId;

  /// Load cached chat theme from SharedPreferences (instant, no network wait)
  Future<void> _loadCachedTheme() async {
    if (_themeCacheKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final cachedTheme = prefs.getString('chat_theme_$_themeCacheKey');
    if (cachedTheme != null && mounted) {
      setState(() {
        _chatThemeColor = _themeColors[cachedTheme] ?? const Color(0xFF6C5CE7);
      });
    }
  }

  /// Save chat theme to SharedPreferences for instant loading next time
  Future<void> _cacheTheme(String themeName) async {
    if (_themeCacheKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_theme_$_themeCacheKey', themeName);
  }

  Future<void> _initChat() async {
    // For group chats with existing chatId, skip createOrGetChat
    if (widget.existingChatId != null && widget.existingChatId!.isNotEmpty) {
      _chatId = widget.existingChatId;
    } else {
      // Create or get existing chat with this recipient
      final chatRes = await ApiService.createOrGetChat(widget.recipientId);
      if (!chatRes.isSuccess || chatRes.data == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(chatRes.errorMessage ?? 'Failed to load chat'),
              backgroundColor: NearfoColors.danger,
            ),
          );
        }
        return;
      }

      _chatId = chatRes.data?.asStringOrNull('_id');
      if (_chatId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _isEncrypted = chatRes.data?.asBool('isEncrypted', true) ?? true;
    }

    // Load chat settings (theme, restriction, block, etc.)
    final settingsRes = await ApiService.getChatSettings(_chatId!);
    if (settingsRes.isSuccess && settingsRes.data != null) {
      final themeName = settingsRes.data!.asString('theme', 'Default');
      _chatThemeColor = _themeColors[themeName] ?? const Color(0xFF6C5CE7);
      _cacheTheme(themeName); // Cache for instant loading on next open
      _isRecipientBlocked = settingsRes.data!.asBool('isBlocked', false);
    }

    // Load restriction status
    final restrictRes = await ApiService.getChatRestrictionStatus(_chatId!);
    if (restrictRes.isSuccess && restrictRes.data != null) {
      final restricted = restrictRes.data!.contains(widget.recipientId);
      if (restricted != _isRecipientRestricted && mounted) {
        setState(() => _isRecipientRestricted = restricted);
      }
    }

    // === OFFLINE-FIRST: Load local messages instantly ===
    // Graceful fail: if local storage fails, chat still works — just no cached messages
    try {
      final localMsgs = await LocalChatStorage.instance.getMessages(_chatId!, limit: _messagesLimit);
      if (localMsgs.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(localMsgs);
        });
        debugPrint('[Chat] Loaded ${localMsgs.length} messages from local storage');
      }
    } catch (e) {
      debugPrint('[Chat] Local storage load error (non-fatal): $e');
    }

    // Load pending messages from offline queue
    // Graceful fail: if queue read fails, pending messages won't show but chat still works
    List<QueuedMessage> pendingMsgs = [];
    try {
      pendingMsgs = OfflineMessageQueue.instance.getPendingForChat(_chatId!);
      if (pendingMsgs.isNotEmpty && mounted) {
        for (final qm in pendingMsgs) {
          final localId = qm.localId;
          if (!_messages.any((m) => m['_localId']?.toString() == localId || m['_id']?.toString() == localId)) {
            _messages.add(qm.toDisplayMessage(senderId: _myUserId));
          }
        }
        setState(() {});
        debugPrint('[Chat] Loaded ${pendingMsgs.length} pending messages from queue');
      }
    } catch (e) {
      debugPrint('[Chat] Queue load error (non-fatal): $e');
    }

    // Fetch from server (background refresh — updates local cache)
    final msgRes = await ApiService.getChatMessages(_chatId!, page: 1, limit: _messagesLimit);
    if (msgRes.isSuccess && msgRes.data != null) {
      final msgData = msgRes.data! as Map<String, dynamic>;
      final messages = (msgData.asList('messages'))
          .whereType<Map<String, dynamic>>()
          .toList();

      // Replace local messages with fresh server data (preserving pending)
      if (mounted && messages.isNotEmpty) {
        // Save to local storage for next offline load
        unawaited(LocalChatStorage.instance.saveMessages(_chatId!, messages));
        unawaited(LocalChatStorage.instance.setLastSync(_chatId!, DateTime.now()));

        // Merge: keep pending local messages, replace rest with server data
        final pendingLocalIds = _messages
            .where((m) => m['_localStatus'] != null && m['_localStatus'] != 'sent')
            .map((m) => m['_localId']?.toString() ?? m['_id']?.toString())
            .toSet();

        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          // Re-add pending messages that haven't been sent yet
          for (final qm in pendingMsgs) {
            if (pendingLocalIds.contains(qm.localId) && qm.status != MessageDeliveryStatus.sent) {
              if (!_messages.any((m) => m['_id']?.toString() == qm.serverId)) {
                _messages.add(qm.toDisplayMessage(senderId: _myUserId));
              }
            }
          }
        });
      }
      _hasMoreMessages = msgData.asBool('hasMore', false);
      _messagesPage = 2; // Next page to load

      // Count restricted messages (FB Messenger-style message requests)
      // If recipient is restricted, ALL their messages count as restricted
      if (mounted) {
        final rCount = _isRecipientRestricted
            ? _messages.where((m) => !_isMyMessage(m)).length
            : _messages.where((m) => m['isRestricted'] == true && !_isMyMessage(m)).length;
        if (rCount != _pendingRestrictedCount) {
          setState(() => _pendingRestrictedCount = rCount);
        }
      }
    }

    // === Listen for offline queue updates (message status changes) ===
    _queueUpdateSub = OfflineMessageQueue.instance.onQueueUpdate.listen((queuedMsg) {
      if (queuedMsg.chatId != _chatId || !mounted) return;

      setState(() {
        // Find message by _localId first, then by _id matching localId
        // (toDisplayMessage sets _id = localId initially until server confirms)
        final idx = _messages.indexWhere((m) {
          final mLocalId = m['_localId']?.toString();
          if (mLocalId != null && mLocalId == queuedMsg.localId) return true;
          // Fallback: _id might equal localId before server ID is assigned
          final mId = m['_id']?.toString();
          return mId == queuedMsg.localId;
        });

        if (idx != -1) {
          if (queuedMsg.status == MessageDeliveryStatus.sent && queuedMsg.serverId != null) {
            // Replace local message with server version
            _messages[idx] = {
              ..._messages[idx],
              '_id': queuedMsg.serverId,
              '_localId': queuedMsg.localId,
              '_localStatus': 'sent',
              'mediaUrl': queuedMsg.mediaUrl ?? _messages[idx]['mediaUrl'],
            };
          } else {
            // Update status
            _messages[idx]['_localStatus'] = queuedMsg.status.name;
            if (queuedMsg.errorMessage != null) {
              _messages[idx]['_errorMessage'] = queuedMsg.errorMessage;
            }
            // Update mediaUrl if upload completed
            if (queuedMsg.mediaUrl != null) {
              _messages[idx]['mediaUrl'] = queuedMsg.mediaUrl;
            }
          }
        }
      });
    });

    // === Listen for connectivity changes ===
    _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() => _isOffline = !isOnline);
      }
    });
    _isOffline = !ConnectivityService.instance.isOnline;

    // Join socket room (ensureConnected is called inside joinChat)
    final socket = SocketService.instance;
    socket.joinChat(_chatId!);

    // When socket reconnects while chat is open, fetch any missed messages
    _reconnectedSub = socket.onReconnected.listen((_) {
      if (!mounted || _chatId == null) return;
      debugPrint('[Chat] Socket reconnected — refreshing messages for $_chatId');
      _refreshMessagesFromServer();
    });

    // Listen for real-time messages
    _newMessageSub = socket.onNewMessage.listen((msg) {
      final msgChatId = msg['chat']?.toString() ?? '';
      if (msgChatId == _chatId || msg['chatId']?.toString() == _chatId) {
        if (mounted) {
          // Don't show messages from blocked users
          if (_isRecipientBlocked && !_isMyMessage(msg)) return;
          // Don't add restricted messages to list (FB Messenger-style: hidden until accepted)
          // Use _isRecipientRestricted as primary check — if recipient is restricted, ALL their messages are hidden
          if (!_isMyMessage(msg) && !_restrictedMessagesAccepted &&
              (_isRecipientRestricted || msg['isRestricted'] == true)) {
            // Just increment the pending count for the banner
            setState(() => _pendingRestrictedCount++);
            return;
          }
          final msgId = msg['_id']?.toString() ?? '';

          // Check if this is a server echo of a message we sent via offline queue
          final existingIdx = _messages.indexWhere((m) {
            // 1. Exact server ID match (normal dedup)
            if (msgId.isNotEmpty && m['_id']?.toString() == msgId) return true;
            // 2. Match pending local message: has _localId + status not yet confirmed
            final localStatus = m['_localStatus']?.toString();
            if (localStatus != null && localStatus != 'sent' && _isMyMessage(msg)) {
              // Match by content + type (most reliable for our own messages)
              final sameContent = m['content']?.toString() == msg['content']?.toString();
              final sameType = (m['type']?.toString() ?? 'text') == (msg['type']?.toString() ?? 'text');
              if (sameContent && sameType) return true;
            }
            return false;
          });

          if (existingIdx != -1) {
            // Replace local/pending message with confirmed server message
            final oldLocalId = _messages[existingIdx]['_localId'];
            setState(() {
              msg['_localStatus'] = 'sent'; // Mark as confirmed
              if (oldLocalId != null) msg['_localId'] = oldLocalId; // Preserve localId for queue tracking
              _messages[existingIdx] = msg;
            });
          } else {
            // Avoid duplicate messages (REST response + socket emit)
            if (msgId.isNotEmpty && _messages.any((m) => m['_id']?.toString() == msgId)) return;
            setState(() => _messages.add(msg));
          }
          _scrollToBottom();

          // Save to local storage
          unawaited(LocalChatStorage.instance.saveMessage(_chatId!, msg));

          // If message is from recipient, mark as read immediately since we're viewing the chat
          if (!_isMyMessage(msg) && _myUserId != null) {
            socket.emitMessagesRead(chatId: _chatId!, userId: _myUserId!);
          }
        }
      }
    });

    _typingSub = socket.onTyping.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      // Don't show typing for restricted users (FB Messenger-style)
      if (d.asStringOrNull('userId') == widget.recipientId && mounted && !_isRecipientRestricted) {
        _recipientTyping.value = true;
      }
    });

    _stopTypingSub = socket.onStopTyping.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      if (d.asStringOrNull('userId') == widget.recipientId && mounted) {
        _recipientTyping.value = false;
      }
    });

    _statusSub = socket.onUserStatus.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      if (d.asStringOrNull('userId') == widget.recipientId && mounted) {
        final wasOnline = _recipientOnline.value;
        _recipientOnline.value = d['isOnline'] == true;
        // Rebuild message list so tick marks update (sent → delivered)
        if (wasOnline != _recipientOnline.value) {
          setState(() {});
        }
      }
    });

    // Listen for read receipts from the recipient
    _messagesReadSub = socket.onMessagesRead.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      if (d.asStringOrNull('chatId') == _chatId && d.asStringOrNull('userId') == widget.recipientId && mounted) {
        setState(() {
          _allRead = true;
          // Update readBy on all messages
          for (final msg in _messages) {
            final readByRaw = msg['readBy'];
            final readBy = (readByRaw is List) ? readByRaw.map((e) => e.toString()).toList() : <String>[];
            if (!readBy.contains(widget.recipientId)) {
              readBy.add(widget.recipientId);
              msg['readBy'] = readBy;
            }
          }
        });
      }
    });

    _messageEditedSub = socket.onMessageEdited.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      if (d.asStringOrNull('chatId') == _chatId && mounted) {
        final msgId = d.asStringOrNull('messageId');
        final newContent = d.asString('content', '');
        if (msgId != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.asStringOrNull('_id') == msgId);
            if (idx != -1) {
              _messages[idx]['content'] = newContent;
              _messages[idx]['isEdited'] = true;
              _messages[idx]['editedAt'] = d['editedAt'];
            }
          });
        }
      }
    });

    _messageReactionSub = socket.onMessageReaction.listen((data) {
      // Safe cast — socket may send Map<Object?, Object?> instead of Map<String, dynamic>
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      debugPrint('[ReactionDebug] GOT message_reaction event: chatId=${d.asStringOrNull('chatId')}, msgId=${d.asStringOrNull('messageId')}, emoji=${d.asStringOrNull('emoji')}, userId=${d.asStringOrNull('userId')}, _chatId=$_chatId, _myUserId=$_myUserId, mounted=$mounted');
      if (d.asStringOrNull('chatId') == _chatId && mounted) {
        final msgId = d.asStringOrNull('messageId');
        if (msgId != null) {
          final idx = _messages.indexWhere((m) => m.asStringOrNull('_id') == msgId);
          debugPrint('[ReactionDebug] Message index=$idx for msgId=$msgId, totalMessages=${_messages.length}');
          if (idx != -1) {
            // Single reaction event from server broadcast
            final emoji = d.asStringOrNull('emoji');
            final userId = d.asStringOrNull('userId');
            final userName = d.asStringOrNull('userName');
            debugPrint('[ReactionDebug] emoji=$emoji, userId=$userId, _myUserId=$_myUserId, isOther=${userId != _myUserId}');
            // Accept reactions from ALL users (including self from server broadcast)
            // Self-reactions are already shown via optimistic update, but re-adding is harmless
            if (emoji != null && userId != null) {
              setState(() {
                final reactions = List<dynamic>.from(_messages[idx].asList('reactions'));
                final exists = reactions.any((r) => r is Map && r['emoji'] == emoji && r['userId'] == userId);
                debugPrint('[ReactionDebug] exists=$exists, currentReactionsCount=${reactions.length}');
                if (!exists) {
                  reactions.add({'emoji': emoji, 'userId': userId, 'userName': userName ?? ''});
                  _messages[idx]['reactions'] = reactions;
                  debugPrint('[ReactionDebug] ADDED reaction! New count=${reactions.length}');
                }
              });
            }
          }
        }
      }
    });

    // Listen for reaction removal from other user (real-time sync)
    _messageReactionRemovedSub = socket.onMessageReactionRemoved.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      if (d.asStringOrNull('chatId') == _chatId && mounted) {
        final msgId = d.asStringOrNull('messageId');
        final userId = d.asStringOrNull('userId');
        if (msgId != null && userId != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.asStringOrNull('_id') == msgId);
            if (idx != -1) {
              final reactions = List<dynamic>.from(_messages[idx].asList('reactions'));
              reactions.removeWhere((r) => r is Map && r['userId'] == userId);
              _messages[idx]['reactions'] = reactions;
            }
          });
        }
      }
    });

    // Listen for message unsend/delete from the other user (real-time sync)
    _messageDeletedSub = socket.onMessageDeleted.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final msgId = d.asStringOrNull('messageId');
      final chatId = d.asStringOrNull('chatId');
      if (chatId == _chatId && msgId != null && mounted) {
        debugPrint('[Chat] Message $msgId deleted/unsent by other user');
        setState(() {
          _messages.removeWhere((m) => m['_id']?.toString() == msgId);
        });
      }
    });

    // Listen for block/restrict actions from the other user
    _userBlockedSub = socket.onUserBlocked.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final chatId = d.asStringOrNull('chatId');
      final blockedBy = d.asStringOrNull('blockedBy');
      if (chatId == _chatId && blockedBy != _myUserId && mounted) {
        final isBlocked = d.asBool('isBlocked', false);
        debugPrint('[Chat] User ${isBlocked ? "blocked" : "unblocked"} us');
        setState(() => _isRecipientBlocked = isBlocked);
      }
    });

    _userRestrictedSub = socket.onUserRestricted.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final chatId = d.asStringOrNull('chatId');
      final restrictedBy = d.asStringOrNull('restrictedBy');
      if (chatId == _chatId && restrictedBy != _myUserId && mounted) {
        final isRestricted = d.asBool('isRestricted', false);
        debugPrint('[Chat] User ${isRestricted ? "restricted" : "unrestricted"} us');
        setState(() {
          _isRecipientRestricted = isRestricted;
          if (isRestricted) {
            // Reset acceptance — restricted user's msgs should be hidden again
            _restrictedMessagesAccepted = false;
            _pendingRestrictedCount = _messages.where((m) => !_isMyMessage(m)).length;
          } else {
            _pendingRestrictedCount = 0;
          }
        });
      }
    });

    // Listen for screenshot notifications from the other user
    _screenshotSub = socket.onScreenshotTaken.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      if (d.asStringOrNull('chatId') == _chatId && d.asStringOrNull('userId') != _myUserId && mounted) {
        final screenshotUser = d.asString('userName', 'Someone');
        // Show alert banner in chat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.screenshot_monitor_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('$screenshotUser took a screenshot of this chat')),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ),
        );
        // Add a system message to the chat locally
        setState(() {
          _messages.add({
            '_id': 'screenshot_${DateTime.now().millisecondsSinceEpoch}',
            'content': '\u{1F4F8} $screenshotUser took a screenshot',
            'type': 'system',
            'createdAt': DateTime.now().toIso8601String(),
            'isSystem': true,
          });
        });
        _scrollToBottom();
      }
    });

    // Emit that we've read this chat's messages
    if (_myUserId != null) {
      socket.emitMessagesRead(chatId: _chatId!, userId: _myUserId!);
    }

    // Check if recipient has already read our messages
    _checkReadStatus();

    // Initialize screenshot detection
    _initScreenshotDetection();

    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom(immediate: true);
    }
  }

  /// Screenshot detection - alerts the other user when a screenshot is taken
  void _initScreenshotDetection() {
    _screenshotCallback = ScreenshotCallback();
    _screenshotCallback?.addListener(() {
      if (_chatId == null || _myUserId == null || !mounted) return;
      // Emit screenshot event via socket
      final socket = SocketService.instance;
      final userName = context.read<AuthProvider>().user?.name ?? 'Someone';
      socket.emitScreenshotTaken(
        chatId: _chatId!,
        userId: _myUserId!,
        userName: userName,
        recipientId: widget.recipientId,
      );
      // Show local confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Screenshot captured - ${widget.recipientName} was notified')),
            ],
          ),
          backgroundColor: _chatThemeColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    });
  }

  void _scrollToBottom({bool immediate = false}) {
    if (immediate) {
      // Jump instantly without waiting — used for initial load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        // Second pass: catch images/media that finished layout after first frame
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
        // Third pass: catch slow-loading cached network images
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted || !_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          if ((_scrollController.offset - max).abs() > 50) {
            _scrollController.jumpTo(max);
          }
        });
      });
    } else {
      // Smooth scroll for new messages during conversation
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Scroll listener — loads older messages when user scrolls near the top
  void _onScrollForPagination() {
    if (!_scrollController.hasClients) return;
    // Trigger load when within 150px of the top
    if (_scrollController.position.pixels <= 150 &&
        _hasMoreMessages &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMoreMessages();
    }
  }

  /// Refresh messages from server (called on socket reconnect to catch missed msgs)
  Future<void> _refreshMessagesFromServer() async {
    if (_chatId == null || !mounted) return;
    try {
      final msgRes = await ApiService.getChatMessages(_chatId!, page: 1, limit: _messagesLimit);
      if (msgRes.isSuccess && msgRes.data != null && mounted) {
        final msgData = msgRes.data! as Map<String, dynamic>;
        final messages = (msgData.asList('messages'))
            .whereType<Map<String, dynamic>>()
            .toList();
        if (messages.isNotEmpty) {
          // Merge new messages — add any that aren't already in the list
          int added = 0;
          for (final msg in messages) {
            final msgId = msg['_id']?.toString() ?? '';
            if (msgId.isNotEmpty && !_messages.any((m) => m['_id']?.toString() == msgId)) {
              _messages.add(msg);
              added++;
            }
          }
          if (added > 0) {
            debugPrint('[Chat] Reconnect refresh added $added new messages');
            setState(() {});
            _scrollToBottom();
            unawaited(LocalChatStorage.instance.saveMessages(_chatId!, messages));
          }
        }
      }
    } catch (e) {
      debugPrint('[Chat] Reconnect refresh error: $e');
    }
  }

  /// Load next page of older messages
  Future<void> _loadMoreMessages() async {
    if (_chatId == null || _isLoadingMore || !_hasMoreMessages) return;
    setState(() => _isLoadingMore = true);

    final msgRes = await ApiService.getChatMessages(
      _chatId!,
      page: _messagesPage,
      limit: _messagesLimit,
    );

    if (msgRes.isSuccess && msgRes.data != null && mounted) {
      final msgDataOlder = msgRes.data! as Map<String, dynamic>;
      final rawOlder = msgDataOlder.asList('messages')
          .whereType<Map<String, dynamic>>()
          .toList();

      // Deduplicate — page-based pagination can overlap when new messages arrive
      final existingIds = _messages.map((m) => m.asStringOrNull('_id')).toSet();
      final olderMessages = rawOlder
          .where((m) => !existingIds.contains(m.asStringOrNull('_id')))
          .toList();

      if (olderMessages.isNotEmpty) {
        // Preserve scroll position: remember extents before inserting
        final oldMaxExtent = _scrollController.position.maxScrollExtent;
        final scrollOffset = _scrollController.offset;
        // Update restricted message count with newly loaded older messages
        final newRestricted = olderMessages.where((m) =>
          m['isRestricted'] == true && !_isMyMessage(m)
        ).length;
        setState(() {
          _messages.insertAll(0, olderMessages);
          _hasMoreMessages = (msgRes.data! as Map<String, dynamic>).asBool('hasMore', false);
          _messagesPage++;
          if (newRestricted > 0) _pendingRestrictedCount += newRestricted;
        });
        // Restore scroll position: shift by the height the new items added
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMaxExtent = _scrollController.position.maxScrollExtent;
            final addedHeight = newMaxExtent - oldMaxExtent;
            _scrollController.jumpTo(scrollOffset + addedHeight);
          }
        });
      } else {
        _hasMoreMessages = false;
      }
    }

    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _onTypingChanged(String text) {
    if (_chatId == null || _myUserId == null) return;
    final socket = SocketService.instance;

    if (text.isNotEmpty) {
      socket.startTyping(
        chatId: _chatId!,
        userId: _myUserId!,
        userName: context.read<AuthProvider>().user?.name ?? '',
      );
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        socket.stopTyping(chatId: _chatId!, userId: _myUserId!);
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_isRecipientBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unblock this user to send messages'),
          backgroundColor: NearfoColors.danger,
        ),
      );
      return;
    }
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null || _isSending.value) return;

    _messageController.clear();
    final replyData = _replyingToMessage;
    _isSending.value = true;
    setState(() {
      _replyingToMessage = null; // Clear reply state immediately
    });

    // Stop typing
    if (_myUserId != null) {
      SocketService.instance.stopTyping(chatId: _chatId!, userId: _myUserId!);
    }

    // Build replyTo payload if replying
    Map<String, dynamic>? replyTo;
    if (replyData != null) {
      final senderData = replyData['sender'];
      final msgId = replyData['_id']?.toString() ?? '';
      // Only build replyTo if we have a valid messageId
      if (msgId.isNotEmpty) {
        final senderId = senderData is Map
            ? (senderData['_id']?.toString() ?? '')
            : (senderData?.toString() ?? '');
        replyTo = {
          'messageId': msgId,
          'content': replyData['content']?.toString() ?? '',
          'senderName': senderData is Map ? (senderData['name']?.toString() ?? '') : '',
          if (senderId.isNotEmpty) 'senderId': senderId,
        };
      }
    }

    // Read auth user BEFORE await (context.read is unsafe after async gap)
    final authUser = context.read<AuthProvider>().user;

    // === OFFLINE-FIRST: Enqueue message → show instantly → send in background ===
    final queuedMsg = await OfflineMessageQueue.instance.enqueue(
      chatId: _chatId!,
      content: text,
      replyTo: replyTo,
    );

    // Show message immediately in chat (optimistic UI)
    final displayMsg = queuedMsg.toDisplayMessage(
      senderId: _myUserId,
      senderData: authUser != null ? {
        '_id': authUser.id,
        'name': authUser.name,
        'handle': authUser.handle,
        'avatarUrl': authUser.avatarUrl,
      } : null,
    );

    if (mounted) {
      _isSending.value = false;
      setState(() {
        _messages.add(displayMsg);
      });
      _scrollToBottom();

      // Save to local storage
      unawaited(LocalChatStorage.instance.saveMessage(_chatId!, displayMsg));
    }
  }

  void _checkReadStatus() {
    // Check if any of our sent messages have been read by recipient
    for (final msg in _messages) {
      if (_isMyMessage(msg)) {
        final readBy = (msg['readBy'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        if (readBy.contains(widget.recipientId)) {
          _allRead = true;
          break;
        }
      }
    }
  }

  String _getMessageStatus(Map<String, dynamic> msg) {
    // Check offline-first local status first
    final localStatus = msg['_localStatus']?.toString();
    if (localStatus != null) {
      switch (localStatus) {
        case 'pending':
        case 'uploading':
        case 'sending':
          return 'pending';
        case 'failed':
          return 'failed';
        // 'sent' falls through to normal logic below
      }
    }

    final readByRaw = msg.asList('readBy');
    final readBy = readByRaw.map((e) => e.toString()).toList();
    if (readBy.contains(widget.recipientId)) {
      return 'read';
    }
    // If the message has been received by server (has _id), it's at least sent
    // If recipient is online, consider it delivered
    if (_recipientOnline.value) {
      return 'delivered';
    }
    return 'sent';
  }

  bool _isMyMessage(Map<String, dynamic> msg) {
    final sender = msg['sender'];
    if (sender is Map) return sender['_id'] == _myUserId;
    return sender.toString() == _myUserId;
  }

  String _getSenderInitial(Map<String, dynamic> msg) {
    final sender = msg['sender'];
    if (sender is Map) {
      final name = sender['name']?.toString() ?? '';
      return name.isNotEmpty ? name[0].toUpperCase() : '?';
    }
    return '?';
  }

  void _startCall({required bool isVideo}) {
    if (_isRecipientBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unblock this user to make calls'),
          backgroundColor: NearfoColors.danger,
        ),
      );
      return;
    }

    final myUser = context.read<AuthProvider>().user;
    if (myUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          recipientId: widget.recipientId,
          recipientName: widget.recipientName,
          recipientAvatar: widget.recipientAvatar,
          callerId: myUser.id,
          callerName: myUser.name,
          isVideo: isVideo,
          isIncoming: false,
        ),
      ),
    );
  }

  /// Start editing a message — populate input bar with existing content
  void _startEditingMessage(Map<String, dynamic> msg) {
    setState(() {
      _editingMessage = msg;
      _replyingToMessage = null; // Cancel any reply
      _messageController.text = msg['content']?.toString() ?? '';
    });
    _messageFocusNode.requestFocus();
    // Move cursor to end
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  /// Cancel editing
  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  /// Submit edited message
  Future<void> _submitEditedMessage() async {
    if (_editingMessage == null || _chatId == null) return;
    final newContent = _messageController.text.trim();
    final msgId = _editingMessage!['_id']?.toString() ?? '';
    final oldContent = _editingMessage!['content']?.toString() ?? '';

    if (newContent.isEmpty || newContent == oldContent || msgId.isEmpty) {
      _cancelEditing();
      return;
    }

    _isSending.value = true;

    // Optimistic UI update — show edit instantly
    final idx = _messages.indexWhere((m) => m['_id']?.toString() == msgId);
    if (idx != -1) {
      setState(() {
        _messages[idx]['content'] = newContent;
        _messages[idx]['isEdited'] = true;
        _messages[idx]['editedAt'] = DateTime.now().toIso8601String();
      });
    }
    _cancelEditing();

    final res = await ApiService.editMessage(
      chatId: _chatId!,
      messageId: msgId,
      content: newContent,
    );

    if (mounted) {
      _isSending.value = false;
      if (res.isSuccess) {
        // Re-lookup by ID to avoid stale index after async gap
        final freshIdx = _messages.indexWhere((m) => m['_id']?.toString() == msgId);
        if (freshIdx != -1 && res.data?.asStringOrNull('editedAt') != null) {
          _messages[freshIdx]['editedAt'] = res.data!.asStringOrNull('editedAt');
        }
        // Emit socket event so receiver sees the edit in real-time
        SocketService.instance.emit('message_edited', {
          'chatId': _chatId,
          'messageId': msgId,
          'content': newContent,
        });
      } else {
        // Revert optimistic update on failure — re-lookup index by ID
        final revertIdx = _messages.indexWhere((m) => m['_id']?.toString() == msgId);
        if (revertIdx != -1) {
          setState(() {
            _messages[revertIdx]['content'] = oldContent;
            _messages[revertIdx]['isEdited'] = oldContent != newContent ? _messages[revertIdx]['isEdited'] : false;
            _messages[revertIdx].remove('editedAt');
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Failed to edit message'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Toggle own online status visibility (ghost mode) from chat screen
  Future<void> _toggleMyOnlineStatus() async {
    final newStatus = !_showOnlineStatus;
    final auth = context.read<AuthProvider>();

    // Optimistic UI update
    setState(() => _showOnlineStatus = newStatus);

    // Save to profile via API
    final success = await auth.updateProfile({'showOnlineStatus': newStatus});

    if (success && mounted) {
      // Tell socket server immediately
      SocketService.instance.toggleOnlineVisibility(
        userId: _myUserId ?? '',
        visible: newStatus,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newStatus ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: Colors.white, size: 18,
              ),
              const SizedBox(width: 8),
              Text(newStatus ? 'You\'re visible now' : 'You\'re invisible now'),
            ],
          ),
          backgroundColor: newStatus ? NearfoColors.success : NearfoColors.textDim,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    } else if (mounted) {
      // Revert on failure
      setState(() => _showOnlineStatus = !newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update online status'),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  void _openChatSettings() async {
    if (_chatId == null) return;

    // For group chats, open GroupInfoScreen
    if (widget.isGroup) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => GroupInfoScreen(
            chatId: _chatId!,
            groupName: widget.recipientName,
          ),
        ),
      );
      if (result != null && mounted) {
        // Handle group name changes etc.
        if (result.containsKey('left') && result['left'] == true) {
          Navigator.pop(context);
        }
      }
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSettingsScreen(
          chatId: _chatId!,
          recipientId: widget.recipientId,
          recipientName: widget.recipientName,
          recipientHandle: widget.recipientHandle,
          recipientAvatar: widget.recipientAvatar,
          isOnline: _recipientOnline.value,
          isRestricted: _isRecipientRestricted,
        ),
      ),
    );
    if (result != null && mounted) {
      final newRestricted = (result as Map<String, dynamic>).asBool('isRestricted', _isRecipientRestricted);
      final restrictionChanged = newRestricted != _isRecipientRestricted;
      setState(() {
        _isRecipientRestricted = newRestricted;
        _isRecipientBlocked = (result as Map<String, dynamic>).asBool('isBlocked', _isRecipientBlocked);
        // Apply theme color from settings
        final themeName = (result as Map<String, dynamic>).asString('theme', 'Default');
        _chatThemeColor = _themeColors[themeName] ?? const Color(0xFF6C5CE7);
        _cacheTheme(themeName); // Cache locally for instant loading
        // If restriction changed, recount pending restricted messages immediately
        if (restrictionChanged) {
          _pendingRestrictedCount = _isRecipientRestricted
              ? _messages.where((m) => !_isMyMessage(m)).length
              : 0;
          _restrictedMessagesAccepted = false; // Reset acceptance on restriction change
        }
      });
    }
    // Sync global online status (might have been changed in chat settings)
    if (mounted) {
      final updatedUser = context.read<AuthProvider>().user;
      if (updatedUser != null && _showOnlineStatus != updatedUser.showOnlineStatus) {
        setState(() => _showOnlineStatus = updatedUser.showOnlineStatus);
      }
    }
    // Always reload settings from API (handles system back button case)
    if (mounted && _chatId != null) {
      final settingsRes = await ApiService.getChatSettings(_chatId!);
      if (settingsRes.isSuccess && settingsRes.data != null && mounted) {
        final themeName = settingsRes.data!.asString('theme', 'Default');
        setState(() {
          _chatThemeColor = _themeColors[themeName] ?? const Color(0xFF6C5CE7);
        });
        _cacheTheme(themeName); // Cache locally for instant loading
      }
    }
  }

  void _showMessageActions(Map<String, dynamic> msg) {
    final isMe = _isMyMessage(msg);
    final msgId = msg['_id']?.toString() ?? '';
    final content = msg['content']?.toString() ?? '';
    final msgType = msg['type']?.toString() ?? 'text';
    final mediaUrl = msg['mediaUrl']?.toString();
    final hasMedia = (msgType == 'image' || msgType == 'video' || msgType == 'voice') && mediaUrl != null && mediaUrl.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Copy (for text messages)
              if (content.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.copy, color: NearfoColors.text),
                  title: Text(context.l10n.chatCopy, style: TextStyle(color: NearfoColors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.chatMessageCopied), backgroundColor: NearfoColors.primary),
                    );
                  },
                ),
              // Download (for image/video messages)
              if (hasMedia)
                ListTile(
                  leading: Icon(Icons.download, color: NearfoColors.success),
                  title: Text(context.l10n.chatDownloadMedia(type: msgType == 'image' ? 'Image' : msgType == 'video' ? 'Video' : 'Voice'), style: TextStyle(color: NearfoColors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Resolve relative URL to absolute before downloading
                    final resolvedUrl = NearfoConfig.resolveMediaUrl(mediaUrl!);
                    _downloadMedia(resolvedUrl, msgType);
                  },
                ),
              // Reply
              ListTile(
                leading: Icon(Icons.reply, color: NearfoColors.primary),
                title: Text(context.l10n.chatReply, style: TextStyle(color: NearfoColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingToMessage = msg);
                  _messageFocusNode.requestFocus();
                },
              ),
              // Forward
              ListTile(
                leading: Icon(Icons.shortcut, color: NearfoColors.primaryLight),
                title: Text(context.l10n.chatForward, style: TextStyle(color: NearfoColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showForwardPicker(msg);
                },
              ),
              // React
              ListTile(
                leading: Icon(Icons.favorite_border, color: NearfoColors.accent),
                title: Text(context.l10n.chatReact, style: TextStyle(color: NearfoColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Delay to let the first bottom sheet finish closing animation
                  // before opening the emoji picker sheet (prevents race condition)
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _addReactionFromMenu(msg);
                  });
                },
              ),
              if (isMe && msgType == 'text' && content.isNotEmpty) ...[
                // Edit message (only text, within 15 minutes)
                Builder(builder: (context) {
                  final createdAt = msg['createdAt'];
                  DateTime? msgTime;
                  if (createdAt is String) msgTime = DateTime.tryParse(createdAt);
                  final withinWindow = msgTime != null &&
                      DateTime.now().difference(msgTime).inMinutes < 15;
                  if (!withinWindow) return const SizedBox.shrink();
                  return ListTile(
                    leading: Icon(Icons.edit_rounded, color: NearfoColors.primary),
                    title: Text(context.l10n.chatEditMessageOption, style: TextStyle(color: NearfoColors.text)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startEditingMessage(msg);
                    },
                  );
                }),
              ],
              if (isMe) ...[
                // Unsend / Undo
                ListTile(
                  leading: Icon(Icons.undo, color: NearfoColors.warning),
                  title: Text(context.l10n.chatUnsendMessage, style: TextStyle(color: NearfoColors.warning)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: NearfoColors.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(context.l10n.chatUnsendConfirm, style: TextStyle(fontWeight: FontWeight.w700, color: NearfoColors.text)),
                        content: Text(
                          context.l10n.chatUnsendWarning,
                          style: TextStyle(color: NearfoColors.textMuted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: Text(context.l10n.chatCancel, style: TextStyle(color: NearfoColors.textMuted)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: Text(context.l10n.chatUnsend, style: TextStyle(color: NearfoColors.warning, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && msgId.isNotEmpty) {
                      // Optimistic UI update — remove message instantly
                      final removedIdx = _messages.indexWhere((m) => m['_id']?.toString() == msgId);
                      Map<String, dynamic>? removedMsg;
                      if (removedIdx != -1) {
                        removedMsg = Map<String, dynamic>.from(_messages[removedIdx]);
                        setState(() => _messages.removeAt(removedIdx));
                      }

                      final res = await ApiService.unsendMessage(chatId: _chatId!, messageId: msgId);
                      if (res.isSuccess && mounted) {
                        // Emit socket event so the receiver's chat updates in real-time
                        SocketService.instance.emit('message_deleted', {
                          'chatId': _chatId,
                          'messageId': msgId,
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.chatMessageUnsent), backgroundColor: NearfoColors.success),
                        );
                      } else if (mounted && removedMsg != null) {
                        // Revert optimistic update on failure — use safe index (list may have changed during async)
                        setState(() {
                          final safeIdx = removedIdx.clamp(0, _messages.length);
                          _messages.insert(safeIdx, removedMsg!);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.errorMessage ?? context.l10n.chatUnsendFailed),
                            backgroundColor: NearfoColors.danger,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
              // Delete for me
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(context.l10n.chatDeleteForMe, style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (msgId.isNotEmpty) {
                    final res = await ApiService.deleteMessage(chatId: _chatId!, messageId: msgId);
                    if (res.isSuccess && mounted) {
                      setState(() => _messages.removeWhere((m) => m['_id']?.toString() == msgId));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show emoji reaction picker from menu (opens bottom sheet)
  void _addReactionFromMenu(Map<String, dynamic> msg) {
    final reactionEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: reactionEmojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _addReaction(msg, emoji);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 40)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Show chat picker to forward a message
  Future<void> _showForwardPicker(Map<String, dynamic> msg) async {
    final chatsRes = await ApiService.getChats(limit: 50);
    if (!chatsRes.isSuccess || chatsRes.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to load chats'), backgroundColor: NearfoColors.danger),
        );
      }
      return;
    }

    final chats = chatsRes.data!;
    if (!mounted) return;

    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredChats = List<Map<String, dynamic>>.from(chats);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: NearfoColors.textDim,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.l10n.chatForwardTo, style: TextStyle(
                        color: NearfoColors.text, fontSize: 18, fontWeight: FontWeight.w700,
                      )),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        style: TextStyle(color: NearfoColors.text),
                        decoration: InputDecoration(
                          hintText: context.l10n.chatSearchChats,
                          hintStyle: TextStyle(color: NearfoColors.textDim),
                          prefixIcon: Icon(Icons.search, color: NearfoColors.textDim),
                          filled: true,
                          fillColor: NearfoColors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (query) {
                          setSheetState(() {
                            if (query.isEmpty) {
                              filteredChats = List<Map<String, dynamic>>.from(chats);
                            } else {
                              filteredChats = chats.where((chat) {
                                final participants = (chat as Map<String, dynamic>).asList('participants');
                                for (final p in participants) {
                                  if (p is Map) {
                                    final name = (p as Map<String, dynamic>).asString('name', '').toLowerCase();
                                    final handle = (p as Map<String, dynamic>).asString('handle', '').toLowerCase();
                                    if (name.contains(query.toLowerCase()) || handle.contains(query.toLowerCase())) {
                                      return true;
                                    }
                                  }
                                }
                                final groupName = (chat as Map<String, dynamic>).asString('groupName', '').toLowerCase();
                                return groupName.contains(query.toLowerCase());
                              }).toList();
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 8),
                    // Chat list
                    Expanded(
                      child: filteredChats.isEmpty
                          ? Center(child: Text(context.l10n.chatNoChatFound, style: TextStyle(color: NearfoColors.textDim)))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filteredChats.length,
                              itemBuilder: (context, index) {
                                final chat = filteredChats[index];
                                final chatId = chat.asString('_id', '');
                                final isGroup = chat['isGroup'] == true;
                                final participants = chat.asList('participants');

                                // Find the other participant for 1:1 chats
                                String displayName = '';
                                String? avatarUrl;
                                if (isGroup) {
                                  displayName = chat.asString('groupName', 'Group');
                                  avatarUrl = chat.asStringOrNull('groupAvatar');
                                } else {
                                  for (final p in participants) {
                                    if (p is Map && (p as Map<String, dynamic>).asStringOrNull('_id') != _myUserId) {
                                      displayName = (p as Map<String, dynamic>).asString('name', '');
                                      avatarUrl = (p as Map<String, dynamic>).asStringOrNull('avatarUrl');
                                      break;
                                    }
                                  }
                                  if (displayName.isEmpty && participants.isNotEmpty) {
                                    final p = participants.first;
                                    displayName = p is Map ? (p['name']?.toString() ?? 'Chat') : 'Chat';
                                  }
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: NearfoColors.primary,
                                    child: avatarUrl != null
                                        ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(avatarUrl), fit: BoxFit.cover, width: 44, height: 44,
                                            errorWidget: (_, __, ___) => Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
                                        : Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(displayName, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w600)),
                                  subtitle: isGroup
                                      ? Text('Group', style: TextStyle(color: NearfoColors.textDim, fontSize: 12))
                                      : null,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _forwardMessage(msg, chatId, displayName);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((_) => searchController.dispose());
  }

  /// Forward a message to the selected chat
  Future<void> _forwardMessage(Map<String, dynamic> msg, String targetChatId, String targetName) async {
    final msgType = msg['type']?.toString() ?? 'text';
    final content = msg['content']?.toString() ?? '';
    final mediaUrl = msg['mediaUrl']?.toString();

    // Forward as a new message to the target chat
    final res = await ApiService.sendMessage(
      chatId: targetChatId,
      content: content.isNotEmpty ? content : (msgType == 'image' ? context.l10n.chatForwardedImage : msgType == 'video' ? context.l10n.chatForwardedVideo : msgType == 'voice' ? context.l10n.chatForwardedVoice : ''),
      type: msgType,
      mediaUrl: mediaUrl,
    );

    if (mounted) {
      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatForwardedTo(name: targetName)),
            backgroundColor: NearfoColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? context.l10n.chatForwardFailed),
            backgroundColor: NearfoColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleRestriction() async {
    if (_chatId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _isRecipientRestricted ? 'Unrestrict User?' : 'Restrict User?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _isRecipientRestricted
              ? 'You will see their messages normally again. They\'ll be able to see when you\'re online.'
              : 'Their new messages will go to message requests. They won\'t see when you\'re online or if you\'ve read their messages. They won\'t know they\'re restricted.',
          style: TextStyle(color: NearfoColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _isRecipientRestricted ? 'Unrestrict' : 'Restrict',
              style: TextStyle(
                color: _isRecipientRestricted ? NearfoColors.success : NearfoColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistic UI update — toggle restriction instantly
    final wasRestricted = _isRecipientRestricted;
    setState(() {
      _isRecipientRestricted = !_isRecipientRestricted;
      // Immediately update restricted message count and hide/show messages
      if (_isRecipientRestricted) {
        _pendingRestrictedCount = _messages.where((m) => !_isMyMessage(m)).length;
        _restrictedMessagesAccepted = false;
      } else {
        _pendingRestrictedCount = 0;
      }
    });

    final res = await ApiService.toggleChatRestriction(
      chatId: _chatId!,
      userId: widget.recipientId,
    );

    if (res.isSuccess && res.data != null) {
      final newRestricted = res.data!.asBool('isRestricted', false);
      if (newRestricted != _isRecipientRestricted && mounted) {
        setState(() => _isRecipientRestricted = newRestricted);
      }
      // Emit socket event so receiver's chat screen updates in real-time
      SocketService.instance.emit('user_restricted', {
        'chatId': _chatId,
        'restrictedBy': _myUserId,
        'targetUserId': widget.recipientId,
        'isRestricted': _isRecipientRestricted,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isRecipientRestricted ? 'User restricted' : 'User unrestricted'),
            backgroundColor: _isRecipientRestricted ? NearfoColors.warning : NearfoColors.success,
          ),
        );
      }
    } else if (mounted) {
      // Revert optimistic update on failure
      setState(() => _isRecipientRestricted = wasRestricted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Failed to update restriction'),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  /// Accept restricted messages (message request) — marks them as normal messages
  Future<void> _handleAcceptRestricted() async {
    if (_chatId == null) return;
    setState(() {
      _restrictedMessagesAccepted = true;
      // Un-hide restricted messages in local list
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i]['isRestricted'] == true) {
          _messages[i]['isRestricted'] = false;
        }
      }
      _pendingRestrictedCount = 0;
    });
    // Sync with server
    await ApiService.acceptRestrictedMessages(_chatId!);
  }

  /// Delete restricted messages (decline message request)
  Future<void> _handleDeleteRestricted() async {
    if (_chatId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete message requests?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete all pending messages from this restricted user.',
          style: TextStyle(color: NearfoColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: NearfoColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _messages.removeWhere((m) => m['isRestricted'] == true && !_isMyMessage(m));
      _pendingRestrictedCount = 0;
    });
    // Sync with server
    await ApiService.deleteRestrictedMessages(_chatId!);
  }

  @override
  void dispose() {
    // Leave the socket room to stop receiving messages for this chat
    if (_chatId != null) {
      SocketService.instance.leaveChat(_chatId!);
    }
    // Clean up any in-progress voice recording temp file
    if (_isRecording.value && _recordingPath != null) {
      try {
        final f = File(_recordingPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    _newMessageSub?.cancel();
    _typingSub?.cancel();
    _stopTypingSub?.cancel();
    _statusSub?.cancel();
    _messagesReadSub?.cancel();
    _messageEditedSub?.cancel();
    _messageReactionSub?.cancel();
    _messageReactionRemovedSub?.cancel();
    _messageDeletedSub?.cancel();
    _screenshotSub?.cancel();
    _userBlockedSub?.cancel();
    _userRestrictedSub?.cancel();
    _queueUpdateSub?.cancel();
    _reconnectedSub?.cancel();
    _connectivitySub?.cancel();
    _screenshotCallback?.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _recorderController?.dispose();
    _messageController.dispose();
    _scrollController.removeListener(_onScrollForPagination);
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _isSending.dispose();
    _recipientOnline.dispose();
    _recipientTyping.dispose();
    _isRecording.dispose();
    _showEmojiPicker.dispose();
    _showGifPicker.dispose();
    _recordingSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.card,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: _chatThemeColor),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _openChatSettings,
          child: Row(
            children: [
              // Premium avatar with gradient ring
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: (!widget.isGroup && _recipientOnline.value) ? LinearGradient(
                    colors: [NearfoColors.success, NearfoColors.success.withOpacity(0.6)],
                  ) : null,
                  border: (widget.isGroup || !_recipientOnline.value) ? Border.all(color: NearfoColors.border, width: 2) : null,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: NearfoColors.bg,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: widget.isGroup ? NearfoColors.accent : _chatThemeColor.withOpacity(0.2),
                    child: widget.isGroup
                        ? const Icon(Icons.group, color: Colors.white, size: 18)
                        : widget.recipientAvatar != null
                        ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(widget.recipientAvatar!), fit: BoxFit.cover, width: 32, height: 32,
                            errorWidget: (_, __, ___) => Text(
                              widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _chatThemeColor, fontSize: 14),
                            )))
                        : Text(
                            widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _chatThemeColor, fontSize: 14),
                          ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.recipientName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: NearfoColors.text)),
                    if (widget.isGroup)
                      Text(
                        'Tap for group info',
                        style: TextStyle(fontSize: 12, color: NearfoColors.textDim),
                      )
                    else
                    ValueListenableBuilder<bool>(
                      valueListenable: _recipientTyping,
                      builder: (context, typing, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _recipientOnline,
                          builder: (context, online, _) {
                            // Hide online/typing from restricted users (FB Messenger-style)
                            final showTyping = typing && !_isRecipientRestricted;
                            final showOnline = online && !_isRecipientRestricted;
                            return Row(
                              children: [
                                if (showTyping || showOnline)
                                  Container(
                                    width: 7, height: 7,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(
                                      color: showTyping ? _chatThemeColor : NearfoColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    showTyping
                                        ? 'typing...'
                                        : showOnline
                                            ? context.l10n.chatActiveNow
                                            : widget.lastSeenText.isNotEmpty
                                                ? widget.lastSeenText
                                                : 'Offline',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: typing ? FontWeight.w600 : FontWeight.w400,
                                      color: typing ? _chatThemeColor : online ? NearfoColors.success : NearfoColors.textDim,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Call buttons — only for 1:1 chats
          if (!widget.isGroup) ...[
          IconButton(
            onPressed: () => _startCall(isVideo: false),
            icon: Icon(Icons.call_rounded, color: _chatThemeColor, size: 22),
          ),
          IconButton(
            onPressed: () => _startCall(isVideo: true),
            icon: Icon(Icons.videocam_rounded, color: _chatThemeColor, size: 24),
          ),
          ],
          // More options menu (online status toggle, etc.)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: _chatThemeColor, size: 22),
            color: NearfoColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'toggle_online') {
                _toggleMyOnlineStatus();
              } else if (value == 'toggle_restrict') {
                _toggleRestriction();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'toggle_online',
                child: Row(
                  children: [
                    Icon(
                      _showOnlineStatus ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: _showOnlineStatus ? NearfoColors.success : NearfoColors.textDim,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showOnlineStatus ? 'Go Invisible' : 'Go Online',
                            style: TextStyle(color: NearfoColors.text, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _showOnlineStatus ? 'Hide your online status' : 'Show your online status',
                            style: TextStyle(color: NearfoColors.textDim, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _showOnlineStatus ? NearfoColors.success : NearfoColors.textDim,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'toggle_restrict',
                child: Row(
                  children: [
                    Icon(
                      _isRecipientRestricted ? Icons.lock_open_rounded : Icons.block_rounded,
                      color: _isRecipientRestricted ? NearfoColors.success : NearfoColors.warning,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRecipientRestricted ? 'Unrestrict' : 'Restrict',
                            style: TextStyle(color: NearfoColors.text, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _isRecipientRestricted ? 'See their messages normally' : 'Move messages to requests',
                            style: TextStyle(color: NearfoColors.textDim, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Encryption banner (sleek Messenger-style)
          if (_isEncrypted && !_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_chatThemeColor.withOpacity(0.06), _chatThemeColor.withOpacity(0.02)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: _chatThemeColor.withOpacity(0.6)),
                  const SizedBox(width: 5),
                  Text(
                    'Encrypted',
                    style: TextStyle(
                      color: _chatThemeColor.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          // Offline banner
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: NearfoColors.warning.withOpacity(0.15),
                border: Border(bottom: BorderSide(color: NearfoColors.warning.withOpacity(0.3), width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 14, color: NearfoColors.warning),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'You\'re offline. Messages will send when back online.',
                      style: TextStyle(
                        color: NearfoColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Restricted messages banner (FB Messenger-style message request)
          if (_pendingRestrictedCount > 0 && !_restrictedMessagesAccepted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: NearfoColors.warning.withOpacity(0.1),
                border: Border(bottom: BorderSide(color: NearfoColors.warning.withOpacity(0.3), width: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.mark_email_unread_rounded, size: 18, color: NearfoColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_pendingRestrictedCount message request${_pendingRestrictedCount > 1 ? 's' : ''} from this user',
                      style: TextStyle(color: NearfoColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleDeleteRestricted,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: NearfoColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Delete', style: TextStyle(color: NearfoColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _handleAcceptRestricted,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: NearfoColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Accept', style: TextStyle(color: NearfoColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          // Messages
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Premium avatar display
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [_chatThemeColor, _chatThemeColor.withOpacity(0.5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: NearfoColors.card,
                                child: CircleAvatar(
                                  radius: 37,
                                  backgroundColor: _chatThemeColor.withOpacity(0.1),
                                  child: widget.recipientAvatar != null
                                      ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(widget.recipientAvatar!), fit: BoxFit.cover, width: 74, height: 74,
                                          errorWidget: (_, __, ___) => Text(
                                            widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: _chatThemeColor, fontSize: 32),
                                          )))
                                      : Text(
                                          widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: _chatThemeColor, fontSize: 32),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(widget.recipientName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: NearfoColors.text)),
                            if (widget.recipientHandle != null) ...[
                              const SizedBox(height: 4),
                              Text('@${widget.recipientHandle}', style: TextStyle(color: NearfoColors.textDim, fontSize: 14)),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _chatThemeColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Say hi! Start a conversation', style: TextStyle(color: _chatThemeColor, fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show loading spinner at the top while fetching older messages
                          if (_isLoadingMore && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _chatThemeColor),
                                ),
                              ),
                            );
                          }
                          final msgIndex = _isLoadingMore ? index - 1 : index;
                          final msg = _messages[msgIndex];

                          // Hide messages from restricted user until accepted (FB Messenger-style)
                          // Use _isRecipientRestricted as primary check — covers ALL messages from restricted user
                          // regardless of whether the individual message has isRestricted flag set
                          if (!_isMyMessage(msg) && !_restrictedMessagesAccepted &&
                              (_isRecipientRestricted || msg['isRestricted'] == true)) {
                            return const SizedBox.shrink();
                          }

                          final isMe = _isMyMessage(msg);
                          final timestamp = (DateTime.tryParse(msg.asString('createdAt', '')) ?? DateTime.now()).toLocal();

                          final prevTimestamp = msgIndex == 0
                              ? null
                              : (DateTime.tryParse(_messages[msgIndex - 1].asString('createdAt', '')))?.toLocal();
                          final showDate = msgIndex == 0 || (prevTimestamp?.day ?? 0) != timestamp.day;

                          // System messages (screenshot notifications, etc.)
                          if (msg['isSystem'] == true || msg['type'] == 'system') {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.5),
                                  ),
                                  child: Text(
                                    (msg['content'] as String?) ?? '',
                                    style: TextStyle(color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            );
                          }

                          // === Premium message grouping (Messenger-style) ===
                          final prevMsg = msgIndex > 0 ? _messages[msgIndex - 1] : null;
                          final nextMsg = msgIndex < _messages.length - 1 ? _messages[msgIndex + 1] : null;
                          final prevIsMe = prevMsg != null ? _isMyMessage(prevMsg) : null;
                          final nextIsMe = nextMsg != null ? _isMyMessage(nextMsg) : null;
                          final prevIsSystem = prevMsg != null && (prevMsg['isSystem'] == true || prevMsg['type'] == 'system');
                          final nextIsSystem = nextMsg != null && (nextMsg['isSystem'] == true || nextMsg['type'] == 'system');

                          // For groups, also break groups when sender changes
                          String _getSenderId(Map<String, dynamic> m) {
                            final s = m['sender'];
                            if (s is Map) return s['_id']?.toString() ?? '';
                            return s?.toString() ?? '';
                          }
                          final sameSenderAsPrev = prevMsg != null && _getSenderId(prevMsg) == _getSenderId(msg);
                          final sameSenderAsNext = nextMsg != null && _getSenderId(nextMsg) == _getSenderId(msg);

                          final isFirstInGroup = widget.isGroup
                              ? (!sameSenderAsPrev || prevIsSystem || showDate)
                              : (prevIsMe != isMe || prevIsSystem || showDate);
                          final isLastInGroup = widget.isGroup
                              ? (!sameSenderAsNext || nextIsSystem || (nextMsg != null && ((DateTime.tryParse(nextMsg.asString('createdAt', '')))?.toLocal()?.day ?? 0) != timestamp.day))
                              : (nextIsMe != isMe || nextIsSystem || (nextMsg != null && ((DateTime.tryParse(nextMsg.asString('createdAt', '')))?.toLocal()?.day ?? 0) != timestamp.day));

                          // Spacing: tight within group, larger between groups
                          final topPadding = isFirstInGroup ? 8.0 : 1.5;

                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: NearfoColors.card.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _formatDate(timestamp),
                                        style: TextStyle(color: NearfoColors.textDim, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.only(top: topPadding),
                                child: _SwipeToReply(
                                  onSwipeComplete: () {
                                    setState(() => _replyingToMessage = msg);
                                    _messageFocusNode.requestFocus();
                                  },
                                  isMe: isMe,
                                  themeColor: _chatThemeColor,
                                  child: _buildMessageBubble(msg, isMe, timestamp, isFirstInGroup: isFirstInGroup, isLastInGroup: isLastInGroup),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // Reply preview banner (premium Messenger-style)
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NearfoColors.card,
                border: Border(top: BorderSide(color: _chatThemeColor.withOpacity(0.3), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3, height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_chatThemeColor, _chatThemeColor.withOpacity(0.4)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.reply_rounded, color: _chatThemeColor.withOpacity(0.6), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isMyMessage(_replyingToMessage!) ? 'Replying to yourself' : 'Replying to ${_replyingToMessage!['sender'] is Map ? _replyingToMessage!['sender']['name']?.toString() ?? widget.recipientName : widget.recipientName}',
                          style: TextStyle(color: _chatThemeColor, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          () {
                            final replyContent = _replyingToMessage!['content']?.toString() ?? '';
                            if (replyContent.isNotEmpty) return replyContent;
                            final replyType = _replyingToMessage!['type']?.toString() ?? 'text';
                            if (replyType == 'image') return 'Photo';
                            if (replyType == 'video') return 'Video';
                            if (replyType == 'voice') return 'Voice message';
                            return '';
                          }(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: NearfoColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingToMessage = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: NearfoColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.close_rounded, color: NearfoColors.textDim, size: 18),
                    ),
                  ),
                ],
              ),
            ),

          // Edit message banner
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NearfoColors.card,
                border: Border(top: BorderSide(color: NearfoColors.warning.withOpacity(0.4), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3, height: 40,
                    decoration: BoxDecoration(
                      color: NearfoColors.warning,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.edit_rounded, color: NearfoColors.warning.withOpacity(0.7), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Editing message',
                          style: TextStyle(color: NearfoColors.warning, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _editingMessage!['content']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: NearfoColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: NearfoColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.close_rounded, color: NearfoColors.textDim, size: 18),
                    ),
                  ),
                ],
              ),
            ),

          // Voice recording overlay
          ValueListenableBuilder<bool>(
            valueListenable: _isRecording,
            builder: (context, recording, _) {
              if (!recording) return const SizedBox.shrink();
              return ValueListenableBuilder<int>(
                valueListenable: _recordingSeconds,
                builder: (context, seconds, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: NearfoColors.card,
                      border: Border(top: BorderSide(color: Colors.red.withOpacity(0.3))),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          // Recording indicator
                          Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 6)],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatRecordingDuration(seconds),
                            style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          const Spacer(),
                          // Cancel button
                          GestureDetector(
                            onTap: _cancelRecording,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: NearfoColors.bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  const SizedBox(width: 4),
                                  Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          // Send voice button
                          GestureDetector(
                            onTap: _stopAndSendRecording,
                            child: Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_chatThemeColor, _chatThemeColor.withOpacity(0.8)],
                                ),
                                borderRadius: BorderRadius.circular(21),
                                boxShadow: [BoxShadow(color: _chatThemeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Blocked/Restricted banner — replaces input bar
          if (_isRecipientBlocked)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: NearfoColors.card,
                border: Border(top: BorderSide(color: NearfoColors.border.withOpacity(0.5))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_rounded, color: NearfoColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'You blocked this user',
                      style: TextStyle(color: NearfoColors.textDim, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
          // Premium Input bar (Messenger-style)
          ValueListenableBuilder<bool>(
            valueListenable: _isRecording,
            builder: (context, recording, child) {
              if (recording) return const SizedBox.shrink();
              return child!;
            },
            child:
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: NearfoColors.card,
                border: Border(top: BorderSide(color: NearfoColors.border.withOpacity(0.5))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Attachment button (opens media options)
                        GestureDetector(
                          onTap: _showMediaAttachmentOptions,
                          child: Container(
                            width: 40, height: 40,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_chatThemeColor.withOpacity(0.15), _chatThemeColor.withOpacity(0.08)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.add_rounded, color: _chatThemeColor, size: 24),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Camera quick button
                        GestureDetector(
                          onTap: () => _pickAndSendMedia(ImageSource.camera, isVideo: false),
                          child: Container(
                            width: 40, height: 40,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: NearfoColors.bg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.camera_alt_rounded, color: _chatThemeColor, size: 22),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Message input field
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            decoration: BoxDecoration(
                              color: NearfoColors.bg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: NearfoColors.border.withOpacity(0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    focusNode: _messageFocusNode,
                                    onChanged: (text) {
                                      _onTypingChanged(text);
                                      // ValueListenableBuilder will rebuild on text changes
                                    },
                                    style: TextStyle(color: NearfoColors.text, fontSize: 15),
                                    maxLines: 5,
                                    minLines: 1,
                                    decoration: InputDecoration(
                                      hintText: _editingMessage != null ? context.l10n.chatEditMessage : _replyingToMessage != null ? context.l10n.chatReply : context.l10n.chatSaySomething,
                                      hintStyle: TextStyle(color: NearfoColors.textDim, fontSize: 16),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _editingMessage != null ? _submitEditedMessage() : _sendMessage(),
                                  ),
                                ),
                                // Emoji button inside text field
                                Padding(
                                  padding: const EdgeInsets.only(right: 0, bottom: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      _showGifPicker.value = false;
                                      _showEmojiPicker.value = !_showEmojiPicker.value;
                                      if (_showEmojiPicker.value) {
                                        _messageFocusNode.unfocus();
                                      }
                                    },
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(Icons.emoji_emotions_outlined, color: NearfoColors.textDim, size: 22),
                                    ),
                                  ),
                                ),
                                // GIF button inside text field
                                Padding(
                                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      _showEmojiPicker.value = false;
                                      _showGifPicker.value = !_showGifPicker.value;
                                      if (_showGifPicker.value) {
                                        _messageFocusNode.unfocus();
                                      }
                                    },
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(context.l10n.chatMediaGif, style: TextStyle(
                                        color: NearfoColors.textDim,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      )),
                                      alignment: Alignment.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Send or Mic button (toggles based on text input)
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _messageController,
                          builder: (context, value, _) {
                            if (value.text.trim().isNotEmpty) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: _isSending,
                                builder: (context, sending, _) {
                                  return GestureDetector(
                                    onTap: _editingMessage != null ? _submitEditedMessage : _sendMessage,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [_chatThemeColor, _chatThemeColor.withOpacity(0.8)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(21),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _chatThemeColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: sending
                                          ? const Center(
                                              child: SizedBox(
                                                width: 20, height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              ),
                                            )
                                          : Icon(_editingMessage != null ? Icons.check_rounded : Icons.send_rounded, color: Colors.white, size: 20),
                                    ),
                                  );
                                },
                              );
                            } else {
                              return GestureDetector(
                                onTap: _startVoiceRecording,
                                child: Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: _chatThemeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(21),
                                  ),
                                  child: Icon(Icons.mic_rounded, color: _chatThemeColor, size: 24),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    // Emoji picker widget (FB Messenger style — all emojis)
                    ValueListenableBuilder<bool>(
                      valueListenable: _showEmojiPicker,
                      builder: (context, show, _) {
                        if (!show) return const SizedBox.shrink();
                        return Container(
                          height: 280,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            border: Border(top: BorderSide(color: NearfoColors.border.withOpacity(0.3))),
                          ),
                          child: ep.EmojiPicker(
                            textEditingController: _messageController,
                            config: ep.Config(
                              height: 280,
                              checkPlatformCompatibility: true,
                              emojiViewConfig: ep.EmojiViewConfig(
                                emojiSizeMax: 28,
                              ),
                              categoryViewConfig: const ep.CategoryViewConfig(),
                              bottomActionBarConfig: const ep.BottomActionBarConfig(),
                              searchViewConfig: const ep.SearchViewConfig(),
                            ),
                          ),
                        );
                      },
                    ),
                    // GIF picker widget (Giphy)
                    ValueListenableBuilder<bool>(
                      valueListenable: _showGifPicker,
                      builder: (context, show, _) {
                        if (!show) return const SizedBox.shrink();
                        return Container(
                          height: 280,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            border: Border(top: BorderSide(color: NearfoColors.border.withOpacity(0.3))),
                          ),
                          child: GifPicker(
                            themeColor: _chatThemeColor,
                            onGifSelected: (gif) {
                              _showGifPicker.value = false;
                              _sendGifMessage(gif);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== SEND GIF MESSAGE =====

  Future<void> _sendGifMessage(GiphyGif gif) async {
    if (_chatId == null) return;

    // Read auth user BEFORE await
    final authUser = context.read<AuthProvider>().user;

    // Enqueue as image type with the GIF URL (no upload needed)
    final queuedMsg = await OfflineMessageQueue.instance.enqueue(
      chatId: _chatId!,
      content: context.l10n.chatMediaGif,
      type: 'image',
      mediaUrl: gif.originalUrl,
    );

    // Show message immediately in chat (optimistic UI)
    final displayMsg = queuedMsg.toDisplayMessage(
      senderId: _myUserId,
      senderData: authUser != null ? {
        '_id': authUser.id,
        'name': authUser.name,
        'handle': authUser.handle,
        'avatarUrl': authUser.avatarUrl,
      } : null,
    );

    if (mounted) {
      setState(() {
        _messages.add(displayMsg);
      });
      _scrollToBottom();

      // Save to local storage
      unawaited(LocalChatStorage.instance.saveMessage(_chatId!, displayMsg));
    }
  }

  // ===== VOICE RECORDING METHODS =====

  String _formatRecordingDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startVoiceRecording() async {
    try {
      // Check microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Microphone permission required'), backgroundColor: NearfoColors.warning),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      _recorderController = aw.RecorderController()
        ..androidEncoder = aw.AndroidEncoder.aac
        ..androidOutputFormat = aw.AndroidOutputFormat.mpeg4
        ..iosEncoder = aw.IosEncoder.kAudioFormatMPEG4AAC
        ..sampleRate = 44100
        ..bitRate = 128000;

      await _recorderController!.record(path: _recordingPath!);

      HapticFeedback.mediumImpact();

      _isRecording.value = true;
      _recordingSeconds.value = 0;
      _recordingStartTime = DateTime.now();

      // Start duration timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _recordingSeconds.value++;
          // Auto-stop after 5 minutes
          if (_recordingSeconds.value >= 300) {
            _stopAndSendRecording();
          }
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      debugPrint('[VoiceRecord] Error starting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to start recording'), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _recorderController?.stop();
      _recorderController?.dispose();
      _recorderController = null;
      // Delete the temp file
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      debugPrint('[VoiceRecord] Cancel error: $e');
    }
    if (mounted) {
      _isRecording.value = false;
      _recordingSeconds.value = 0;
      _recordingPath = null;
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording.value || _chatId == null) return;

    try {
      _recordingTimer?.cancel();
      final path = await _recorderController?.stop();
      _recorderController?.dispose();
      _recorderController = null;
      final duration = _recordingSeconds.value;

      _isRecording.value = false;
      _recordingSeconds.value = 0;

      if (path == null || path.isEmpty) {
        debugPrint('[VoiceRecord] No recording path returned');
        return;
      }

      // Don't send very short recordings (< 1 second)
      if (duration < 1) {
        final file = File(path);
        if (await file.exists()) await file.delete();
        return;
      }

      _isSending.value = true;

      // Read auth user BEFORE await (context.read is unsafe after async gap)
      final authUser = context.read<AuthProvider>().user;

      // === OFFLINE-FIRST: Enqueue voice message with local path ===
      final queuedMsg = await OfflineMessageQueue.instance.enqueue(
        chatId: _chatId!,
        content: '${duration}s voice message',
        type: 'voice',
        localMediaPath: path,
      );

      // Show message immediately in chat (optimistic UI)
      final displayMsg = queuedMsg.toDisplayMessage(
        senderId: _myUserId,
        senderData: authUser != null ? {
          '_id': authUser.id,
          'name': authUser.name,
          'handle': authUser.handle,
          'avatarUrl': authUser.avatarUrl,
        } : null,
      );

      if (mounted) {
        _isSending.value = false;
        setState(() {
          _messages.add(displayMsg);
        });
        _scrollToBottom();
        unawaited(LocalChatStorage.instance.saveMessage(_chatId!, displayMsg));
      }
      // Note: Don't delete temp file — queue needs it for upload
    } catch (e) {
      debugPrint('[VoiceRecord] Stop/send error: $e');
      if (mounted) {
        _isRecording.value = false;
        _isSending.value = false;
        _recordingSeconds.value = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Voice message failed'), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }

  /// Show Messenger-style attachment options bottom sheet
  void _showMediaAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_library_rounded,
                    label: context.l10n.chatMediaGallery,
                    color: const Color(0xFF00B894),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendMedia(ImageSource.gallery, isVideo: false);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: context.l10n.chatMediaCamera,
                    color: const Color(0xFF0984E3),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendMedia(ImageSource.camera, isVideo: false);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.videocam_rounded,
                    label: context.l10n.chatMediaVideo,
                    color: const Color(0xFFE17055),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendMedia(ImageSource.gallery, isVideo: true);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.video_camera_front_rounded,
                    label: context.l10n.chatMediaRecord,
                    color: const Color(0xFFE84393),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendMedia(ImageSource.camera, isVideo: true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: NearfoColors.text, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// Pick image/video from gallery or camera and send as message
  Future<void> _pickAndSendMedia(ImageSource source, {required bool isVideo}) async {
    if (_chatId == null) return;

    try {
      final picker = ImagePicker();
      XFile? file;

      if (isVideo) {
        file = await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 5));
      } else {
        file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
      }

      if (file == null) return; // User cancelled

      _isSending.value = true;

      // Compress media before upload
      String uploadPath = file.path;
      if (isVideo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Compressing video...'),
              backgroundColor: NearfoColors.primary,
              duration: const Duration(seconds: 30),
            ),
          );
        }
        uploadPath = await VideoCompressor.compressTo720p(file.path);
        debugPrint('[Chat] Video compress: ${file.path} -> $uploadPath');
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      } else {
        // Compress image (multi-pass, under 900KB)
        uploadPath = await ImageCompressor.compress(file.path, type: ImageType.post);
        debugPrint('[Chat] Image compress: ${file.path} -> $uploadPath');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploading ${isVideo ? 'video' : 'image'}...'),
            backgroundColor: NearfoColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Read auth user BEFORE await (context.read is unsafe after async gap)
      final authUser = context.read<AuthProvider>().user;

      // === OFFLINE-FIRST: Enqueue media message with local file path ===
      // Queue handles upload + send in background (works offline too)
      final msgType = isVideo ? 'video' : 'image';
      final queuedMsg = await OfflineMessageQueue.instance.enqueue(
        chatId: _chatId!,
        content: '',
        type: msgType,
        localMediaPath: uploadPath,
      );

      // Show message immediately in chat (optimistic UI with local file)
      final displayMsg = queuedMsg.toDisplayMessage(
        senderId: _myUserId,
        senderData: authUser != null ? {
          '_id': authUser.id,
          'name': authUser.name,
          'handle': authUser.handle,
          'avatarUrl': authUser.avatarUrl,
        } : null,
      );

      if (mounted) {
        _isSending.value = false;
        setState(() {
          _messages.add(displayMsg);
        });
        _scrollToBottom();
        unawaited(LocalChatStorage.instance.saveMessage(_chatId!, displayMsg));
      }
    } catch (e) {
      debugPrint('[Media] Error: $e');
      if (mounted) {
        _isSending.value = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Something went wrong'), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }

  void _scrollToMessage(String? messageId) {
    if (messageId == null || messageId.isEmpty) return;
    final index = _messages.indexWhere((m) => m['_id']?.toString() == messageId);
    if (index == -1) return;

    // Calculate approximate scroll position (each message ~80px height)
    final estimatedOffset = index * 80.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = estimatedOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _addReaction(Map<String, dynamic> msg, String emoji) async {
    final msgId = msg['_id']?.toString();
    if (msgId == null || _chatId == null) return;

    // Update local message state optimistically
    setState(() {
      final idx = _messages.indexWhere((m) => m.asStringOrNull('_id') == msgId);
      if (idx != -1) {
        final reactions = List<dynamic>.from(_messages[idx].asList('reactions'));

        final existingIdx = reactions.indexWhere(
          (r) => r is Map && r['emoji'] == emoji && r['userId'] == _myUserId,
        );

        if (existingIdx == -1) {
          reactions.add({
            'emoji': emoji,
            'userId': _myUserId,
            'userName': context.read<AuthProvider>().user?.name ?? 'You',
          });
          _messages[idx]['reactions'] = reactions;
        }
      }
    });

    // Send to API and socket
    final apiRes = await ApiService.addReaction(_chatId!, msgId, emoji);
    if (apiRes.isSuccess) {
      SocketService.instance.addMessageReaction(
        chatId: _chatId!,
        messageId: msgId,
        emoji: emoji,
      );
    } else {
      // Revert optimistic update on API failure
      setState(() {
        final idx = _messages.indexWhere((m) => m.asStringOrNull('_id') == msgId);
        if (idx != -1) {
          List<dynamic> reactions = List<dynamic>.from(_messages[idx].asList('reactions'));
          reactions.removeWhere((r) => r is Map && r['emoji'] == emoji && r['userId'] == _myUserId);
          _messages[idx]['reactions'] = reactions;
        }
      });
    }
  }

  void _showReactionPicker(Map<String, dynamic> msg, Offset tapPosition) {
    final reactionEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy - 60,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      items: reactionEmojis.map((emoji) {
        return PopupMenuItem<String>(
          value: emoji,
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        _addReaction(msg, selected);
      }
    });
  }

  Widget _buildReactionsDisplay(Map<String, dynamic> msg, bool isMe) {
    final reactions = msg.asList('reactions');
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji
    final Map<String, int> reactionCounts = {};
    for (final reaction in reactions) {
      final emoji = (reaction as Map<String, dynamic>).asString('emoji', '');
      if (emoji.isNotEmpty) {
        reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactionCounts.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isMe
              ? Colors.white.withOpacity(0.15)
              : NearfoColors.bg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe
                ? Colors.white.withOpacity(0.2)
                : NearfoColors.border,
            ),
          ),
          child: Text(
            '${entry.key} ${entry.value > 1 ? entry.value : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isMe ? Colors.white : NearfoColors.text,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReplyPreviewInBubble(Map<String, dynamic> replyTo, bool isMe) {
    final replyContent = replyTo['content']?.toString() ?? '';
    final replySenderName = replyTo['senderName']?.toString() ?? '';
    final isMeReply = replyTo['senderId']?.toString() == _myUserId;
    // Determine display text — show type label if content is empty (media messages)
    final replyType = replyTo['type']?.toString() ?? 'text';
    final displayContent = replyContent.isNotEmpty
        ? replyContent
        : (replyType == 'image' ? 'Photo' : replyType == 'video' ? 'Video' : replyType == 'voice' ? 'Voice message' : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isMe ? Colors.white.withOpacity(0.5) : _chatThemeColor.withOpacity(0.7), width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMeReply ? 'You' : replySenderName,
            style: TextStyle(color: _chatThemeColor, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            displayContent.length > 80 ? '${displayContent.substring(0, 80)}...' : displayContent,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMe ? Colors.white.withOpacity(0.7) : NearfoColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, DateTime timestamp, {bool isFirstInGroup = true, bool isLastInGroup = true}) {
    final content = msg.asString('content', '');
    final status = isMe ? _getMessageStatus(msg) : null;
    final replyTo = msg.asMapOrNull('replyTo');
    final hasReply = replyTo != null && (replyTo['messageId'] != null || replyTo.asString('content', '').isNotEmpty);
    final msgType = msg.asString('type', 'text');
    // Support both camelCase and snake_case keys from backend/socket
    final mediaUrl = msg.asStringOrNull('mediaUrl') ?? msg.asStringOrNull('media_url');

    // === Premium Messenger-style border radius ===
    const double bigR = 20.0;
    const double smallR = 4.0;

    // Smart corners: grouped messages get tight corners on their side
    final BorderRadius bubbleRadius;
    if (isMe) {
      bubbleRadius = BorderRadius.only(
        topLeft: const Radius.circular(bigR),
        topRight: Radius.circular(isFirstInGroup ? bigR : smallR),
        bottomLeft: const Radius.circular(bigR),
        bottomRight: Radius.circular(isLastInGroup ? bigR : smallR),
      );
    } else {
      bubbleRadius = BorderRadius.only(
        topLeft: Radius.circular(isFirstInGroup ? bigR : smallR),
        topRight: const Radius.circular(bigR),
        bottomLeft: Radius.circular(isLastInGroup ? bigR : smallR),
        bottomRight: const Radius.circular(bigR),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageActions(msg),
      onDoubleTap: () {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final tapPosition = box.localToGlobal(Offset.zero);
        _showReactionPicker(msg, tapPosition);
      },
      child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: IntrinsicWidth(
              child: ClipRRect(
                borderRadius: bubbleRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
        padding: (msgType == 'image' || msgType == 'video') && mediaUrl != null
            ? const EdgeInsets.all(3)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isMe ? LinearGradient(
            colors: [
              _chatThemeColor.withOpacity(0.55),
              _chatThemeColor.withOpacity(0.30),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : LinearGradient(
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: bubbleRadius,
          border: Border.all(
            color: isMe
                ? Colors.white.withOpacity(0.18)
                : Colors.white.withOpacity(0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isMe
                  ? _chatThemeColor.withOpacity(0.20)
                  : Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show sender name in group chats for messages from others
            if (widget.isGroup && !isMe && isFirstInGroup)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  (msg['sender'] is Map ? (msg['sender'] as Map)['name']?.toString() : null) ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _chatThemeColor,
                  ),
                ),
              ),
            if (hasReply)
              Padding(
                padding: (msgType == 'image' || msgType == 'video') && mediaUrl != null
                    ? const EdgeInsets.fromLTRB(10, 4, 10, 4)
                    : EdgeInsets.zero,
                child: GestureDetector(
                  onTap: () => _scrollToMessage(replyTo!['messageId']?.toString()),
                  child: _buildReplyPreviewInBubble(replyTo!, isMe),
                ),
              ),
            // === IMAGE MESSAGE ===
            if (msgType == 'image' && mediaUrl != null)
              _buildImageContent(mediaUrl, isMe, content),
            // === VIDEO MESSAGE ===
            if (msgType == 'video' && mediaUrl != null)
              _buildVideoContent(mediaUrl, isMe, content),
            // === VOICE MESSAGE ===
            if (msgType == 'voice' && mediaUrl != null)
              _VoiceMessagePlayer(
                url: mediaUrl,
                isMe: isMe,
                themeColor: _chatThemeColor,
                durationText: content,
              ),
            // === TEXT MESSAGE (default) ===
            if (msgType != 'image' && msgType != 'video' && msgType != 'voice')
              Text(
                content,
                style: TextStyle(
                  color: isMe ? Colors.white : NearfoColors.text,
                  fontSize: 15.5,
                  height: 1.3,
                ),
              ),
            // Show time on last message in group, or always for media
            if (isLastInGroup || msgType == 'image' || msgType == 'video' || msgType == 'voice') ...[
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  if (msg['isEdited'] == true) ...[
                    Text(
                      'edited',
                      style: TextStyle(
                        color: isMe ? Colors.white.withOpacity(0.45) : NearfoColors.textDim.withOpacity(0.6),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Padding(
                    padding: (msgType == 'image' || msgType == 'video') && mediaUrl != null
                        ? const EdgeInsets.symmetric(horizontal: 10)
                        : EdgeInsets.zero,
                    child: Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        color: isMe ? Colors.white.withOpacity(0.55) : NearfoColors.textDim.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (isMe && status != null) ...[
                    const SizedBox(width: 3),
                    _buildStatusIcon(status),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
                ),
              ),
            ),
          ),
          // Reactions display below bubble
          if (msg.asList('reactions').isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 6,
                left: isMe ? 0 : 8,
                right: isMe ? 8 : 0,
              ),
              child: _buildReactionsDisplay(msg, isMe),
            ),
        ],
      ),
      ),
    );
  }

  /// Build image content inside a message bubble
  Widget _buildImageContent(String url, bool isMe, String caption) {
    final resolvedUrl = NearfoConfig.resolveMediaUrl(url);
    debugPrint('[ChatImage] raw=$url resolved=$resolvedUrl');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showFullScreenImage(resolvedUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
              child: CachedNetworkImage(
                imageUrl: resolvedUrl,
                fit: BoxFit.cover,
                placeholder: (ctx, _) => Container(
                  width: 200, height: 150,
                  decoration: BoxDecoration(
                    color: NearfoColors.bg.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isMe ? Colors.white : NearfoColors.primary,
                    ),
                  ),
                ),
                errorWidget: (ctx, _, err) => Container(
                  width: 200, height: 150,
                  decoration: BoxDecoration(
                    color: NearfoColors.bg.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: isMe ? Colors.white54 : NearfoColors.textDim, size: 40),
                      const SizedBox(height: 4),
                      Text('Image failed to load',
                        style: TextStyle(color: isMe ? Colors.white54 : NearfoColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              caption,
              style: TextStyle(
                color: isMe ? Colors.white : NearfoColors.text,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }

  /// Build video content inside a message bubble (thumbnail + play icon)
  Widget _buildVideoContent(String url, bool isMe, String caption) {
    final resolvedUrl = NearfoConfig.resolveMediaUrl(url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openVideoPlayer(resolvedUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 250, height: 180,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Show first frame as thumbnail from video
                  _VideoThumbnail(url: resolvedUrl, width: 250, height: 180),
                  // Play button overlay
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                  // Video label
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('Video', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              caption,
              style: TextStyle(
                color: isMe ? Colors.white : NearfoColors.text,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }

  /// Full screen image viewer
  void _showFullScreenImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeCtx) => _FullScreenMediaViewer(
          url: url,
          mediaType: 'image',
          themeColor: _chatThemeColor,
        ),
      ),
    );
  }

  /// Open video in a simple player page
  void _openVideoPlayer(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeCtx) => _FullScreenMediaViewer(
          url: url,
          mediaType: 'video',
          themeColor: _chatThemeColor,
        ),
      ),
    );
  }

  /// Download media file to device storage (delegates to static helper)
  Future<void> _downloadMedia(String url, String mediaType) async {
    await _MediaDownloadHelper.download(
      url: url,
      mediaType: mediaType,
      context: context,
      isMounted: () => mounted,
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'read':
        // Green double tick
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 14, color: NearfoColors.success),
          ],
        );
      case 'delivered':
        // Grey double tick
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 14, color: Colors.white.withOpacity(0.7)),
          ],
        );
      case 'pending':
        // Clock icon = waiting to send (offline or in queue)
        return SizedBox(
          width: 14,
          height: 14,
          child: Icon(Icons.access_time, size: 13, color: Colors.white.withOpacity(0.5)),
        );
      case 'failed':
        // Red error icon = send failed
        return GestureDetector(
          onTap: () {
            // Show retry option
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Message failed to send. Tap to retry.'),
                backgroundColor: NearfoColors.danger,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    unawaited(OfflineMessageQueue.instance.processQueue());
                  },
                ),
              ),
            );
          },
          child: Icon(Icons.error_outline, size: 14, color: NearfoColors.danger),
        );
      default:
        // Single tick = sent
        return Icon(Icons.done, size: 14, color: Colors.white.withOpacity(0.7));
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(dateOnly).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// WhatsApp/Messenger-style swipe-to-reply widget
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeComplete;
  final bool isMe;
  final Color themeColor;

  const _SwipeToReply({
    required this.child,
    required this.onSwipeComplete,
    required this.isMe,
    required this.themeColor,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _hasTriggered = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  static const double _triggerThreshold = 64.0;
  static const double _maxDrag = 100.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.addListener(() {
      setState(() => _dragOffset = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only allow right swipe (positive dx)
    final newOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDrag);
    setState(() => _dragOffset = newOffset);

    // Haptic feedback when threshold is crossed
    if (!_hasTriggered && _dragOffset >= _triggerThreshold) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
    } else if (_hasTriggered && _dragOffset < _triggerThreshold) {
      _hasTriggered = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= _triggerThreshold) {
      // Trigger reply
      HapticFeedback.lightImpact();
      widget.onSwipeComplete();
    }

    // Animate back to origin
    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.forward(from: 0);
    _hasTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _triggerThreshold).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Reply icon that appears behind the message on swipe
        Positioned(
          left: widget.isMe ? null : 0,
          right: widget.isMe ? 0 : null,
          top: 0,
          bottom: 0,
          child: Opacity(
            opacity: progress,
            child: Center(
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hasTriggered
                        ? widget.themeColor
                        : widget.themeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    color: _hasTriggered
                        ? Colors.white
                        : widget.themeColor,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        // The actual message bubble, translated by drag
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// Static helper for downloading media — used by both chat screen and fullscreen viewer
/// Uses dio streaming download + saves images/videos to device Gallery.
/// Voice messages go to Downloads folder (not gallery-appropriate).
class _MediaDownloadHelper {
  static final _dio = dio_pkg.Dio(dio_pkg.BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  static Future<void> download({
    required String url,
    required String mediaType,
    required BuildContext context,
    required bool Function() isMounted,
  }) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        bool hasPermission = false;

        // Android 13+: granular media permissions
        if (mediaType == 'image') {
          final status = await Permission.photos.request();
          hasPermission = status.isGranted || status.isLimited;
        } else if (mediaType == 'video') {
          final status = await Permission.videos.request();
          hasPermission = status.isGranted || status.isLimited;
        } else if (mediaType == 'voice') {
          final status = await Permission.audio.request();
          hasPermission = status.isGranted || status.isLimited;
        }

        // Fallback to storage permission (older Android)
        if (!hasPermission) {
          final status = await Permission.storage.request();
          hasPermission = status.isGranted;
        }

        // Last resort: manage external storage (Android 11+)
        if (!hasPermission) {
          final status = await Permission.manageExternalStorage.request();
          hasPermission = status.isGranted;
        }

        if (!hasPermission) {
          if (isMounted()) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('Storage permission required to download'), backgroundColor: NearfoColors.warning),
            );
          }
          return;
        }
      }

      if (isMounted()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saving $mediaType...'), backgroundColor: NearfoColors.primary, duration: const Duration(seconds: 1)),
        );
      }

      // Generate filename
      final uri = Uri.parse(url);
      String filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (filename.contains('?')) filename = filename.split('?').first;
      if (filename.isEmpty || !filename.contains('.')) {
        final ext = mediaType == 'image' ? 'jpg' : mediaType == 'voice' ? 'm4a' : 'mp4';
        filename = 'nearfo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      // Download to temp directory first
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';

      final response = await _dio.download(
        url,
        tempPath,
        options: dio_pkg.Options(
          headers: {'Accept': '*/*'},
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Download failed (HTTP ${response.statusCode})');
      }

      final tempFile = File(tempPath);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw Exception('File was not saved correctly');
      }

      // Save images/videos to Gallery via native MediaStore API
      // Voice messages go to Downloads folder
      String successMsg;
      if (Platform.isAndroid && (mediaType == 'image' || mediaType == 'video')) {
        // Use native MediaStore API (works on Android 10+ scoped storage)
        try {
          const channel = MethodChannel('com.nearfo.app/media_scanner');
          await channel.invokeMethod<String>('saveToGallery', {
            'path': tempPath,
            'mediaType': mediaType,
            'fileName': filename,
          });
        } catch (e) {
          // Fallback: try direct DCIM copy (works on Android 9 and below)
          final dcimDir = Directory('/storage/emulated/0/DCIM/Nearfo');
          if (!await dcimDir.exists()) {
            await dcimDir.create(recursive: true);
          }
          final destPath = '${dcimDir.path}/$filename';
          await tempFile.copy(destPath);
        }
        try { await tempFile.delete(); } catch (_) {}

        successMsg = '${mediaType == 'image' ? 'Image' : 'Video'} saved to Gallery';
      } else {
        // Voice messages or iOS → save to Downloads / Documents
        Directory? destDir;
        if (Platform.isAndroid) {
          destDir = Directory('/storage/emulated/0/Download');
          if (!await destDir.exists()) {
            destDir = await getExternalStorageDirectory();
          }
          destDir ??= await getApplicationDocumentsDirectory();
        } else {
          destDir = await getApplicationDocumentsDirectory();
        }
        final destPath = '${destDir.path}/$filename';
        await tempFile.copy(destPath);
        try { await tempFile.delete(); } catch (_) {}
        successMsg = mediaType == 'voice'
            ? 'Voice message saved to Downloads'
            : '${mediaType == 'image' ? 'Image' : 'Video'} saved to Downloads';
      }

      if (isMounted()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: NearfoColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on dio_pkg.DioException catch (e) {
      debugPrint('[Download] Dio error: ${e.type} — ${e.message}');
      String errorMsg = 'Failed to download $mediaType';
      if (e.type == dio_pkg.DioExceptionType.connectionTimeout ||
          e.type == dio_pkg.DioExceptionType.receiveTimeout) {
        errorMsg = 'Download timed out. Check your connection.';
      } else if (e.type == dio_pkg.DioExceptionType.connectionError) {
        errorMsg = 'No internet connection';
      } else if (e.response?.statusCode == 403) {
        errorMsg = 'Access denied. Media may have expired.';
      } else if (e.response?.statusCode == 404) {
        errorMsg = 'Media file not found on server';
      }
      if (isMounted()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: NearfoColors.danger),
        );
      }
    } catch (e) {
      debugPrint('[Download] Error: $e');
      if (isMounted()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download $mediaType'), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }
}

/// Video thumbnail widget — extracts frame natively using video_thumbnail package
class _VideoThumbnail extends StatefulWidget {
  final String url;
  final double width;
  final double height;

  const _VideoThumbnail({required this.url, required this.width, required this.height});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();

  /// In-memory cache of thumbnail bytes keyed by URL
  static final Map<String, Uint8List> _cache = {};
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  Uint8List? _thumbBytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Check cache first
    final cached = _VideoThumbnail._cache[widget.url];
    if (cached != null) {
      _thumbBytes = cached;
      return;
    }
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final bytes = await vt.VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: (widget.width * 2).toInt(), // 2x for sharp display
        quality: 75,
        timeMs: 500, // grab frame at 0.5s
      );
      if (bytes != null && bytes.isNotEmpty) {
        // Cache for reuse
        _VideoThumbnail._cache[widget.url] = bytes;
        if (mounted) {
          setState(() => _thumbBytes = bytes);
        }
      } else {
        if (mounted) setState(() => _failed = true);
      }
    } catch (e) {
      debugPrint('[VideoThumbnail] Failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbBytes != null) {
      return SizedBox(
        width: widget.width, height: widget.height,
        child: Image.memory(
          _thumbBytes!,
          fit: BoxFit.cover,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, __, ___) => _placeholder(failed: true),
        ),
      );
    }
    return _placeholder(failed: _failed);
  }

  Widget _placeholder({required bool failed}) {
    return Container(
      width: widget.width, height: widget.height,
      color: Colors.black54,
      child: Center(
        child: failed
            ? Icon(Icons.videocam, color: Colors.white24, size: 60)
            : SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white30,
                ),
              ),
      ),
    );
  }
}

/// Full screen media viewer with its own Scaffold context for SnackBars
class _FullScreenMediaViewer extends StatefulWidget {
  final String url;
  final String mediaType; // 'image' or 'video'
  final Color themeColor;

  const _FullScreenMediaViewer({
    required this.url,
    required this.mediaType,
    required this.themeColor,
  });

  @override
  State<_FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<_FullScreenMediaViewer> {
  bool _isDownloading = false;
  late final String _resolvedUrl = NearfoConfig.resolveMediaUrl(widget.url);

  // Video: download-first-play-locally approach
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoadingVideo = true;
  double _downloadProgress = 0.0;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _downloadAndPlayVideo();
    }
  }

  /// Download video to temp file first, then play locally.
  /// This bypasses ExoPlayer streaming issues with CloudFront URLs.
  Future<void> _downloadAndPlayVideo() async {
    try {
      setState(() {
        _isLoadingVideo = true;
        _videoError = null;
        _downloadProgress = 0.0;
      });

      debugPrint('[VideoPlayer] Downloading: $_resolvedUrl');

      final tempDir = await getTemporaryDirectory();
      final fileName = 'nearfo_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tempFile = File('${tempDir.path}/$fileName');

      final dio = dio_pkg.Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(minutes: 5);

      await dio.download(
        _resolvedUrl,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
        options: dio_pkg.Options(
          headers: {
            'User-Agent': 'Nearfo/1.0',
            'Accept': '*/*',
          },
        ),
      );

      if (!mounted) {
        // Cleanup if widget was disposed during download
        tempFile.deleteSync();
        return;
      }

      final fileSize = await tempFile.length();
      debugPrint('[VideoPlayer] Downloaded: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB -> ${tempFile.path}');

      if (fileSize < 1000) {
        throw Exception('Downloaded file too small (${fileSize}B) — likely not a valid video');
      }

      // Play from local file — reliable on all Android devices
      final vpController = VideoPlayerController.file(tempFile);
      await vpController.initialize();

      if (!mounted) {
        vpController.dispose();
        tempFile.deleteSync();
        return;
      }

      final chewie = ChewieController(
        videoPlayerController: vpController,
        autoPlay: true,
        looping: false,
        aspectRatio: vpController.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: widget.themeColor,
          handleColor: widget.themeColor,
          bufferedColor: widget.themeColor.withOpacity(0.3),
          backgroundColor: Colors.white24,
        ),
        errorBuilder: (context, errorMessage) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Playback error', style: const TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryVideo,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) {
        chewie.dispose();
        vpController.dispose();
        return;
      }

      setState(() {
        _videoController = vpController;
        _chewieController = chewie;
        _isLoadingVideo = false;
      });
    } catch (e) {
      debugPrint('[VideoPlayer] Error: $e');
      if (mounted) {
        setState(() {
          _videoError = 'Failed to load video';
          _isLoadingVideo = false;
        });
      }
    }
  }

  void _retryVideo() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
    _downloadAndPlayVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    await _MediaDownloadHelper.download(
      url: _resolvedUrl,
      mediaType: widget.mediaType,
      context: context,
      isMounted: () => mounted,
    );

    if (mounted) setState(() => _isDownloading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaType == 'image') {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: _isDownloading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: _handleDownload,
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: _resolvedUrl,
              fit: BoxFit.contain,
              placeholder: (ctx, _) => Center(
                child: CircularProgressIndicator(color: widget.themeColor),
              ),
              errorWidget: (_, __, ___) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white38, size: 64),
                  const SizedBox(height: 12),
                  Text('Failed to load image', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Video viewer — download-first, play locally via Chewie
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Video', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: _isDownloading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _handleDownload,
          ),
        ],
      ),
      body: _buildVideoBody(),
    );
  }

  Widget _buildVideoBody() {
    if (_isLoadingVideo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                color: widget.themeColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0
                  ? 'Downloading... ${(_downloadProgress * 100).toInt()}%'
                  : 'Loading video...',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_videoError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_videoError!, style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retryVideo,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const SizedBox.shrink();
  }
}

/// Voice message playback widget inside a chat bubble
class _VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  final Color themeColor;
  final String durationText;

  const _VoiceMessagePlayer({
    required this.url,
    required this.isMe,
    required this.themeColor,
    required this.durationText,
  });

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// Local file path after downloading from CloudFront (download-first approach)
  String? _localFilePath;

  /// Stream subscriptions — stored for proper cleanup in dispose
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    }));
    _subs.add(_player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    }));
    _subs.add(_player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _hasSource = false; // Allow replay from beginning on next tap
        });
      }
    }));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  bool _hasSource = false;

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else if (_hasSource && _position > Duration.zero) {
        // Resume from paused position
        await _player.resume();
      } else {
        setState(() => _isLoading = true);
        final resolvedUrl = NearfoConfig.resolveMediaUrl(widget.url);
        debugPrint('[VoicePlayer] Raw URL: ${widget.url}');
        debugPrint('[VoicePlayer] Resolved URL: $resolvedUrl');

        // Download-first approach: download to temp file then play locally
        // (CloudFront streaming can fail on Android — same fix as video player)
        if (_localFilePath == null) {
          final tempDir = await getTemporaryDirectory();
          final uri = Uri.parse(resolvedUrl);
          String filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
          if (filename.contains('?')) filename = filename.split('?').first;
          if (filename.isEmpty || !filename.contains('.')) {
            filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          }
          final tempPath = '${tempDir.path}/$filename';

          // Check if already cached from a previous session
          final cachedFile = File(tempPath);
          if (await cachedFile.exists() && (await cachedFile.length()) > 0) {
            _localFilePath = tempPath;
            debugPrint('[VoicePlayer] Using cached file: $tempPath');
          } else {
            debugPrint('[VoicePlayer] Downloading to: $tempPath');
            final dioClient = dio_pkg.Dio(dio_pkg.BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ));
            await dioClient.download(resolvedUrl, tempPath);
            // Verify download succeeded before caching path
            final dlFile = File(tempPath);
            if (await dlFile.exists() && (await dlFile.length()) > 0) {
              _localFilePath = tempPath;
              debugPrint('[VoicePlayer] Download complete: $tempPath');
            } else {
              throw Exception('Downloaded file is empty');
            }
          }
        }

        await _player.play(DeviceFileSource(_localFilePath!));
        _hasSource = true;
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[VoicePlayer] Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to play voice message'), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Parse duration from content like "15s voice message"
  int _parseDurationFromText() {
    final match = RegExp(r'(\d+)s').firstMatch(widget.durationText);
    if (match != null) return int.tryParse(match.group(1)!) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = _duration.inSeconds > 0
        ? _duration
        : Duration(seconds: _parseDurationFromText());
    final progress = totalDuration.inMilliseconds > 0
        ? (_position.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlayback,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white.withOpacity(0.2) : widget.themeColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isMe ? Colors.white : widget.themeColor,
                      ),
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: widget.isMe ? Colors.white : widget.themeColor,
                    size: 22,
                  ),
          ),
        ),
        SizedBox(width: 10),
        // Waveform + progress
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform bar visualization
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      progress: progress,
                      activeColor: widget.isMe ? Colors.white : widget.themeColor,
                      inactiveColor: widget.isMe ? Colors.white.withOpacity(0.3) : widget.themeColor.withOpacity(0.2),
                    ),
                    size: const Size(double.infinity, 28),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Duration text
              Text(
                _isPlaying || _position.inSeconds > 0
                    ? '${_formatDuration(_position)} / ${_formatDuration(totalDuration)}'
                    : _formatDuration(totalDuration),
                style: TextStyle(
                  color: widget.isMe ? Colors.white.withOpacity(0.7) : NearfoColors.textDim,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Mic icon
        Icon(Icons.mic, color: widget.isMe ? Colors.white.withOpacity(0.5) : widget.themeColor.withOpacity(0.4), size: 18),
      ],
    );
  }
}

/// Custom painter for voice waveform visualization
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Generate fixed waveform bars (pseudo-random pattern for visual appeal)
    const barWidth = 3.0;
    const barSpacing = 2.0;
    final barCount = ((size.width) / (barWidth + barSpacing)).floor();

    // Pre-defined wave heights for visual consistency
    final heights = List.generate(barCount, (i) {
      // Create a natural-looking waveform pattern
      final seed = (i * 7 + 3) % 13;
      return 0.2 + (seed / 13.0) * 0.8;
    });

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + barSpacing);
      final normalizedPos = i / barCount;
      final isActive = normalizedPos <= progress;

      final barHeight = heights[i] * size.height;
      final y = (size.height - barHeight) / 2;

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

