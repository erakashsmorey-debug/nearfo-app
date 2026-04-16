import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/ad_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../l10n/l10n_helper.dart';

/// Premium Monetization Dashboard — Earnings overview, ad metrics, revenue breakdown.
/// Tracks estimated AdMob revenue with beautiful premium UI.
class MonetizationDashboardScreen extends StatefulWidget {
  const MonetizationDashboardScreen({super.key});
  @override
  State<MonetizationDashboardScreen> createState() => _MonetizationDashboardScreenState();
}

class _MonetizationDashboardScreenState extends State<MonetizationDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Simulated metrics (replace with real AdMob Reporting API data later)
  double _todayEarnings = 0;
  double _weekEarnings = 0;
  double _monthEarnings = 0;
  double _totalEarnings = 0;
  int _todayImpressions = 0;
  int _todayClicks = 0;
  double _ctr = 0;
  double _ecpm = 0;

  // Ad type breakdown
  int _bannerImpressions = 0;
  int _interstitialImpressions = 0;
  int _rewardedViews = 0;
  double _bannerRevenue = 0;
  double _interstitialRevenue = 0;
  double _rewardedRevenue = 0;

  // Daily data for chart (last 7 days)
  List<double> _dailyEarnings = [];
  List<String> _dailyLabels = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Use REAL data from AdService (live impression counts from the device)
    final ads = AdService.instance;
    final rand = Random();

    setState(() {
      // Real impression counts from AdService (tracked locally)
      _bannerImpressions = ads.bannerImpressions;
      _interstitialImpressions = ads.interstitialImpressions;
      _rewardedViews = ads.rewardedImpressions;
      _todayImpressions = ads.totalImpressions;
      _todayClicks = ads.bannerClicks + ads.interstitialClicks;

      // Estimated revenue based on average eCPM rates (India)
      // Banner eCPM ~$0.50-1.50, Interstitial ~$3-8, Rewarded ~$8-15
      _bannerRevenue = _bannerImpressions * 0.001; // ~$1.00 eCPM
      _interstitialRevenue = _interstitialImpressions * 0.005; // ~$5.00 eCPM
      _rewardedRevenue = _rewardedViews * 0.010; // ~$10.00 eCPM
      _todayEarnings = _bannerRevenue + _interstitialRevenue + _rewardedRevenue;

      _ctr = _todayImpressions > 0 ? (_todayClicks / _todayImpressions) * 100 : 0;
      _ecpm = _todayImpressions > 0 ? (_todayEarnings / _todayImpressions) * 1000 : 0;

      // Estimated weekly/monthly/total (scaled from today)
      _weekEarnings = _todayEarnings * 7;
      _monthEarnings = _todayEarnings * 30;
      _totalEarnings = _todayEarnings * 30; // Will grow over time

      // Generate 7-day chart data (today is real, rest estimated)
      _dailyEarnings = List.generate(7, (i) {
        if (i == 6) return _todayEarnings; // Today is real
        return (_todayEarnings * (0.5 + rand.nextDouble() * 1.0)); // Estimated variation
      });

      final now = DateTime.now();
      _dailyLabels = List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
      });

      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: CustomScrollView(
        slivers: [
          // Premium gradient app bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1a1a2e),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: _loadMetrics,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                onPressed: () => _showAdSettings(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF7C3AED), size: 28),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.monetizationTitle, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                Text(context.l10n.dashboardLabel, style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Today's earnings highlight
                        Row(
                          children: [
                            Text('${context.l10n.todayLabel}: ', style: const TextStyle(color: Colors.white60, fontSize: 14)),
                            _isLoading
                                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                                : Text(
                                    '\$${_todayEarnings.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF00E676), fontSize: 28, fontWeight: FontWeight.w900),
                                  ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.trending_up_rounded, color: Color(0xFF00E676), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(_ctr).toStringAsFixed(1)}% ${context.l10n.ctrLabel}',
                                    style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: NearfoColors.primary,
                unselectedLabelColor: NearfoColors.textMuted,
                indicatorColor: NearfoColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(text: context.l10n.overviewTab),
                  Tab(text: context.l10n.adTypesTab),
                  Tab(text: context.l10n.setupGuideTab),
                ],
              ),
            ),
          ),

          // Tab content
          SliverFillRemaining(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildAdTypesTab(),
                      _buildSetupGuideTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW TAB
  // ============================================================
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Earnings Cards Row
          Row(
            children: [
              Expanded(child: _earningsCard('This Week', _weekEarnings, Icons.calendar_view_week_rounded, const Color(0xFF6C5CE7))),
              SizedBox(width: 12),
              Expanded(child: _earningsCard('This Month', _monthEarnings, Icons.calendar_month_rounded, const Color(0xFF00B894))),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _earningsCard('All Time', _totalEarnings, Icons.account_balance_wallet_rounded, const Color(0xFFFDAA00))),
              SizedBox(width: 12),
              Expanded(child: _earningsCard('eCPM', _ecpm, Icons.speed_rounded, const Color(0xFFE84393), isCurrency: false, suffix: '')),
            ],
          ),

          const SizedBox(height: 24),

          // 7-Day Earnings Chart
          _sectionTitle('Last 7 Days Earnings'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NearfoColors.border),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: _buildBarChart(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _dailyLabels.map((l) => Text(l, style: TextStyle(color: NearfoColors.textDim, fontSize: 11))).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Today's Performance Metrics
          _sectionTitle('Today\'s Performance'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NearfoColors.border),
            ),
            child: Column(
              children: [
                _metricRow('Impressions', '$_todayImpressions', Icons.visibility_rounded, const Color(0xFF0984E3)),
                const Divider(height: 24),
                _metricRow('Clicks', '$_todayClicks', Icons.touch_app_rounded, const Color(0xFF6C5CE7)),
                const Divider(height: 24),
                _metricRow('CTR', '${_ctr.toStringAsFixed(2)}%', Icons.percent_rounded, const Color(0xFF00B894)),
                const Divider(height: 24),
                _metricRow('eCPM', '\$${_ecpm.toStringAsFixed(2)}', Icons.speed_rounded, const Color(0xFFE84393)),
                const Divider(height: 24),
                _metricRow('Revenue', '\$${_todayEarnings.toStringAsFixed(2)}', Icons.attach_money_rounded, const Color(0xFF00E676)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          _sectionTitle('Quick Actions'),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Test Ads',
                  color: const Color(0xFF6C5CE7),
                  onTap: () {
                    AdService.instance.showInterstitialAd();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Showing test interstitial ad...'),
                        backgroundColor: NearfoColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.video_library_outlined,
                  label: 'Test Rewarded',
                  color: const Color(0xFF00B894),
                  onTap: () {
                    final shown = AdService.instance.showRewardedAd(
                      onRewardEarned: (amount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reward earned: $amount'), backgroundColor: NearfoColors.success),
                        );
                      },
                    );
                    if (!shown) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Rewarded ad loading...'), backgroundColor: NearfoColors.warning),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============================================================
  // AD TYPES TAB
  // ============================================================
  Widget _buildAdTypesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Breakdown
          _sectionTitle('Revenue Breakdown'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NearfoColors.border),
            ),
            child: Column(
              children: [
                // Visual pie-like breakdown
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      // Donut-style indicator
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            values: [_bannerRevenue, _interstitialRevenue, _rewardedRevenue],
                            colors: const [Color(0xFF0984E3), Color(0xFF6C5CE7), Color(0xFF00B894)],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${_todayEarnings.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                Text('Today', style: TextStyle(color: NearfoColors.textDim, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legendItem('Banner', _bannerRevenue, const Color(0xFF0984E3)),
                            const SizedBox(height: 10),
                            _legendItem('Interstitial', _interstitialRevenue, const Color(0xFF6C5CE7)),
                            const SizedBox(height: 10),
                            _legendItem('Rewarded', _rewardedRevenue, const Color(0xFF00B894)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Banner Ads Detail
          _adTypeDetailCard(
            title: 'Banner Ads',
            subtitle: 'Shown in feed every 4 posts & on notification screen',
            icon: Icons.view_agenda_rounded,
            color: const Color(0xFF0984E3),
            impressions: _bannerImpressions,
            revenue: _bannerRevenue,
            tips: [
              'Non-intrusive 320x50 banners',
              'Users scroll past naturally',
              'Best for consistent passive income',
            ],
          ),
          const SizedBox(height: 12),

          // Interstitial Ads Detail
          _adTypeDetailCard(
            title: 'Interstitial Ads',
            subtitle: 'Full-screen, shown every 5th screen transition',
            icon: Icons.fullscreen_rounded,
            color: const Color(0xFF6C5CE7),
            impressions: _interstitialImpressions,
            revenue: _interstitialRevenue,
            tips: [
              'Highest revenue per impression',
              'Shows between chat opens & profile views',
              'Not during reels, stories, or calls',
            ],
          ),
          const SizedBox(height: 12),

          // Rewarded Ads Detail
          _adTypeDetailCard(
            title: 'Rewarded Ads',
            subtitle: 'Users choose to watch for premium features',
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFF00B894),
            impressions: _rewardedViews,
            revenue: _rewardedRevenue,
            tips: [
              'User-initiated = highest engagement',
              'Unlock: who viewed profile, post boost, themes',
              'Best user experience — no interruption',
            ],
          ),

          const SizedBox(height: 16),

          // Banner ad preview
          const StyledBannerAd(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============================================================
  // SETUP GUIDE TAB
  // ============================================================
  Widget _buildSetupGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFDAA00).withOpacity(0.15), const Color(0xFFE84393).withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDAA00).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                const Text('Setup Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _setupStepItem(1, 'Create Google AdMob Account', 'Visit admob.google.com and sign up', true),
                _setupStepItem(2, 'Register Your App', 'Add Nearfo (Android) in AdMob console', false),
                _setupStepItem(3, 'Create Ad Units', 'Create Banner, Interstitial & Rewarded ad units', false),
                _setupStepItem(4, 'Replace Ad Unit IDs', 'Update IDs in ad_service.dart', false),
                _setupStepItem(5, 'Replace App ID', 'Update AndroidManifest.xml & Info.plist', false),
                _setupStepItem(6, 'Build & Publish', 'Build APK with real ads and publish to Play Store', false),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Where to Find Ad IDs'),
          const SizedBox(height: 12),

          _guideCard(
            '1. AdMob App ID',
            'Go to AdMob → Apps → Your App → App settings\n'
                'Format: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX\n\n'
                'Update in:\n'
                '• android/app/src/main/AndroidManifest.xml\n'
                '• ios/Runner/Info.plist',
            Icons.apps_rounded,
            const Color(0xFF0984E3),
          ),
          const SizedBox(height: 12),

          _guideCard(
            '2. Ad Unit IDs',
            'Go to AdMob → Apps → Your App → Ad Units\n'
                'Create 3 ad units:\n\n'
                '• Banner (320x50) — for feed & lists\n'
                '• Interstitial — for screen transitions\n'
                '• Rewarded — for premium unlocks\n\n'
                'Update in: lib/services/ad_service.dart',
            Icons.code_rounded,
            const Color(0xFF6C5CE7),
          ),
          const SizedBox(height: 12),

          _guideCard(
            '3. Revenue Optimization Tips',
            '• Start with test ads (already configured)\n'
            '• Don\'t show too many ads — user retention matters\n'
            '• Rewarded ads have highest eCPM (\$10-25)\n'
            '• Interstitial eCPM: \$4-12\n'
            '• Banner eCPM: \$0.50-3\n'
            '• India eCPM is lower (~30% of US rates)\n'
            '• With 1000 DAU: expect \$3-15/day',
            Icons.lightbulb_rounded,
            const Color(0xFF00B894),
          ),
          const SizedBox(height: 12),

          _guideCard(
            '4. Payment Setup',
            'AdMob pays once you reach \$100 threshold\n\n'
            '• Payment methods: Wire transfer, EFT\n'
            '• Add your bank details in AdMob → Payments\n'
            '• Payments are sent monthly (around 21st)\n'
            '• First payment may take 2-3 months',
            Icons.account_balance_rounded,
            const Color(0xFFFDAA00),
          ),

          const SizedBox(height: 24),

          // Estimated Revenue Calculator
          _sectionTitle('Estimated Revenue'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NearfoColors.border),
            ),
            child: Column(
              children: [
                _estimateRow('100 DAU', '\$0.30 - \$1.50', '/day'),
                const Divider(height: 20),
                _estimateRow('1,000 DAU', '\$3 - \$15', '/day'),
                const Divider(height: 20),
                _estimateRow('10,000 DAU', '\$30 - \$150', '/day'),
                const Divider(height: 20),
                _estimateRow('100K DAU', '\$300 - \$1,500', '/day'),
                const SizedBox(height: 12),
                Text(
                  'DAU = Daily Active Users  •  Based on India eCPM rates',
                  style: TextStyle(color: NearfoColors.textDim, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGET BUILDERS
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
  }

  Widget _earningsCard(String label, double value, IconData icon, Color color, {bool isCurrency = true, String suffix = ''}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NearfoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: NearfoColors.textDim, size: 12),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isCurrency ? '\$${value.toStringAsFixed(2)}$suffix' : '${value.toStringAsFixed(2)}$suffix',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_dailyEarnings.isEmpty) return const SizedBox();
    final maxVal = _dailyEarnings.reduce(max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(_dailyEarnings.length, (i) {
        final ratio = maxVal > 0 ? _dailyEarnings[i] / maxVal : 0.0;
        final isToday = i == _dailyEarnings.length - 1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '\$${_dailyEarnings[i].toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isToday ? const Color(0xFF7C3AED) : NearfoColors.textDim,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  height: 120 * ratio,
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF7C3AED), Color(0xFF6C5CE7)],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [const Color(0xFF6C5CE7).withOpacity(0.4), const Color(0xFF6C5CE7).withOpacity(0.15)],
                          ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _legendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13))),
        Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      ],
    );
  }

  Widget _adTypeDetailCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int impressions,
    required double revenue,
    required List<String> tips,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NearfoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: NearfoColors.textDim, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('Impressions', '$impressions', color),
              const SizedBox(width: 16),
              _miniStat('Revenue', '\$${revenue.toStringAsFixed(2)}', color),
              const SizedBox(width: 16),
              _miniStat('eCPM', impressions > 0 ? '\$${((revenue / impressions) * 1000).toStringAsFixed(1)}' : '\$0', color),
            ],
          ),
          SizedBox(height: 14),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 14),
                    SizedBox(width: 8),
                    Expanded(child: Text(t, style: TextStyle(color: NearfoColors.textMuted, fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: NearfoColors.textDim, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _setupStepItem(int step, String title, String subtitle, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF00E676) : NearfoColors.textDim.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, decoration: isDone ? TextDecoration.lineThrough : null)),
                Text(subtitle, style: TextStyle(color: NearfoColors.textDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideCard(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NearfoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _estimateRow(String users, String revenue, String period) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(users, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        Expanded(
          flex: 3,
          child: Text(revenue, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF00E676))),
        ),
        Text(period, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
      ],
    );
  }

  void _showAdSettings(BuildContext context) {
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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Ad Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.tune_rounded, color: Color(0xFF6C5CE7)),
              title: const Text('Ad Frequency'),
              subtitle: const Text('Show interstitial every 5 transitions'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Color(0xFFE84393)),
              title: const Text('Block Categories'),
              subtitle: const Text('Choose which ad categories to block'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Color(0xFF0984E3)),
              title: const Text('AdMob Console'),
              subtitle: const Text('Open admob.google.com'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16),
              onTap: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DONUT CHART PAINTER
// ============================================================
class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, v) => sum + v);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    double startAngle = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle - 0.05, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
// SLIVER TAB BAR DELEGATE
// ============================================================
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: NearfoColors.bg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
