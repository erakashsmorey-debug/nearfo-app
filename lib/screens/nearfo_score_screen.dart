import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class NearfoScoreScreen extends StatefulWidget {
  const NearfoScoreScreen({super.key});

  @override
  State<NearfoScoreScreen> createState() => _NearfoScoreScreenState();
}

class _NearfoScoreScreenState extends State<NearfoScoreScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  int _score = 0;
  Map<String, dynamic> _breakdown = {};
  Map<String, dynamic> _user = {};
  late AnimationController _animController;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scoreAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _loadScore();
  }

  Future<void> _loadScore() async {
    final res = await ApiService.getNearfoScore();
    if (res.isSuccess && res.data != null && mounted) {
      final data = res.data!;
      setState(() {
        _score = data.asInt('score');
        _breakdown = data.asMap('breakdown');
        _user = data.asMap('user');
        _loading = false;
        _scoreAnim = Tween<double>(begin: 0, end: _score.toDouble()).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
      });
      _animController.forward();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        title: Text(context.l10n.nearfoScoreTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : RefreshIndicator(
              onRefresh: _loadScore,
              color: NearfoColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildScoreCircle(),
                    const SizedBox(height: 28),
                    _buildScoreLabel(),
                    const SizedBox(height: 32),
                    _buildBreakdownSection(),
                    const SizedBox(height: 28),
                    _buildTipsCard(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScoreCircle() {
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (context, child) {
        final animValue = _scoreAnim.value;
        return Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NearfoColors.primary.withOpacity(0.15),
                NearfoColors.accent.withOpacity(0.15),
              ],
            ),
            border: Border.all(color: NearfoColors.primary.withOpacity(0.3), width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: animValue / 100,
                  strokeWidth: 10,
                  backgroundColor: NearfoColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getScoreColor(animValue.round()),
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        NearfoColors.primaryGradient.createShader(bounds),
                    child: Text(
                      '${animValue.round()}',
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 16,
                      color: NearfoColors.textDim,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreLabel() {
    String label;
    Color color;
    IconData icon;

    if (_score >= 80) {
      label = context.l10n.scoreLabel80;
      color = NearfoColors.success;
      icon = Icons.local_fire_department;
    } else if (_score >= 60) {
      label = context.l10n.scoreLabel60;
      color = NearfoColors.accent;
      icon = Icons.thumb_up;
    } else if (_score >= 40) {
      label = context.l10n.scoreLabel40;
      color = NearfoColors.warning;
      icon = Icons.trending_up;
    } else if (_score >= 20) {
      label = context.l10n.scoreLabel20;
      color = NearfoColors.primaryLight;
      icon = Icons.rocket_launch;
    } else {
      label = context.l10n.scoreLabel0;
      color = NearfoColors.textMuted;
      icon = Icons.waving_hand;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection() {
    final categories = [
      {
        'key': 'posts',
        'label': context.l10n.postsLabel,
        'icon': Icons.article_rounded,
        'color': NearfoColors.primary,
        'subtitle': '${_breakdown['posts']?['count'] ?? 0} ${context.l10n.postsCreated}',
      },
      {
        'key': 'reels',
        'label': context.l10n.reelsLabel,
        'icon': Icons.slow_motion_video_rounded,
        'color': NearfoColors.pink,
        'subtitle': '${_breakdown['reels']?['count'] ?? 0} ${context.l10n.reelsCreated}',
      },
      {
        'key': 'followers',
        'label': context.l10n.followersLabel,
        'icon': Icons.people_rounded,
        'color': NearfoColors.accent,
        'subtitle': '${_breakdown['followers']?['count'] ?? 0} ${context.l10n.followers}',
      },
      {
        'key': 'engagement',
        'label': context.l10n.engagementLabel,
        'icon': Icons.favorite_rounded,
        'color': NearfoColors.danger,
        'subtitle': '${_breakdown['engagement']?['rate'] ?? 0}% ${context.l10n.engagementRate}',
      },
      {
        'key': 'activity',
        'label': context.l10n.activityLabel,
        'icon': Icons.trending_up_rounded,
        'color': NearfoColors.success,
        'subtitle': '${_breakdown['activity']?['likes'] ?? 0} ${context.l10n.likes}, ${_breakdown['activity']?['views'] ?? 0} ${context.l10n.views}',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.scoreBreakdown,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        ...categories.map((cat) => _buildBreakdownItem(cat)),
      ],
    );
  }

  Widget _buildBreakdownItem(Map<String, dynamic> cat) {
    final key = (cat['key'] as String?) ?? '';
    final label = (cat['label'] as String?) ?? '';
    final icon = (cat['icon'] as IconData?) ?? Icons.help;
    final color = (cat['color'] as Color?) ?? Colors.grey;
    final subtitle = (cat['subtitle'] as String?) ?? '';

    final catData = (_breakdown[key] as Map<String, dynamic>?) ?? {};
    final score = ((catData['score'] as num?)?.toInt()) ?? 0;
    final weight = ((catData['weight'] as num?)?.toInt()) ?? 20;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NearfoColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$score/$weight',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: weight > 0 ? score / weight : 0,
              minHeight: 8,
              backgroundColor: NearfoColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    // Find the weakest category and give tips
    String tip = context.l10n.defaultTip;
    IconData tipIcon = Icons.lightbulb_rounded;

    if (_breakdown.isNotEmpty) {
      int minScore = 100;
      String weakest = '';
      _breakdown.forEach((key, value) {
        final s = ((value is Map ? ((value as Map<String, dynamic>)['score'] as num?)?.toInt() : null) ?? 0);
        if (s < minScore) {
          minScore = s;
          weakest = key;
        }
      });

      switch (weakest) {
        case 'posts':
          tip = context.l10n.tipPosts;
          tipIcon = Icons.edit_note_rounded;
          break;
        case 'reels':
          tip = context.l10n.tipReels;
          tipIcon = Icons.videocam_rounded;
          break;
        case 'followers':
          tip = context.l10n.tipFollowers;
          tipIcon = Icons.person_add_rounded;
          break;
        case 'engagement':
          tip = context.l10n.tipEngagement;
          tipIcon = Icons.chat_bubble_rounded;
          break;
        case 'activity':
          tip = context.l10n.tipActivity;
          tipIcon = Icons.local_fire_department_rounded;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NearfoColors.primary.withOpacity(0.1),
            NearfoColors.accent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NearfoColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NearfoColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tipIcon, color: NearfoColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.tipToImprove,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(color: NearfoColors.textMuted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return NearfoColors.success;
    if (score >= 60) return NearfoColors.accent;
    if (score >= 40) return NearfoColors.warning;
    if (score >= 20) return NearfoColors.primaryLight;
    return NearfoColors.textDim;
  }
}
