import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    final res = await ApiService.getAnalytics();
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() {
        _analytics = res.data;
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
        title: Text(context.l10n.analyticsTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: NearfoColors.textMuted),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _analytics == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 48, color: NearfoColors.textDim),
                      const SizedBox(height: 12),
                      Text(context.l10n.couldNotLoadAnalytics, style: TextStyle(color: NearfoColors.textMuted)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadAnalytics, child: Text(context.l10n.retryBtn, style: TextStyle(color: NearfoColors.primary))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  color: NearfoColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nearfo Score Card
                        _buildScoreCard(),
                        const SizedBox(height: 20),

                        // Main Stats
                        Text(context.l10n.overviewLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _statCard(context.l10n.postsLabel, '${_analytics!['totalPosts'] ?? 0}', Icons.article_rounded, NearfoColors.primary)),
                            const SizedBox(width: 10),
                            Expanded(child: _statCard(context.l10n.reelsLabel, '${_analytics!['totalReels'] ?? 0}', Icons.video_library_rounded, NearfoColors.accent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _statCard(context.l10n.followersLabel, '${_analytics!['followersCount'] ?? 0}', Icons.people_rounded, NearfoColors.success)),
                            const SizedBox(width: 10),
                            Expanded(child: _statCard(context.l10n.followingLabel, '${_analytics!['followingCount'] ?? 0}', Icons.person_add_rounded, NearfoColors.primaryLight)),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Engagement
                        Text(context.l10n.engagementLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _statCard(context.l10n.totalLikesLabel, '${_analytics!['totalLikes'] ?? 0}', Icons.favorite_rounded, NearfoColors.pink)),
                            const SizedBox(width: 10),
                            Expanded(child: _statCard(context.l10n.reelViewsLabel, '${_analytics!['totalReelViews'] ?? 0}', Icons.visibility_rounded, NearfoColors.accent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _statCard(context.l10n.commentsLabel, '${_analytics!['totalComments'] ?? 0}', Icons.chat_bubble_rounded, NearfoColors.primaryLight)),
                            const SizedBox(width: 10),
                            Expanded(child: _statCard(context.l10n.engagementRateLabel, '${_analytics!['engagementRate'] ?? 0}%', Icons.trending_up_rounded, NearfoColors.success)),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // This Week
                        Text(context.l10n.thisWeekLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _weeklyCard(),

                        const SizedBox(height: 24),

                        // Tips
                        _tipsCard(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildScoreCard() {
    final score = (_analytics!['nearfoScore'] as int?) ?? 0;
    String level;
    Color levelColor;
    if (score >= 80) {
      level = context.l10n.legendLevel;
      levelColor = NearfoColors.primaryLight;
    } else if (score >= 60) {
      level = context.l10n.starLevel;
      levelColor = NearfoColors.accent;
    } else if (score >= 40) {
      level = context.l10n.risingLevel;
      levelColor = NearfoColors.success;
    } else if (score >= 20) {
      level = context.l10n.activeLevel;
      levelColor = NearfoColors.primary;
    } else {
      level = context.l10n.newcomerLevel;
      levelColor = NearfoColors.textMuted;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NearfoColors.primary.withOpacity(0.15), NearfoColors.accent.withOpacity(0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NearfoColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(context.l10n.nearfoScoreLabel, style: TextStyle(color: NearfoColors.textMuted, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: NearfoColors.primaryLight),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(level, style: TextStyle(color: levelColor, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: NearfoColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(context.l10n.localInfluenceDesc, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _weeklyCard() {
    final postsThisWeek = (_analytics!['postsThisWeek'] as int?) ?? 0;
    final reelsThisWeek = (_analytics!['reelsThisWeek'] as int?) ?? 0;
    final recentFollowers = (_analytics!['recentFollowers'] as int?) ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NearfoColors.border),
      ),
      child: Column(
        children: [
          _weeklyRow(Icons.article_rounded, context.l10n.postsCreatedLabel, '$postsThisWeek', NearfoColors.primary),
          Divider(color: NearfoColors.border, height: 20),
          _weeklyRow(Icons.video_library_rounded, context.l10n.reelsUploadedLabel, '$reelsThisWeek', NearfoColors.accent),
          Divider(color: NearfoColors.border, height: 20),
          _weeklyRow(Icons.person_add_rounded, context.l10n.newFollowersLabel, '+$recentFollowers', NearfoColors.success),
        ],
      ),
    );
  }

  Widget _weeklyRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: NearfoColors.text))),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _tipsCard() {
    final score = (_analytics!['nearfoScore'] as int?) ?? 0;
    String tip;
    if (score < 20) {
      tip = context.l10n.tipScore0;
    } else if (score < 40) {
      tip = context.l10n.tipScore20;
    } else if (score < 60) {
      tip = context.l10n.tipScore40;
    } else if (score < 80) {
      tip = context.l10n.tipScore60;
    } else {
      tip = context.l10n.tipScore80;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NearfoColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NearfoColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_rounded, color: NearfoColors.primaryLight, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.tipToGrow, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: NearfoColors.primaryLight)),
                const SizedBox(height: 4),
                Text(tip, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NearfoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}
