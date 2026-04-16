import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/cache_service.dart';
import '../providers/auth_provider.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _chatUpdateSub;
  StreamSubscription? _userStatusSub;
  final Set<String> _pinnedChatIds = {};
  final Set<String> _mutedChatIds = {};
  final Set<String> _archivedChatIds = {};
  Set<String> _usersWithStories = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadStoryUsers();
    _chatUpdateSub = SocketService.instance.onChatUpdate.listen((_) {
      _loadChats(); // Refresh when a new message arrives in any chat
    });
    // Listen for real-time online/offline status changes
    _userStatusSub = SocketService.instance.onUserStatus.listen((data) {
      final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final userId = d.asStringOrNull('userId');
      final isOnline = d['isOnline'] == true;
      if (userId == null || !mounted) return;
      // Update participant's isOnline in local chat data
      bool changed = false;
      for (final chat in _chats) {
        final participants = chat.asListOrNull('participants');
        if (participants is List) {
          for (final p in participants) {
            if (p is Map) {
              final pMap = p as Map<String, dynamic>;
              if (pMap['_id'] == userId) {
                if (pMap['isOnline'] != isOnline) {
                  pMap['isOnline'] = isOnline;
                  if (!isOnline) pMap['lastSeen'] = DateTime.now().toUtc().toIso8601String();
                  changed = true;
                }
              }
            }
          }
        }
      }
      if (changed && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _chatUpdateSub?.cancel();
    _userStatusSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    // Show cached chat list instantly on first load
    if (_isLoading && _chats.isEmpty) {
      final cached = CacheService.getStale('chat_list');
      if (cached != null && cached is List<dynamic>) {
        try {
          final cachedChats = (cached as List<dynamic>).map((c) => Map<String, dynamic>.from(c as Map<dynamic, dynamic>)).toList();
          if (mounted) {
            setState(() {
              _chats = cachedChats;
              _filteredChats = cachedChats;
              _isLoading = false;
            });
            _filterChats(_searchController.text);
          }
        } catch (_) {}
      }
    }

    // Always fetch fresh data
    final res = await ApiService.getChats();
    if (res.isSuccess && res.data != null && mounted) {
      setState(() {
        _chats = res.data!;
        _filteredChats = res.data!;
        _isLoading = false;
      });
      _filterChats(_searchController.text);
      // Cache fresh data
      CacheService.put('chat_list', res.data!, maxAge: const Duration(minutes: 10));
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStoryUsers() async {
    try {
      final res = await ApiService.getStoryFeed();
      if (res.isSuccess && res.data != null && mounted) {
        final storyGroups = res.data!;
        final userIds = <String>{};
        for (final group in storyGroups) {
          final user = (group as Map<String, dynamic>)['user'];
          if (user is Map) {
            final id = (user as Map<String, dynamic>).asStringOrNull('_id');
            if (id != null) userIds.add(id);
          }
        }
        if (mounted) setState(() => _usersWithStories = userIds);
      }
    } catch (e) {
      debugPrint('[ChatScreen] Fetch stories error: $e');
    }
  }

  void _filterChats(String query) {
    final q = query.toLowerCase();
    setState(() {
      var filtered = _chats.where((chat) {
        final chatId = chat.asString('_id', '');
        // Hide archived chats
        if (_archivedChatIds.contains(chatId)) return false;
        if (query.isEmpty) return true;
        final isGroup = chat['isGroup'] == true;
        final name = isGroup
            ? chat.asString('groupName', '')
            : _getOtherParticipantName(chat);
        final lastMsg = chat.asString('lastMessage', '');
        return name.toLowerCase().contains(q) || lastMsg.toLowerCase().contains(q);
      }).toList();

      // Sort: pinned chats first
      filtered.sort((a, b) {
        final aId = a.asString('_id', '');
        final bId = b.asString('_id', '');
        final aPinned = _pinnedChatIds.contains(aId) ? 0 : 1;
        final bPinned = _pinnedChatIds.contains(bId) ? 0 : 1;
        if (aPinned != bPinned) return aPinned.compareTo(bPinned);
        return 0; // keep original order otherwise
      });

      _filteredChats = filtered;
    });
  }

  void _openNewChatSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NewChatSearchSheet(),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        Navigator.pushNamed(context, NearfoRoutes.chatDetail, arguments: {
          'recipientId': (result['_id'] as String?) ?? '',
          'recipientName': (result['name'] as String?) ?? (result['handle'] as String?) ?? 'User',
          'recipientHandle': result['handle'],
          'recipientAvatar': result['avatarUrl'],
          'isOnline': result['isOnline'] == true,
        }).then((_) => _loadChats());
      }
    });
  }

  String _getOtherParticipantName(Map<String, dynamic> chat) {
    final myId = context.read<AuthProvider>().user?.id;
    final participants = chat.asListOrNull('participants') ?? [];
    for (final p in participants) {
      if (p is Map && (p as Map<String, dynamic>)['_id'] != myId) {
        final name = (p as Map<String, dynamic>).asString('name', '');
        // If name is default or empty, show handle instead
        if (name.isEmpty || name == 'Nearfo User') {
          final handle = (p as Map<String, dynamic>).asString('handle', '');
          return handle.isNotEmpty ? '@$handle' : 'Unknown';
        }
        return name;
      }
    }
    return chat.asString('groupName', 'Chat');
  }

  String _getOtherParticipantId(Map<String, dynamic> chat) {
    final myId = context.read<AuthProvider>().user?.id;
    final participants = chat.asListOrNull('participants') ?? [];
    for (final p in participants) {
      if (p is Map && (p as Map<String, dynamic>)['_id'] != myId) {
        return (p as Map<String, dynamic>).asString('_id', '');
      }
    }
    return '';
  }

  String? _getOtherParticipantHandle(Map<String, dynamic> chat) {
    final myId = context.read<AuthProvider>().user?.id;
    final participants = chat.asListOrNull('participants') ?? [];
    for (final p in participants) {
      if (p is Map && (p as Map<String, dynamic>)['_id'] != myId) {
        return (p as Map<String, dynamic>).asStringOrNull('handle');
      }
    }
    return null;
  }

  String? _getOtherParticipantAvatar(Map<String, dynamic> chat) {
    final myId = context.read<AuthProvider>().user?.id;
    final participants = chat.asListOrNull('participants') ?? [];
    for (final p in participants) {
      if (p is Map && (p as Map<String, dynamic>)['_id'] != myId) {
        final avatar = (p as Map<String, dynamic>).asStringOrNull('avatarUrl');
        return (avatar != null && avatar.isNotEmpty) ? avatar : null;
      }
    }
    return null;
  }

  bool _isOtherParticipantOnline(Map<String, dynamic> chat) {
    final myId = context.read<AuthProvider>().user?.id;
    final participants = chat.asListOrNull('participants') ?? [];
    for (final p in participants) {
      if (p is Map && (p as Map<String, dynamic>)['_id'] != myId) {
        return (p as Map<String, dynamic>)['isOnline'] == true;
      }
    }
    return false;
  }

  String _getLastSeenText(Map<String, dynamic> chat) {
    final myId = context.read<AuthProvider>().user?.id;
    final participants = chat.asListOrNull('participants') ?? [];
    for (final p in participants) {
      if (p is Map && (p as Map<String, dynamic>)['_id'] != myId) {
        if ((p as Map<String, dynamic>)['isOnline'] == true) return 'Online';
        final lastSeen = (p as Map<String, dynamic>).asStringOrNull('lastSeen');
        if (lastSeen == null) return '';
        final dt = DateTime.tryParse(lastSeen)?.toLocal();
        if (dt == null) return '';
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inDays < 7) return '${diff.inDays}d ago';
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    }
    return '';
  }

  String _getInitials(String name) {
    return name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
  }

  Widget _buildChatAvatar({
    required Map<String, dynamic> chat,
    required String name,
    required bool isGroup,
    required bool isOnline,
  }) {
    final avatar = isGroup ? null : _getOtherParticipantAvatar(chat);
    final recipientId = isGroup ? '' : _getOtherParticipantId(chat);
    final hasStory = _usersWithStories.contains(recipientId);

    return Stack(
      children: [
        // Story ring container
        Container(
          width: 56,
          height: 56,
          decoration: hasStory
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [NearfoColors.primary, NearfoColors.accent, Colors.pinkAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          padding: hasStory ? const EdgeInsets.all(2.5) : EdgeInsets.zero,
          child: Container(
            decoration: hasStory
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: NearfoColors.bg, width: 2),
                  )
                : null,
            child: CircleAvatar(
              radius: hasStory ? 22 : 26,
              backgroundColor: isGroup ? NearfoColors.accent : NearfoColors.primary.withOpacity(0.2),
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar))
                  : null,
              child: avatar != null && avatar.isNotEmpty
                  ? null
                  : isGroup
                      ? const Icon(Icons.group, color: Colors.white, size: 22)
                      : Text(
                          _getInitials(name),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: NearfoColors.primary,
                            fontSize: hasStory ? 14 : 16,
                          ),
                        ),
            ),
          ),
        ),
        // Online indicator
        if (isOnline)
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: NearfoColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: NearfoColors.bg, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  void _showChatOptions(Map<String, dynamic> chat, String name) {
    final chatId = chat.asString('_id', '');
    if (chatId.isEmpty) return;

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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: NearfoColors.text),
                ),
              ),
              const SizedBox(height: 12),
              // Pin chat
              ListTile(
                leading: Icon(
                  _pinnedChatIds.contains(chatId) ? Icons.push_pin : Icons.push_pin_outlined,
                  color: NearfoColors.primary,
                ),
                title: Text(
                  _pinnedChatIds.contains(chatId) ? 'Unpin chat' : 'Pin chat',
                  style: TextStyle(color: NearfoColors.text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (_pinnedChatIds.contains(chatId)) {
                      _pinnedChatIds.remove(chatId);
                    } else {
                      _pinnedChatIds.add(chatId);
                    }
                  });
                  _filterChats(_searchController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_pinnedChatIds.contains(chatId) ? 'Chat pinned' : 'Chat unpinned'),
                      backgroundColor: NearfoColors.primary,
                    ),
                  );
                },
              ),
              // Mute
              ListTile(
                leading: Icon(
                  _mutedChatIds.contains(chatId) ? Icons.notifications : Icons.notifications_off_outlined,
                  color: NearfoColors.textMuted,
                ),
                title: Text(
                  _mutedChatIds.contains(chatId) ? 'Unmute notifications' : 'Mute notifications',
                  style: TextStyle(color: NearfoColors.text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final willMute = !_mutedChatIds.contains(chatId);
                  setState(() {
                    if (willMute) {
                      _mutedChatIds.add(chatId);
                    } else {
                      _mutedChatIds.remove(chatId);
                    }
                  });
                  unawaited(ApiService.updateChatSettings(chatId: chatId, settings: {'isMuted': willMute}));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(willMute ? 'Notifications muted' : 'Notifications unmuted'),
                      backgroundColor: NearfoColors.primary,
                    ),
                  );
                },
              ),
              // Archive
              ListTile(
                leading: Icon(Icons.archive_outlined, color: NearfoColors.warning),
                title: Text('Archive chat', style: TextStyle(color: NearfoColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _archivedChatIds.add(chatId);
                  });
                  _filterChats(_searchController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Chat archived'),
                      backgroundColor: NearfoColors.primary,
                      action: SnackBarAction(
                        label: 'Undo',
                        textColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            _archivedChatIds.remove(chatId);
                          });
                          _filterChats(_searchController.text);
                        },
                      ),
                    ),
                  );
                },
              ),
              // Delete
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Delete conversation', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: NearfoColors.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        'Delete conversation?',
                        style: TextStyle(fontWeight: FontWeight.w700, color: NearfoColors.text),
                      ),
                      content: Text(
                        'This will permanently delete the entire conversation with $name. This action cannot be undone.',
                        style: TextStyle(color: NearfoColors.textMuted),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final res = await ApiService.deleteChat(chatId);
                    if (res.isSuccess && mounted) {
                      setState(() {
                        _chats.removeWhere((c) => c.asString('_id', '') == chatId);
                        _filteredChats.removeWhere((c) => c.asString('_id', '') == chatId);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.chatConversationDeleted), backgroundColor: NearfoColors.success),
                      );
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => NearfoColors.primaryGradient.createShader(bounds),
                  child: Text(context.l10n.chatTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openNewChatSearch,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: NearfoColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: NearfoColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: NearfoColors.accent.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: NearfoColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NearfoColors.primary.withOpacity(0.15)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [NearfoColors.primary.withOpacity(0.02), NearfoColors.accent.withOpacity(0.02)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: NearfoColors.primary.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: NearfoColors.textDim, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterChats,
                      style: TextStyle(color: NearfoColors.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.l10n.chatSearchConversations,
                        hintStyle: TextStyle(color: NearfoColors.textDim, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _filterChats('');
                      },
                      child: Icon(Icons.close, color: NearfoColors.textDim, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Divider(color: NearfoColors.border, height: 1),

          // Chat list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
                : _filteredChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: NearfoColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline, size: 48, color: NearfoColors.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(context.l10n.chatNoConversations, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(context.l10n.chatStartChatting, style: TextStyle(color: NearfoColors.textDim)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadChats,
                        color: NearfoColors.primary,
                        backgroundColor: NearfoColors.card,
                        child: ListView.builder(
                          itemCount: _filteredChats.length,
                          itemBuilder: (ctx, i) {
                            final chat = _filteredChats[i];
                            final chatId = chat.asString('_id', '');
                            final isGroup = chat['isGroup'] == true;
                            final name = isGroup
                                ? chat.asString('groupName', 'Group')
                                : _getOtherParticipantName(chat);
                            final lastMessage = chat.asString('lastMessage', '');
                            final lastMessageAt = chat.asStringOrNull('lastMessageAt');
                            final unread = (chat['unreadCount'] as num?) ?? 0;
                            final isOnline = !isGroup && _isOtherParticipantOnline(chat);
                            final lastSeenText = !isGroup ? _getLastSeenText(chat) : '';

                            return GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, NearfoRoutes.chatDetail, arguments: {
                                  'recipientId': isGroup ? '' : _getOtherParticipantId(chat),
                                  'recipientName': name,
                                  'recipientHandle': isGroup ? null : _getOtherParticipantHandle(chat),
                                  'recipientAvatar': isGroup ? null : _getOtherParticipantAvatar(chat),
                                  'isOnline': isOnline,
                                  'lastSeenText': lastSeenText,
                                  'existingChatId': isGroup ? chatId : null,
                                  'isGroup': isGroup,
                                }).then((_) => _loadChats());
                              },
                              onLongPress: () => _showChatOptions(chat, name),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: unread > 0 ? NearfoColors.primary.withOpacity(0.05) : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: NearfoColors.border.withOpacity(0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  boxShadow: unread > 0
                                      ? [
                                          BoxShadow(
                                            color: NearfoColors.primary.withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    _buildChatAvatar(
                                      chat: chat,
                                      name: name,
                                      isGroup: isGroup,
                                      isOnline: isOnline,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: TextStyle(
                                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 15,
                                          )),
                                          const SizedBox(height: 4),
                                          Text(
                                            lastMessage.isNotEmpty ? lastMessage : context.l10n.chatNoMessages,
                                            style: TextStyle(
                                              color: unread > 0 ? NearfoColors.text : NearfoColors.textMuted,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // Last seen text
                                          if (!isGroup && !isOnline && lastSeenText.isNotEmpty && lastSeenText != 'Online')
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                lastSeenText,
                                                style: TextStyle(color: NearfoColors.textDim, fontSize: 11),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(_formatTime(lastMessageAt), style: TextStyle(
                                          color: unread > 0 ? NearfoColors.primary : NearfoColors.textDim,
                                          fontSize: 12,
                                        )),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_pinnedChatIds.contains(chatId))
                                              Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: Icon(Icons.push_pin, size: 14, color: NearfoColors.primary),
                                              ),
                                            if (_mutedChatIds.contains(chatId))
                                              Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: Icon(Icons.notifications_off, size: 14, color: NearfoColors.textDim),
                                              ),
                                            if (unread > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [NearfoColors.primary, NearfoColors.accent],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: NearfoColors.primary.withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ===== New Chat Search Bottom Sheet =====
class _NewChatSearchSheet extends StatefulWidget {
  const _NewChatSearchSheet();
  @override
  State<_NewChatSearchSheet> createState() => _NewChatSearchSheetState();
}

class _NewChatSearchSheetState extends State<_NewChatSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final res = await ApiService.searchUsers(query);
    if (mounted) {
      setState(() {
        _isSearching = false;
        _results = res.isSuccess && res.data != null ? res.data! : [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NearfoColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(context.l10n.chatNewMessage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: NearfoColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NearfoColors.border),
                ),
                child: Row(
                  children: [
                    Text('To: ', style: TextStyle(color: NearfoColors.textDim, fontSize: 14, fontWeight: FontWeight.w600)),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: _onSearchChanged,
                        autofocus: true,
                        style: TextStyle(color: NearfoColors.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: context.l10n.chatSearchByName,
                          hintStyle: TextStyle(color: NearfoColors.textDim, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: NearfoColors.border, height: 1),
            // Results
            Expanded(
              child: _isSearching
                  ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.length < 2
                                ? context.l10n.chatTypeNameToSearch
                                : context.l10n.chatNoUsersFound,
                            style: TextStyle(color: NearfoColors.textDim),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final user = _results[i];
                            final name = user.asString('name', '');
                            final handle = user.asString('handle', '');
                            final avatar = user.asStringOrNull('avatarUrl');
                            final isOnline = user['isOnline'] == true;
                            final displayName = (name.isNotEmpty && name != 'Nearfo User') ? name : '@$handle';
                            final initials = displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

                            return ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: NearfoColors.primary,
                                    backgroundImage: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                                    child: avatar == null || avatar.isEmpty
                                        ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                                        : null,
                                  ),
                                  if (isOnline)
                                    Positioned(
                                      bottom: 0, right: 0,
                                      child: Container(
                                        width: 12, height: 12,
                                        decoration: BoxDecoration(
                                          color: NearfoColors.success,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: NearfoColors.card, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(displayName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              subtitle: handle.isNotEmpty ? Text('@$handle', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)) : null,
                              onTap: () => Navigator.pop(context, user),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
