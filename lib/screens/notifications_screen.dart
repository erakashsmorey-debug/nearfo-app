import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/cache_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/comments_sheet.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Real-time: auto-refresh when new notification arrives via socket
    _notifSub = SocketService.instance.onNewNotification.listen((_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    // Show cached notifications instantly on first load
    if (_isLoading && _notifications.isEmpty) {
      final cached = CacheService.getStale('notifications');
      if (cached != null && cached is Map) {
        try {
          final cachedData = Map<String, dynamic>.from(cached);
          final notifList = ((cachedData['notifications'] as List?) ?? [])
              .map((n) => NotificationModel.fromJson(Map<String, dynamic>.from((n as Map<dynamic, dynamic>))))
              .toList();
          if (mounted && notifList.isNotEmpty) {
            setState(() {
              _notifications = notifList;
              _unreadCount = ((cachedData['unreadCount'] as num?) ?? 0).toInt();
              _isLoading = false;
            });
          }
        } catch (_) {}
      }
    }

    if (_notifications.isEmpty) {
      setState(() => _isLoading = true);
    }

    // Always fetch fresh data
    try {
      final res = await ApiService.getNotifications();
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        setState(() {
          _notifications = res.data!.notifications;
          _unreadCount = res.data!.unreadCount;
        });
        // Cache fresh data
        CacheService.put('notifications', {
          'notifications': res.data!.notifications.map((n) => n.toJson()).toList(),
          'unreadCount': res.data!.unreadCount,
        }, maxAge: const Duration(minutes: 10));
      }
    } catch (e) {
      debugPrint('[Notifications] Load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _markAllRead() async {
    final res = await ApiService.markAllNotificationsRead();
    if (res.isSuccess) {
      setState(() {
        _unreadCount = 0;
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          sender: n.sender,
          type: n.type,
          postId: n.postId,
          postContent: n.postContent,
          reelId: n.reelId,
          isRead: true,
          createdAt: n.createdAt,
        )).toList();
      });
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
        title: Text(context.l10n.notificationsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(context.l10n.notificationsMarkAllRead, style: TextStyle(color: NearfoColors.primaryLight, fontSize: 13)),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Unread count badge
          if (_unreadCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: NearfoColors.primary.withOpacity(0.08),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: NearfoColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$_unreadCount new', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: NearfoColors.card,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_off_rounded, size: 48, color: NearfoColors.textDim),
                            ),
                            const SizedBox(height: 16),
                            Text(context.l10n.notificationsNone, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(context.l10n.notificationsNoneDesc,
                              style: TextStyle(color: NearfoColors.textMuted, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: NearfoColors.primary,
                        child: ListView.builder(
                          itemCount: _notifications.length + 1, // +1 for banner ad at top
                          itemBuilder: (ctx, i) {
                            // Show banner ad as the first item
                            if (i == 0) return const BannerAdWidget();
                            final notif = _notifications[i - 1];
                            return InkWell(
                              onTap: () => _onNotificationTap(notif),
                              child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: notif.isRead ? Colors.transparent : NearfoColors.primary.withOpacity(0.05),
                                border: Border(bottom: BorderSide(color: NearfoColors.border.withOpacity(0.5))),
                              ),
                              child: Row(
                                children: [
                                  // Avatar / Icon
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: _getNotifColor(notif.type).withOpacity(0.15),
                                    child: Text(notif.icon, style: const TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif.message,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                                            height: 1.4,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (notif.postContent != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.postContent!,
                                            style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(notif.timeAgo, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                                  if (!notif.isRead) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(color: NearfoColors.primary, shape: BoxShape.circle),
                                    ),
                                  ],
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
      ),
    );
  }

  void _onNotificationTap(NotificationModel notif) {
    // Mark as read via API (fire and forget)
    if (!notif.isRead) {
      unawaited(ApiService.markNotificationRead(notif.id));
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = NotificationModel(
            id: notif.id,
            sender: notif.sender,
            type: notif.type,
            postId: notif.postId,
            postContent: notif.postContent,
            reelId: notif.reelId,
            isRead: true,
            createdAt: notif.createdAt,
          );
          _unreadCount = (_unreadCount - 1).clamp(0, 9999);
        }
      });
    }

    // Navigate based on notification type
    switch (notif.type) {
      case 'follow':
        // Go to user profile
        if (notif.sender != null && notif.sender!.id.isNotEmpty) {
          Navigator.pushNamed(context, NearfoRoutes.userProfile, arguments: {
            'handle': notif.sender!.handle,
            'userId': notif.sender!.id,
          });
        }
        break;
      case 'like':
      case 'comment':
      case 'mention':
        // Navigate to the post/reel that was interacted with
        if (notif.isReel && notif.reelId != null && notif.reelId!.isNotEmpty) {
          // Open comments sheet for the reel
          CommentsSheet.show(context, postId: notif.reelId!, commentsCount: 0, isReel: true);
        } else if (notif.postId != null && notif.postId!.isNotEmpty) {
          // Open comments sheet for the post
          CommentsSheet.show(context, postId: notif.postId!, commentsCount: 0);
        } else if (notif.sender != null && notif.sender!.id.isNotEmpty) {
          // Fallback: go to sender's profile
          Navigator.pushNamed(context, NearfoRoutes.userProfile, arguments: {
            'handle': notif.sender!.handle,
            'userId': notif.sender!.id,
          });
        }
        break;
      case 'nearby':
        if (notif.sender != null && notif.sender!.id.isNotEmpty) {
          Navigator.pushNamed(context, NearfoRoutes.userProfile, arguments: {
            'handle': notif.sender!.handle,
            'userId': notif.sender!.id,
          });
        }
        break;
      default:
        break;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'like': return NearfoColors.danger;
      case 'comment': return NearfoColors.accent;
      case 'follow': return NearfoColors.primary;
      case 'mention': return NearfoColors.warning;
      case 'nearby': return NearfoColors.success;
      default: return NearfoColors.textMuted;
    }
  }
}
