import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String? recipientHandle;
  final String? recipientAvatar;
  final bool isOnline;
  final bool isRestricted;

  const ChatSettingsScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    this.recipientHandle,
    this.recipientAvatar,
    this.isOnline = false,
    this.isRestricted = false,
  });

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _isMuted = false;
  bool _isRestricted = false;
  bool _isBlocked = false;
  String _disappearingMode = 'Off';
  String _selectedTheme = 'Default';
  String? _myNickname;
  String? _theirNickname;
  List<Map<String, dynamic>> _sharedMedia = [];
  bool _loadingMedia = false;
  bool _readReceipts = true;
  bool _showOnlineStatus = true;
  bool _hideOnlineFromThisUser = false;

  final List<Map<String, dynamic>> _chatThemes = [
    {'name': 'Default', 'color': Color(0xFF6C5CE7)},
    {'name': 'Ocean', 'color': Color(0xFF0984E3)},
    {'name': 'Sunset', 'color': Color(0xFFE17055)},
    {'name': 'Forest', 'color': Color(0xFF00B894)},
    {'name': 'Berry', 'color': Color(0xFFE84393)},
    {'name': 'Midnight', 'color': Color(0xFF2D3436)},
    {'name': 'Gold', 'color': Color(0xFFFDAA00)},
    {'name': 'Lavender', 'color': Color(0xFFA29BFE)},
  ];

  @override
  void initState() {
    super.initState();
    _isRestricted = widget.isRestricted;
    // Load global online status from user profile
    _showOnlineStatus = context.read<AuthProvider>().user?.showOnlineStatus ?? true;
    _loadChatSettings();
    _loadSharedMedia();
    _loadHideOnlineStatus();
  }

  Future<void> _loadChatSettings() async {
    try {
      final res = await ApiService.getChatSettings(widget.chatId);
      if (res.isSuccess && res.data != null) {
        if (mounted) {
          setState(() {
            _isMuted = res.data!.asBool('isMuted', false);
            _isBlocked = res.data!.asBool('isBlocked', false);
            _isRestricted = res.data!.asBool('isRestricted', _isRestricted);
            _disappearingMode = res.data!.asString('disappearingMode', 'Off');
            _selectedTheme = res.data!.asString('theme', 'Default');
            _myNickname = res.data!.asStringOrNull('myNickname');
            _theirNickname = res.data!.asStringOrNull('theirNickname');
          });
        }
      }
    } catch (e) {
      debugPrint('[ChatSettings] Load settings error: $e');
    }
  }

  Future<void> _loadHideOnlineStatus() async {
    try {
      final res = await ApiService.isOnlineHiddenFrom(widget.recipientId);
      if (res.isSuccess && res.data != null && mounted) {
        setState(() => _hideOnlineFromThisUser = res.data!);
      }
    } catch (_) {}
  }

  Future<void> _loadSharedMedia() async {
    setState(() => _loadingMedia = true);
    try {
      final res = await ApiService.getChatMedia(widget.chatId);
      if (res.isSuccess && res.data != null && mounted) {
        setState(() {
          _sharedMedia = List<Map<String, dynamic>>.from(res.data!);
          _loadingMedia = false;
        });
      } else {
        if (mounted) setState(() => _loadingMedia = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: CustomScrollView(
        slivers: [
          // Collapsing app bar with profile
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: NearfoColors.card,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: NearfoColors.text),
              onPressed: () => Navigator.pop(context, {
                'isRestricted': _isRestricted,
                'isBlocked': _isBlocked,
                'isMuted': _isMuted,
                'theme': _selectedTheme,
              }),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      NearfoColors.primary.withOpacity(0.15),
                      NearfoColors.bg,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Avatar
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: NearfoColors.primary.withOpacity(0.2),
                          child: widget.recipientAvatar != null
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: NearfoConfig.resolveMediaUrl(widget.recipientAvatar!),
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Icon(Icons.person, size: 48, color: NearfoColors.primary),
                                    errorWidget: (_, __, ___) => Icon(Icons.person, size: 48, color: NearfoColors.primary),
                                  ),
                                )
                              : Text(
                                  widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: NearfoColors.primary),
                                ),
                        ),
                        if (widget.isOnline)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: NearfoColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(color: NearfoColors.bg, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Name
                    Text(
                      _theirNickname ?? widget.recipientName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: NearfoColors.text,
                      ),
                    ),
                    if (widget.recipientHandle != null)
                      Text(
                        '@${widget.recipientHandle}',
                        style: TextStyle(fontSize: 14, color: NearfoColors.textDim),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Quick Actions Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickAction(
                    icon: Icons.person_outline,
                    label: context.l10n.chatSettingsProfile,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/user-profile/${widget.recipientId}',
                      arguments: {
                        'handle': widget.recipientHandle ?? '',
                        'userId': widget.recipientId,
                      },
                    ),
                  ),
                  _buildQuickAction(
                    icon: Icons.search,
                    label: context.l10n.chatSettingsSearch,
                    onTap: () => _showSearchMessages(),
                  ),
                  _buildQuickAction(
                    icon: _isMuted ? Icons.notifications_off : Icons.notifications_outlined,
                    label: _isMuted ? context.l10n.chatSettingsUnmute : context.l10n.chatSettingsMute,
                    onTap: _toggleMute,
                  ),
                ],
              ),
            ),
          ),

          // Settings List
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Theme ──
                _buildSettingsTile(
                  icon: Icons.palette_outlined,
                  iconColor: _chatThemes.firstWhere(
                    (t) => t['name'] == _selectedTheme,
                    orElse: () => _chatThemes[0],
                  )['color'] as Color,
                  title: context.l10n.chatSettingsTheme,
                  subtitle: _selectedTheme,
                  onTap: _showThemePicker,
                ),

                // ── Nicknames ──
                _buildSettingsTile(
                  icon: Icons.text_fields_rounded,
                  iconColor: NearfoColors.primary,
                  title: context.l10n.chatSettingsNicknames,
                  subtitle: _myNickname != null || _theirNickname != null
                      ? context.l10n.chatSettingsNicknamesSet
                      : context.l10n.chatSettingsSetNicknames,
                  onTap: _showNicknameEditor,
                ),

                // ── Disappearing Messages ──
                _buildSettingsTile(
                  icon: Icons.timer_outlined,
                  iconColor: _disappearingMode != context.l10n.chatSettingsDisappearingOff
                      ? NearfoColors.success
                      : NearfoColors.textMuted,
                  title: context.l10n.chatSettingsDisappearing,
                  subtitle: _disappearingMode,
                  onTap: _showDisappearingOptions,
                ),

                // ── Privacy and Safety ──
                _buildSettingsTile(
                  icon: Icons.lock_outline,
                  iconColor: NearfoColors.textMuted,
                  title: context.l10n.chatSettingsPrivacy,
                  subtitle: context.l10n.chatSettingsPrivacySubtitle,
                  onTap: _showPrivacyOptions,
                ),

                // ── Create Group Chat ──
                _buildSettingsTile(
                  icon: Icons.group_add_outlined,
                  iconColor: NearfoColors.primary,
                  title: context.l10n.chatSettingsCreateGroup,
                  subtitle: context.l10n.chatSettingsCreateGroupWith(name: widget.recipientName),
                  onTap: _createGroupWithUser,
                ),

                const SizedBox(height: 12),
                Divider(color: NearfoColors.border, height: 1),
                const SizedBox(height: 12),

                // ── Shared Media ──
                _buildMediaSection(),

                const SizedBox(height: 12),
                Divider(color: NearfoColors.border, height: 1),
                const SizedBox(height: 12),

                // ── Danger Zone ──
                _buildDangerTile(
                  icon: Icons.visibility_off_outlined,
                  title: _isRestricted ? context.l10n.chatSettingsUnrestrict : context.l10n.chatSettingsRestrict,
                  subtitle: _isRestricted
                      ? context.l10n.chatSettingsRestrictedUser(name: widget.recipientName)
                      : context.l10n.chatSettingsRestrictMessage,
                  color: NearfoColors.warning,
                  onTap: _toggleRestriction,
                ),
                _buildDangerTile(
                  icon: Icons.block,
                  title: _isBlocked ? context.l10n.chatSettingsUnblock : context.l10n.chatSettingsBlock,
                  subtitle: _isBlocked
                      ? context.l10n.chatSettingsBlockedUser(name: widget.recipientName)
                      : context.l10n.chatSettingsBlockMessage,
                  color: NearfoColors.danger,
                  onTap: _toggleBlock,
                ),
                _buildDangerTile(
                  icon: Icons.flag_outlined,
                  title: context.l10n.chatSettingsReport,
                  subtitle: context.l10n.chatSettingsReportMessage,
                  color: Colors.red,
                  onTap: _reportUser,
                ),

                const SizedBox(height: 12),
                Divider(color: NearfoColors.border, height: 1),
                const SizedBox(height: 12),

                // ── Delete Chat ──
                _buildDangerTile(
                  icon: Icons.delete_outline,
                  title: context.l10n.chatSettingsDelete,
                  subtitle: context.l10n.chatSettingsDeleteMessage,
                  color: Colors.red,
                  onTap: _deleteChat,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── WIDGETS ─────────────────────────

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: NearfoColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: NearfoColors.border),
            ),
            child: Icon(icon, color: NearfoColors.text, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: NearfoColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: NearfoColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: NearfoColors.textDim, fontSize: 13),
      ),
      trailing: Icon(Icons.chevron_right, color: NearfoColors.textDim),
      onTap: onTap,
    );
  }

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: NearfoColors.textDim, fontSize: 13),
      ),
      onTap: onTap,
    );
  }

  Widget _buildMediaSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.chatSettingsPhotosAndVideos,
                style: TextStyle(
                  color: NearfoColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_sharedMedia.isNotEmpty)
                TextButton(
                  onPressed: _viewAllMedia,
                  child: Text(
                    context.l10n.chatSettingsSeeAll,
                    style: TextStyle(color: NearfoColors.primary, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _loadingMedia
              ? Center(child: CircularProgressIndicator(color: NearfoColors.primary, strokeWidth: 2))
              : _sharedMedia.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.photo_library_outlined, color: NearfoColors.textDim, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.chatSettingsNoPhotosOrVideos,
                              style: TextStyle(color: NearfoColors.textDim, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _sharedMedia.length > 10 ? 10 : _sharedMedia.length,
                        itemBuilder: (context, index) {
                          final media = _sharedMedia[index];
                          final mediaUrl = media.asString('mediaUrl', '');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    mediaUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: NearfoConfig.resolveMediaUrl(mediaUrl),
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: NearfoColors.card),
                                      errorWidget: (_, __, ___) => Container(
                                        color: NearfoColors.card,
                                        child: Icon(Icons.broken_image, color: NearfoColors.textDim),
                                      ),
                                    )
                                    : Container(
                                        color: NearfoColors.card,
                                        child: Icon(
                                          media['type'] == 'video' ? Icons.videocam : Icons.image,
                                          color: NearfoColors.textDim,
                                        ),
                                      ),
                                    if (media['type'] == 'video')
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  // ───────────────────────── ACTIONS ─────────────────────────

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.chatSettingsChatTheme,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _chatThemes.map((theme) {
                final themeName = (theme as Map<String, dynamic>).asString('name', '');
                final isSelected = _selectedTheme == themeName;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedTheme = themeName);
                    unawaited(ApiService.updateChatSettings(
                      chatId: widget.chatId,
                      settings: {'theme': themeName},
                    ));
                    Navigator.pop(ctx);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme['color'] as Color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: (theme['color'] as Color).withOpacity(0.5), blurRadius: 12)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 28)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        themeName,
                        style: TextStyle(
                          color: isSelected ? NearfoColors.text : NearfoColors.textDim,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showNicknameEditor() {
    final myController = TextEditingController(text: _myNickname ?? '');
    final theirController = TextEditingController(text: _theirNickname ?? '');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.chatSettingsNicknames,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text),
            ),
            const SizedBox(height: 20),
            Text(context.l10n.chatSettingsYourNickname, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: myController,
              style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(
                hintText: context.l10n.chatSettingsYourNicknameHint,
                hintStyle: TextStyle(color: NearfoColors.textDim),
                filled: true,
                fillColor: NearfoColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: NearfoColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: NearfoColors.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.chatSettingsTheirNickname(name: widget.recipientName),
              style: TextStyle(color: NearfoColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: theirController,
              style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(
                hintText: context.l10n.chatSettingsTheirNicknameHint,
                hintStyle: TextStyle(color: NearfoColors.textDim),
                filled: true,
                fillColor: NearfoColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: NearfoColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: NearfoColors.border),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final myNick = myController.text.trim();
                  final theirNick = theirController.text.trim();
                  setState(() {
                    _myNickname = myNick.isNotEmpty ? myNick : null;
                    _theirNickname = theirNick.isNotEmpty ? theirNick : null;
                  });
                  unawaited(ApiService.updateChatSettings(
                    chatId: widget.chatId,
                    settings: {
                      'myNickname': _myNickname,
                      'theirNickname': _theirNickname,
                    },
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NearfoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.l10n.chatSettingsSave, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      myController.dispose();
      theirController.dispose();
    });
  }

  void _showDisappearingOptions() {
    final options = [
      context.l10n.chatSettingsDisappearingOff,
      context.l10n.chatSettingsDisappearing24hours,
      context.l10n.chatSettingsDisappearing7days,
      context.l10n.chatSettingsDisappearing90days,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.chatSettingsDisappearing,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.chatSettingsDisappearingDescription,
              style: TextStyle(color: NearfoColors.textDim, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...options.map((option) => RadioListTile<String>(
                  value: option,
                  groupValue: _disappearingMode,
                  activeColor: NearfoColors.primary,
                  title: Text(option, style: TextStyle(color: NearfoColors.text)),
                  onChanged: (val) {
                    setState(() => _disappearingMode = val!);
                    unawaited(ApiService.updateChatSettings(
                      chatId: widget.chatId,
                      settings: {'disappearingMode': val},
                    ));
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPrivacyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.lock, color: NearfoColors.success),
              title: Text(context.l10n.chatSettingsEncrypted, style: TextStyle(color: NearfoColors.text)),
              subtitle: Text(
                context.l10n.chatSettingsEncryptedMessage,
                style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
              ),
            ),
            ListTile(
              leading: Icon(Icons.read_more, color: NearfoColors.primary),
              title: Text(context.l10n.chatSettingsReadReceipts, style: TextStyle(color: NearfoColors.text)),
              subtitle: Text(
                context.l10n.chatSettingsReadReceiptsMessage,
                style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
              ),
              trailing: Switch(
                value: _readReceipts,
                onChanged: (val) {
                  setState(() => _readReceipts = val);
                  setSheetState(() {});
                  unawaited(ApiService.updateChatSettings(
                    chatId: widget.chatId,
                    settings: {'readReceipts': val},
                  ));
                },
                activeColor: NearfoColors.primary,
              ),
            ),
            ListTile(
              leading: Icon(
                _showOnlineStatus ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: _showOnlineStatus ? NearfoColors.success : NearfoColors.textDim,
                size: 20,
              ),
              title: Text(context.l10n.chatSettingsOnlineStatus, style: TextStyle(color: NearfoColors.text)),
              subtitle: Text(
                _showOnlineStatus ? context.l10n.chatSettingsVisibleToEveryone : context.l10n.chatSettingsAppearOffline,
                style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
              ),
              trailing: Switch(
                value: _showOnlineStatus,
                onChanged: (val) async {
                  setState(() => _showOnlineStatus = val);
                  setSheetState(() {});
                  // Update global profile (not just per-chat)
                  final auth = context.read<AuthProvider>();
                  final success = await auth.updateProfile({'showOnlineStatus': val});
                  if (success && mounted) {
                    SocketService.instance.toggleOnlineVisibility(
                      userId: auth.user?.id ?? '',
                      visible: val,
                    );
                  } else if (mounted) {
                    // Revert on failure
                    setState(() => _showOnlineStatus = !val);
                    setSheetState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.chatSettingsOnlineStatusFailed),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                activeColor: NearfoColors.primary,
              ),
            ),
            ListTile(
              leading: Icon(
                _hideOnlineFromThisUser ? Icons.person_off_rounded : Icons.person_rounded,
                color: _hideOnlineFromThisUser ? Colors.orange : NearfoColors.textDim,
                size: 20,
              ),
              title: Text('Hide online from ${widget.recipientName}', style: TextStyle(color: NearfoColors.text)),
              subtitle: Text(
                _hideOnlineFromThisUser
                    ? '${widget.recipientName} cannot see when you\'re online'
                    : '${widget.recipientName} can see your online status',
                style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
              ),
              trailing: Switch(
                value: _hideOnlineFromThisUser,
                onChanged: (val) async {
                  setState(() => _hideOnlineFromThisUser = val);
                  setSheetState(() {});
                  final res = await ApiService.toggleHideOnlineFrom(
                    targetUserId: widget.recipientId,
                    hide: val,
                  );
                  if (!res.isSuccess && mounted) {
                    setState(() => _hideOnlineFromThisUser = !val);
                    setSheetState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Failed to update visibility'),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                activeColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
          ],
          ),
        ),
      ),
      ),
    );
  }

  void _showSearchMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final searchController = TextEditingController();
        List<Map<String, dynamic>> results = [];
        bool searching = false;

        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  autofocus: true,
                  style: TextStyle(color: NearfoColors.text),
                  decoration: InputDecoration(
                    hintText: context.l10n.chatSettingsSearchMessages,
                    hintStyle: TextStyle(color: NearfoColors.textDim),
                    prefixIcon: Icon(Icons.search, color: NearfoColors.textDim),
                    filled: true,
                    fillColor: NearfoColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: NearfoColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: NearfoColors.border),
                    ),
                  ),
                  onChanged: (query) async {
                    if (query.length < 2) {
                      setSheetState(() => results = []);
                      return;
                    }
                    setSheetState(() => searching = true);
                    try {
                      final res = await ApiService.getChatMessages(widget.chatId, page: 1, limit: 200);
                      if (res.isSuccess && res.data != null) {
                        final messages = ((res.data!['messages'] as List?) ?? [])
                            .whereType<Map<String, dynamic>>()
                            .where((m) => (m['content']?.toString() ?? '').toLowerCase().contains(query.toLowerCase()))
                            .toList();
                        setSheetState(() { results = messages; searching = false; });
                      } else {
                        setSheetState(() => searching = false);
                      }
                    } catch (_) {
                      setSheetState(() => searching = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (searching)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: NearfoColors.primary, strokeWidth: 2),
                  )
                else if (results.isNotEmpty)
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final msg = results[index];
                        final sender = msg['sender'];
                        final senderName = (sender is Map ? sender['name']?.toString() : null) ?? 'Unknown';
                        return ListTile(
                          leading: Icon(Icons.chat_bubble_outline, color: NearfoColors.textDim, size: 20),
                          title: Text(
                            msg['content']?.toString() ?? '',
                            style: TextStyle(color: NearfoColors.text, fontSize: 14),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(senderName, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                          onTap: () => Navigator.pop(ctx),
                        );
                      },
                    ),
                  )
                else if (searchController.text.length >= 2)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('No messages found', style: TextStyle(color: NearfoColors.textDim)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await ApiService.updateChatSettings(
      chatId: widget.chatId,
      settings: {'isMuted': _isMuted},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isMuted ? 'Chat muted' : 'Chat unmuted'),
          backgroundColor: NearfoColors.primary,
        ),
      );
    }
  }

  Future<void> _toggleRestriction() async {
    final confirm = await _showConfirmDialog(
      title: _isRestricted ? 'Unrestrict ${widget.recipientName}?' : 'Restrict ${widget.recipientName}?',
      message: _isRestricted
          ? 'You will see their messages again.'
          : 'Their messages will be silently hidden. They won\'t know.',
      confirmText: _isRestricted ? 'Unrestrict' : 'Restrict',
      confirmColor: NearfoColors.warning,
    );
    if (!confirm) return;

    // Optimistic UI update — toggle restriction instantly
    final wasRestricted = _isRestricted;
    setState(() => _isRestricted = !_isRestricted);

    final res = await ApiService.toggleChatRestriction(
      chatId: widget.chatId,
      userId: widget.recipientId,
    );
    if (res.isSuccess && res.data != null) {
      final newRestricted = res.data!.asBool('isRestricted', false);
      if (newRestricted != _isRestricted && mounted) {
        setState(() => _isRestricted = newRestricted);
      }
      // Emit socket event so receiver's chat screen updates in real-time
      SocketService.instance.emit('user_restricted', {
        'chatId': widget.chatId,
        'restrictedBy': SocketService.instance.currentUserId,
        'targetUserId': widget.recipientId,
        'isRestricted': newRestricted,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isRestricted ? 'User restricted' : 'User unrestricted'),
            backgroundColor: _isRestricted ? NearfoColors.warning : NearfoColors.success,
          ),
        );
      }
    } else if (mounted) {
      // Revert optimistic update on failure
      setState(() => _isRestricted = wasRestricted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Failed to update restriction'),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  Future<void> _toggleBlock() async {
    final confirm = await _showConfirmDialog(
      title: _isBlocked ? 'Unblock ${widget.recipientName}?' : 'Block ${widget.recipientName}?',
      message: _isBlocked
          ? 'They will be able to contact you again.'
          : 'They won\'t be able to send you messages, calls, or see your status.',
      confirmText: _isBlocked ? 'Unblock' : 'Block',
      confirmColor: NearfoColors.danger,
    );
    if (!confirm) return;

    // Optimistic UI update — toggle block instantly
    final wasBlocked = _isBlocked;
    setState(() => _isBlocked = !_isBlocked);

    final res = await ApiService.toggleBlockUser(widget.recipientId);
    if (res.isSuccess) {
      // Emit socket event so receiver's chat screen updates in real-time
      SocketService.instance.emit('user_blocked', {
        'chatId': widget.chatId,
        'blockedBy': SocketService.instance.currentUserId,
        'targetUserId': widget.recipientId,
        'isBlocked': _isBlocked,
      });
    } else if (mounted) {
      // Revert optimistic update on failure
      setState(() => _isBlocked = wasBlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Failed to update block status'),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  void _reportUser() async {
    final reasons = [
      'Spam',
      'Harassment',
      'Inappropriate content',
      'Fake account',
      'Other',
    ];
    String? selected;

    await showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Report ${widget.recipientName}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ...reasons.map((reason) => ListTile(
                  title: Text(reason, style: TextStyle(color: NearfoColors.text)),
                  trailing: Icon(Icons.chevron_right, color: NearfoColors.textDim),
                  onTap: () {
                    selected = reason;
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );

    if (selected != null) {
      final res = await ApiService.reportContent(
        contentType: 'user',
        contentId: widget.recipientId,
        reason: selected!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.isSuccess
                ? 'Report submitted. We\'ll review it soon.'
                : res.errorMessage ?? 'Failed to submit report'),
            backgroundColor: res.isSuccess ? NearfoColors.success : NearfoColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _deleteChat() async {
    final confirm = await _showConfirmDialog(
      title: context.l10n.chatSettingsDeleteConfirm,
      message: context.l10n.chatSettingsDeleteConfirmMessage,
      confirmText: context.l10n.chatSettingsDelete,
      confirmColor: Colors.red,
    );
    if (!confirm) return;

    final res = await ApiService.deleteChat(widget.chatId);
    if (res.isSuccess && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chatSettingsChatDeleted),
          backgroundColor: NearfoColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? context.l10n.chatSettingsDeleteFailed),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  void _createGroupWithUser() {
    Navigator.pushNamed(context, '/create-group');
  }

  void _viewAllMedia() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.chatSettingsPhotosAndVideosCount(count: _sharedMedia.length),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text),
              ),
            ),
            Expanded(
              child: _sharedMedia.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, color: NearfoColors.textDim, size: 60),
                          const SizedBox(height: 12),
                          Text(context.l10n.chatSettingsNoMediaShared, style: TextStyle(color: NearfoColors.textDim, fontSize: 15)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _sharedMedia.length,
                      itemBuilder: (context, index) {
                        final media = _sharedMedia[index];
                        final mediaUrl = media['mediaUrl']?.toString() ?? '';
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: NearfoConfig.resolveMediaUrl(mediaUrl),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: NearfoColors.bg),
                                errorWidget: (_, __, ___) => Container(
                                  color: NearfoColors.bg,
                                  child: Icon(Icons.broken_image, color: NearfoColors.textDim),
                                ),
                              ),
                              if (media['type'] == 'video')
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: NearfoColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: NearfoColors.text)),
            content: Text(message, style: TextStyle(color: NearfoColors.textMuted)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: NearfoColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  confirmText,
                  style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
