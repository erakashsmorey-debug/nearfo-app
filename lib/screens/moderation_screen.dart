import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

/// Admin Moderation Screen — Ban, Suspend, Takedown Review
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _bannedUsers = [];
  List<Map<String, dynamic>> _takedowns = [];
  bool _loadingBanned = true;
  bool _loadingTakedowns = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBanned();
    _loadTakedowns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBanned() async {
    final res = await ApiService.getBannedUsers();
    if (res.isSuccess && mounted) setState(() { _bannedUsers = res.data ?? []; _loadingBanned = false; });
    else if (mounted) setState(() => _loadingBanned = false);
  }

  Future<void> _loadTakedowns() async {
    final res = await ApiService.getTakedowns(status: 'pending');
    if (res.isSuccess && mounted) setState(() { _takedowns = res.data ?? []; _loadingTakedowns = false; });
    else if (mounted) setState(() => _loadingTakedowns = false);
  }

  void _showBanDialog() {
    final controller = TextEditingController();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.banUserTitle, style: TextStyle(color: NearfoColors.danger)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(hintText: 'User ID', hintStyle: TextStyle(color: NearfoColors.textDim),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.danger)),
              )),
            const SizedBox(height: 12),
            TextField(controller: reasonController, style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(hintText: 'Reason', hintStyle: TextStyle(color: NearfoColors.textDim),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.danger)),
              )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancelBtn, style: TextStyle(color: NearfoColors.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (controller.text.trim().isEmpty) return;
              final res = await ApiService.banUser(controller.text.trim(), reason: reasonController.text.trim());
              if (res.isSuccess && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.userBanned), backgroundColor: NearfoColors.danger));
                _loadBanned();
              }
            },
            child: Text(context.l10n.banBtn, style: TextStyle(color: NearfoColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      controller.dispose();
      reasonController.dispose();
    });
  }

  void _showSuspendDialog() {
    final controller = TextEditingController();
    final reasonController = TextEditingController();
    String duration = '168'; // 7 days default
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.suspendUserTitle, style: TextStyle(color: NearfoColors.warning)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(hintText: context.l10n.userIdHint, hintStyle: TextStyle(color: NearfoColors.textDim),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.warning)),
              )),
            const SizedBox(height: 12),
            TextField(controller: reasonController, style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(hintText: context.l10n.reasonHint, hintStyle: TextStyle(color: NearfoColors.textDim),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.warning)),
              )),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: duration,
              dropdownColor: NearfoColors.card,
              style: TextStyle(color: NearfoColors.text),
              decoration: InputDecoration(
                labelText: context.l10n.durationLabel,
                labelStyle: TextStyle(color: NearfoColors.textMuted),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: NearfoColors.border)),
              ),
              items: [
                DropdownMenuItem(value: '24', child: Text(context.l10n.duration24h)),
                DropdownMenuItem(value: '72', child: Text(context.l10n.duration3d)),
                DropdownMenuItem(value: '168', child: Text(context.l10n.duration7d)),
                DropdownMenuItem(value: '720', child: Text(context.l10n.duration30d)),
              ],
              onChanged: (v) => duration = v ?? '168',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancelBtn, style: TextStyle(color: NearfoColors.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (controller.text.trim().isEmpty) return;
              final res = await ApiService.suspendUser(controller.text.trim(), hours: int.parse(duration), reason: reasonController.text.trim());
              if (res.isSuccess && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.userSuspended), backgroundColor: NearfoColors.warning));
              }
            },
            child: Text(context.l10n.suspendBtn, style: TextStyle(color: NearfoColors.warning, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      controller.dispose();
      reasonController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        title: Text('Moderation', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: NearfoColors.text), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.person_off, color: NearfoColors.danger), onPressed: _showBanDialog, tooltip: 'Ban User'),
          IconButton(icon: Icon(Icons.timer_off, color: NearfoColors.warning), onPressed: _showSuspendDialog, tooltip: 'Suspend User'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NearfoColors.primary,
          labelColor: NearfoColors.primary,
          unselectedLabelColor: NearfoColors.textMuted,
          tabs: [
            Tab(text: 'Banned (${_bannedUsers.length})'),
            Tab(text: 'Takedowns (${_takedowns.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBannedTab(),
          _buildTakedownsTab(),
        ],
      ),
    );
  }

  Widget _buildBannedTab() {
    if (_loadingBanned) return Center(child: CircularProgressIndicator(color: NearfoColors.primary));
    if (_bannedUsers.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: NearfoColors.success),
          const SizedBox(height: 12),
          Text('No banned users', style: TextStyle(color: NearfoColors.textMuted)),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadBanned,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _bannedUsers.length,
        itemBuilder: (context, index) {
          final user = _bannedUsers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: NearfoColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: NearfoColors.border)),
            child: ListTile(
              title: Text(((user['name'] as String?) ?? (user['handle'] as String?)) ?? 'Unknown', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w600)),
              subtitle: Text((user['banReason'] as String?) ?? '', style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
              trailing: TextButton(
                onPressed: () async {
                  final id = user['_id']?.toString() ?? '';
                  final res = await ApiService.unbanUser(id);
                  if (res.isSuccess && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User unbanned'), backgroundColor: NearfoColors.success));
                    _loadBanned();
                  }
                },
                child: Text('Unban', style: TextStyle(color: NearfoColors.success)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTakedownsTab() {
    if (_loadingTakedowns) return Center(child: CircularProgressIndicator(color: NearfoColors.primary));
    if (_takedowns.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel_outlined, size: 48, color: NearfoColors.textDim),
          const SizedBox(height: 12),
          Text('No pending takedowns', style: TextStyle(color: NearfoColors.textMuted)),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadTakedowns,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _takedowns.length,
        itemBuilder: (context, index) {
          final td = _takedowns[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: NearfoColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: NearfoColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.copyright, size: 18, color: NearfoColors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${(td['complainantName'] as String?) ?? ''} (${(td['complainantEmail'] as String?) ?? ''})', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w600, fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Type: ${((td['contentType'] as String?) ?? '').toString().toUpperCase()}', style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text((td['description'] as String?) ?? '', style: TextStyle(color: NearfoColors.textMuted, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final id = td['_id']?.toString() ?? '';
                        final res = await ApiService.reviewTakedown(id, action: 'reject');
                        if (res.isSuccess && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Takedown rejected'), backgroundColor: NearfoColors.textMuted));
                          _loadTakedowns();
                        }
                      },
                      child: Text('Reject', style: TextStyle(color: NearfoColors.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final id = td['_id']?.toString() ?? '';
                        final res = await ApiService.reviewTakedown(id, action: 'approve');
                        if (res.isSuccess && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Takedown approved. Content removed.'), backgroundColor: NearfoColors.success));
                          _loadTakedowns();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: NearfoColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text('Approve & Remove', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
