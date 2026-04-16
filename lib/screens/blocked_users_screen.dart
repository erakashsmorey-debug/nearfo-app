import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getBlockedUsers();
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() => _blockedUsers = res.data!);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _unblockUser(String userId, int index) async {
    final user = _blockedUsers[index];
    final name = ((user['name'] as String?) ?? 'this user');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.blockedUsersUnblockUser, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(context.l10n.blockedUsersUnblockDesc(name),
          style: TextStyle(color: NearfoColors.text, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.unblock, style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.toggleBlock(userId);
      if (res.isSuccess && mounted) {
        setState(() => _blockedUsers.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.blockedUsersUnblocked(name)), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.l10n.blockedUsersTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: NearfoColors.card, shape: BoxShape.circle),
                        child: Icon(Icons.block_rounded, size: 48, color: NearfoColors.textDim),
                      ),
                      const SizedBox(height: 16),
                      Text(context.l10n.blockedUsersNoBlocked, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(context.l10n.blockedUsersWillAppear,
                        style: TextStyle(color: NearfoColors.textMuted, fontSize: 14), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  color: NearfoColors.primary,
                  child: ListView.builder(
                    itemCount: _blockedUsers.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (ctx, i) {
                      final user = _blockedUsers[i];
                      final name = ((user['name'] as String?) ?? 'Unknown');
                      final handle = ((user['handle'] as String?) ?? '');
                      final avatar = (user['avatarUrl'] as String?);
                      final userId = (((user['_id'] as String?) ?? (user['id'] as String?)) ?? '');
                      final isVerified = (user['isVerified'] as bool?) == true;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: NearfoColors.card,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: NearfoColors.border,
                              backgroundImage: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                              child: avatar == null || avatar.isEmpty
                                  ? Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      if (isVerified) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.verified, color: NearfoColors.primary, size: 16),
                                      ],
                                    ],
                                  ),
                                  Text('@$handle', style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _unblockUser(userId, i),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: NearfoColors.textDim),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              ),
                              child: Text(context.l10n.unblock, style: TextStyle(color: NearfoColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
