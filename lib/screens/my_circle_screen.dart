import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class MyCircleScreen extends StatefulWidget {
  const MyCircleScreen({super.key});
  @override
  State<MyCircleScreen> createState() => _MyCircleScreenState();
}

class _MyCircleScreenState extends State<MyCircleScreen> {
  List<Map<String, dynamic>> _circle = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCircle();
  }

  Future<void> _loadCircle() async {
    setState(() => _loading = true);
    final res = await ApiService.getMyCircle();
    if (res.isSuccess && res.data != null) {
      setState(() {
        _circle = res.data!;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: NearfoColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.l10n.myCircleTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
        actions: [
          if (_circle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NearfoColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_circle.length}',
                    style: TextStyle(color: NearfoColors.success, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : RefreshIndicator(
              onRefresh: _loadCircle,
              color: NearfoColors.primary,
              child: _circle.isEmpty ? _buildEmpty() : _buildList(),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: NearfoColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people_rounded, size: 56, color: NearfoColors.success),
              ),
              const SizedBox(height: 24),
              Text(context.l10n.myCircleNoOne, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  context.l10n.myCircleDescription,
                  style: TextStyle(color: NearfoColors.textMuted, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, NearfoRoutes.discover),
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: Text(context.l10n.myCircleDiscover),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NearfoColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _circle.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [NearfoColors.success.withOpacity(0.1), NearfoColors.primary.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NearfoColors.success.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, color: NearfoColors.success, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.myCircleMutual(_circle.length),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(context.l10n.myCircleWhoFollowBack,
                            style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final user = _circle[index - 1];
        final isOnline = (user['isOnline'] as bool?) == true;
        final distance = ((user['distanceKm'] as int?) ?? 0);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: NearfoColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NearfoColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: NearfoColors.primary.withOpacity(0.2),
                  backgroundImage: user['avatarUrl'] != null && user['avatarUrl'].toString().isNotEmpty
                      ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(user['avatarUrl'] as String))
                      : null,
                  child: user['avatarUrl'] == null || user['avatarUrl'].toString().isEmpty
                      ? Text(
                          (((user['name'] as String?) ?? '?')[0]).toUpperCase(),
                          style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: NearfoColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: NearfoColors.card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    (user['name'] as String?) ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user['isVerified'] == true) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.verified, color: NearfoColors.primary, size: 16),
                ],
              ],
            ),
            subtitle: Row(
              children: [
                Text('@${((user['handle'] as String?) ?? '')}', style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                const SizedBox(width: 8),
                Icon(Icons.location_on, size: 12, color: NearfoColors.textDim),
                const SizedBox(width: 2),
                Text('${distance}km', style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: NearfoColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded, color: NearfoColors.success, size: 16),
                  const SizedBox(width: 4),
                  Text(context.l10n.myCircleMutualLabel, style: TextStyle(color: NearfoColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            onTap: () {
              if (user['handle'] != null) {
                Navigator.pushNamed(context, NearfoRoutes.userProfile, arguments: user['handle']);
              }
            },
          ),
        );
      },
    );
  }
}
