import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/json_helpers.dart';
import 'chat_detail_screen.dart';
import '../l10n/l10n_helper.dart';

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getIncomingMessageRequests();
    if (res.isSuccess && res.data != null) {
      setState(() {
        _requests = res.data!;
        _requestCount = _requests.length;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _acceptRequest(int index) async {
    final request = _requests[index];
    final requestId = request.asStringOrNull('_id') ?? request.asStringOrNull('id') ?? '';

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: CircularProgressIndicator(color: NearfoColors.primary),
      ),
    );

    final res = await ApiService.acceptMessageRequest(requestId);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
    }

    if (res.isSuccess && res.data != null) {
      final sender = request['sender'];
      final senderName = sender is Map ? (sender as Map<String, dynamic>).asString('name', 'User') : 'User';
      final senderId = sender is Map ? ((sender as Map<String, dynamic>).asStringOrNull('_id') ?? (sender as Map<String, dynamic>).asStringOrNull('id') ?? '') : '';
      final senderAvatar =
          sender is Map ? ((sender as Map<String, dynamic>).asStringOrNull('avatar') ?? (sender as Map<String, dynamic>).asStringOrNull('profilePicture')) : null;

      if (mounted) {
        // Remove from list
        setState(() {
          _requests.removeAt(index);
          _requestCount = _requests.length;
        });

        // Navigate to chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              recipientId: senderId,
              recipientName: senderName,
              recipientAvatar: senderAvatar,
              isOnline: false,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? context.l10n.messageRequestsAcceptFailed),
            backgroundColor: NearfoColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(int index) async {
    final request = _requests[index];
    final requestId = request.asStringOrNull('_id') ?? request.asStringOrNull('id') ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.messageRequestsDeclineTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          context.l10n.messageRequestsDeclineDescription,
          style: TextStyle(color: NearfoColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.messageRequestsKeep, style: TextStyle(color: NearfoColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.messageRequestsDecline, style: TextStyle(color: NearfoColors.danger)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.declineMessageRequest(requestId);

    if (res.isSuccess) {
      if (mounted) {
        setState(() {
          _requests.removeAt(index);
          _requestCount = _requests.length;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.messageRequestsDeclineSuccess),
            backgroundColor: NearfoColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? context.l10n.messageRequestsDeclineFailed),
            backgroundColor: NearfoColors.danger,
          ),
        );
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
          icon: Icon(Icons.arrow_back_rounded, color: NearfoColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Text(
              context.l10n.messageRequestsTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: NearfoColors.text,
              ),
            ),
            if (_requestCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: NearfoColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _requestCount.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: NearfoColors.primary),
              )
            : _requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: NearfoColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            size: 56,
                            color: NearfoColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.messageRequestsNone,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: NearfoColors.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.l10n.messageRequestsDescription,
                          style: TextStyle(
                            fontSize: 14,
                            color: NearfoColors.textMuted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRequests,
                    color: NearfoColors.primary,
                    backgroundColor: NearfoColors.card,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) => Divider(
                        color: NearfoColors.border,
                        height: 1,
                        indent: 68,
                      ),
                      itemBuilder: (ctx, index) {
                        final request = _requests[index];
                        final sender = request['sender'];

                        final senderName = sender is Map
                            ? (sender as Map<String, dynamic>).asString('name', 'User')
                            : (sender as String?) ?? 'User';
                        final senderHandle = sender is Map
                            ? (sender as Map<String, dynamic>).asString('handle', '@user')
                            : '@user';
                        final senderAvatar = sender is Map
                            ? ((sender as Map<String, dynamic>).asStringOrNull('avatar') ?? (sender as Map<String, dynamic>).asStringOrNull('profilePicture'))
                            : null;

                        final message = request.asString('message', '');
                        final messagePreview = message.isNotEmpty
                            ? (message.length > 100
                                ? '${message.substring(0, 100)}...'
                                : message)
                            : 'Sent you a message';

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: NearfoColors.primary,
                                    child: senderAvatar != null
                                        ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: NearfoConfig.resolveMediaUrl(senderAvatar),
                                              fit: BoxFit.cover,
                                              width: 48,
                                              height: 48,
                                              errorWidget: (_, __, ___) =>
                                                  Text(
                                                senderName.isNotEmpty
                                                    ? senderName[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            senderName.isNotEmpty
                                                ? senderName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 14),

                                  // User info and message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                senderName,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: NearfoColors.text,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          senderHandle,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: NearfoColors.textDim,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: NearfoColors.card,
                                            border: Border.all(
                                              color: NearfoColors.border,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            messagePreview,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: NearfoColors.text,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Action buttons
                              Row(
                                children: [
                                  const SizedBox(width: 48), // Align with avatar
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _declineRequest(index),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: NearfoColors.card,
                                          border: Border.all(
                                            color: NearfoColors.border,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          context.l10n.messageRequestsDecline,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: NearfoColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _acceptRequest(index),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient:
                                              NearfoColors.primaryGradient,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          context.l10n.messageRequestsAccept,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
