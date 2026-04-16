import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? _groupData;
  bool _isLoading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = context.read<AuthProvider>().user?.id;
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getGroupInfo(widget.chatId);
    if (res.isSuccess && res.data != null && mounted) {
      setState(() {
        _groupData = res.data;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _isAdmin {
    if (_groupData == null || _myUserId == null) return false;
    final admin = _groupData!['groupAdmin'];
    if (admin is Map) return admin['_id']?.toString() == _myUserId;
    return admin?.toString() == _myUserId;
  }

  String get _groupNameDisplay {
    return _groupData?.asString('groupName', widget.groupName) ?? widget.groupName;
  }

  String get _groupDescription {
    return _groupData?.asString('groupDescription', '') ?? '';
  }

  List<Map<String, dynamic>> get _participants {
    final list = _groupData?['participants'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  String _getAdminId() {
    final admin = _groupData?['groupAdmin'];
    if (admin is Map) return admin['_id']?.toString() ?? '';
    return admin?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : CustomScrollView(
              slivers: [
                // App Bar with group avatar
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: NearfoColors.card,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: NearfoColors.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (_isAdmin)
                      IconButton(
                        icon: Icon(Icons.edit, color: NearfoColors.primary),
                        onPressed: _editGroupInfo,
                      ),
                  ],
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
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: NearfoColors.accent,
                            child: const Icon(Icons.group, color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _groupNameDisplay,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: NearfoColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.groupInfoMembersCount(count: _participants.length),
                            style: TextStyle(fontSize: 14, color: NearfoColors.textDim),
                          ),
                          if (_groupDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _groupDescription,
                                style: TextStyle(fontSize: 13, color: NearfoColors.textDim),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Quick Actions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_isAdmin)
                          _buildQuickAction(
                            icon: Icons.person_add_outlined,
                            label: context.l10n.groupInfoAdd,
                            onTap: _addMember,
                          ),
                        _buildQuickAction(
                          icon: Icons.notifications_outlined,
                          label: context.l10n.groupInfoMute,
                          onTap: _toggleMute,
                        ),
                        _buildQuickAction(
                          icon: Icons.search,
                          label: context.l10n.groupInfoSearch,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),

                // Members Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      context.l10n.groupInfoMembers,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: NearfoColors.text,
                      ),
                    ),
                  ),
                ),

                // Members List
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final member = _participants[index];
                      final memberId = member.asString('_id', '');
                      final isMe = memberId == _myUserId;
                      final isMemberAdmin = memberId == _getAdminId();
                      final name = member.asString('name', 'Unknown');
                      final handle = member.asString('handle', '');
                      final avatarUrl = member.asStringOrNull('avatarUrl');

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: NearfoColors.primary.withOpacity(0.2),
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatarUrl))
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                isMe ? '$name (You)' : name,
                                style: TextStyle(
                                  color: NearfoColors.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMemberAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: NearfoColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  context.l10n.groupInfoAdmin,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: NearfoColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: handle.isNotEmpty
                            ? Text('@$handle', style: TextStyle(color: NearfoColors.textDim, fontSize: 13))
                            : null,
                        trailing: (_isAdmin && !isMe)
                            ? IconButton(
                                icon: Icon(Icons.more_vert, color: NearfoColors.textDim),
                                onPressed: () => _showMemberOptions(member),
                              )
                            : null,
                        onTap: isMe
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  '/user-profile/$memberId',
                                  arguments: {'handle': handle, 'userId': memberId},
                                ),
                      );
                    },
                    childCount: _participants.length,
                  ),
                ),

                // Danger Zone
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Divider(color: NearfoColors.border, height: 1),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.exit_to_app, color: Colors.red, size: 22),
                        ),
                        title: Text(
                          context.l10n.groupInfoLeaveGroup,
                          style: const TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          context.l10n.groupInfoLeaveDescription,
                          style: TextStyle(color: NearfoColors.textDim, fontSize: 13),
                        ),
                        onTap: _leaveGroup,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

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

  // ───── ACTIONS ─────

  void _editGroupInfo() {
    final nameCtrl = TextEditingController(text: _groupNameDisplay);
    final descCtrl = TextEditingController(text: _groupDescription);

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.groupInfoEditGroup, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text)),
            const SizedBox(height: 20),
            Text(context.l10n.groupInfoGroupName, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(
                hintText: context.l10n.groupInfoGroupNameHint,
                hintStyle: TextStyle(color: NearfoColors.textDim),
                filled: true,
                fillColor: NearfoColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.groupInfoDescription, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: NearfoColors.text),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: context.l10n.groupInfoDescriptionHint,
                hintStyle: TextStyle(color: NearfoColors.textDim),
                filled: true,
                fillColor: NearfoColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.border)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final newName = nameCtrl.text.trim();
                  if (newName.isEmpty) return;
                  Navigator.pop(ctx);
                  final res = await ApiService.updateGroupChat(
                    chatId: widget.chatId,
                    groupName: newName,
                    groupDescription: descCtrl.text.trim(),
                  );
                  if (res.isSuccess) {
                    _loadGroupInfo(); // Refresh
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NearfoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.l10n.groupInfoSave, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addMember() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(context.l10n.groupInfoAddMembers, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text)),
                const SizedBox(height: 16),
                TextField(
                  controller: searchCtrl,
                  style: TextStyle(color: NearfoColors.text),
                  onChanged: (q) async {
                    if (q.length < 2) {
                      setSheetState(() => searchResults = []);
                      return;
                    }
                    setSheetState(() => searching = true);
                    final res = await ApiService.searchUsers(q);
                    if (ctx.mounted) {
                      setSheetState(() {
                        searching = false;
                        searchResults = res.isSuccess ? (res.data ?? []) : [];
                        // Filter out existing participants
                        final existingIds = _participants.map((p) => p.asString('_id', '')).toSet();
                        searchResults = searchResults.where((u) => !existingIds.contains(u.asString('_id', ''))).toList();
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: context.l10n.groupInfoSearchPeople,
                    hintStyle: TextStyle(color: NearfoColors.textDim),
                    filled: true,
                    fillColor: NearfoColors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.search, color: NearfoColors.textDim),
                    suffixIcon: searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (_, i) {
                      final user = searchResults[i];
                      final userId = user.asString('_id', '');
                      final userName = user.asString('name', '');
                      final userHandle = user.asString('handle', '');
                      final userAvatar = user.asStringOrNull('avatarUrl');
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (userAvatar ?? '').isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(userAvatar!)) : null,
                          backgroundColor: NearfoColors.primary.withOpacity(0.2),
                          child: (userAvatar ?? '').isEmpty ? Icon(Icons.person, color: NearfoColors.primary) : null,
                        ),
                        title: Text(userName, style: TextStyle(color: NearfoColors.text)),
                        subtitle: Text('@$userHandle', style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
                        trailing: IconButton(
                          icon: Icon(Icons.add_circle, color: NearfoColors.primary),
                          onPressed: () async {
                            final addRes = await ApiService.addGroupMember(widget.chatId, userId);
                            if (addRes.isSuccess) {
                              Navigator.pop(ctx);
                              _loadGroupInfo();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.l10n.groupInfoUserAdded(name: userName)), backgroundColor: NearfoColors.success),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final memberId = member.asString('_id', '');
    final memberName = member.asString('name', 'Unknown');

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
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(memberName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.person_outline, color: NearfoColors.text),
              title: Text(context.l10n.groupInfoViewProfile, style: TextStyle(color: NearfoColors.text)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/user-profile/$memberId',
                  arguments: {'handle': member.asString('handle', ''), 'userId': memberId},
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: Text(context.l10n.groupInfoRemoveFromGroup, style: const TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: NearfoColors.card,
                    title: Text(context.l10n.groupInfoRemoveConfirm(name: memberName), style: TextStyle(color: NearfoColors.text)),
                    content: Text(context.l10n.groupInfoRemoveDescription, style: TextStyle(color: NearfoColors.textDim)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.groupInfoCancel, style: TextStyle(color: NearfoColors.textDim))),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(context.l10n.groupInfoRemove, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final res = await ApiService.removeGroupMember(chatId: widget.chatId, userId: memberId);
                  if (res.isSuccess) {
                    _loadGroupInfo();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.groupInfoUserRemoved(name: memberName)), backgroundColor: NearfoColors.warning),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMute() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.groupInfoMuteToggled), backgroundColor: NearfoColors.primary),
    );
    unawaited(ApiService.updateChatSettings(
      chatId: widget.chatId,
      settings: {'isMuted': true},
    ));
  }

  void _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.groupInfoLeaveConfirm, style: TextStyle(color: NearfoColors.text)),
        content: Text(
          context.l10n.groupInfoLeaveWarning,
          style: TextStyle(color: NearfoColors.textDim),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.groupInfoCancel, style: TextStyle(color: NearfoColors.textDim))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.groupInfoLeave, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.leaveGroup(widget.chatId);
      if (res.isSuccess && mounted) {
        Navigator.pop(context, {'left': true});
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? context.l10n.groupInfoLeaveFailed), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }
}
