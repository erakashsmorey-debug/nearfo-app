import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'call_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});
  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<Map<String, dynamic>> _callLogs = [];
  bool _loading = true;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory({bool refresh = false}) async {
    if (refresh) setState(() { _page = 1; _loading = true; });

    final res = await ApiService.getCallHistory(page: _page);
    if (res.isSuccess && res.data != null && mounted) {
      setState(() {
        if (refresh || _page == 1) {
          _callLogs = res.data!;
        } else {
          _callLogs.addAll(res.data!);
        }
        _hasMore = res.hasMore;
        _page++;
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCallTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return '';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return 'Missed';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        title: Text('Calls', style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.bold)),
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _loading && _callLogs.isEmpty
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _callLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_rounded, size: 64, color: NearfoColors.textDim.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No recent calls', style: TextStyle(color: NearfoColors.textDim, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Your call history will appear here', style: TextStyle(color: NearfoColors.textDim.withOpacity(0.5), fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadCallHistory(refresh: true),
                  child: ListView.builder(
                    itemCount: _callLogs.length,
                    itemBuilder: (context, index) {
                      final call = _callLogs[index];
                      final caller = (call['caller'] as Map<String, dynamic>?) ?? {};
                      final receiver = (call['receiver'] as Map<String, dynamic>?) ?? {};
                      final isOutgoing = caller['_id'] != null;
                      final other = isOutgoing ? receiver : caller;
                      final name = (other['name'] as String?)?.toString() ?? 'Unknown';
                      final handle = (other['handle'] as String?)?.toString() ?? '';
                      final avatar = (other['avatarUrl'] as String?)?.toString() ?? '';
                      final type = (call['type'] as String?)?.toString() ?? 'audio';
                      final status = (call['status'] as String?)?.toString() ?? 'missed';
                      final duration = (call['duration'] as int?) ?? 0;
                      final timeStr = _formatCallTime((call['createdAt'] as String?)?.toString());
                      final isMissed = status == 'missed' || status == 'declined';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: NearfoColors.card,
                          backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatar)) : null,
                          child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0] : '?',
                            style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.bold)) : null,
                        ),
                        title: Text(name, style: TextStyle(
                          color: isMissed ? NearfoColors.danger : NearfoColors.text,
                          fontWeight: FontWeight.w600,
                        )),
                        subtitle: Row(
                          children: [
                            Icon(
                              isOutgoing ? Icons.call_made : Icons.call_received,
                              size: 14,
                              color: isMissed ? NearfoColors.danger : NearfoColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isMissed ? 'Missed • $timeStr' : '${_formatDuration(duration)} • $timeStr',
                              style: TextStyle(color: NearfoColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            type == 'video' ? Icons.videocam : Icons.phone,
                            color: NearfoColors.primary,
                          ),
                          onPressed: () {
                            final otherId = (other['_id'] as String?)?.toString() ?? '';
                            if (otherId.isEmpty) return;
                            final myUser = context.read<AuthProvider>().user;
                            if (myUser == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CallScreen(
                                  recipientId: otherId,
                                  recipientName: name,
                                  recipientAvatar: avatar.isNotEmpty ? avatar : null,
                                  callerId: myUser.id,
                                  callerName: myUser.name,
                                  isVideo: type == 'video',
                                  isIncoming: false,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
