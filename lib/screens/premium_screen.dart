import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/ad_service.dart';
import '../l10n/l10n_helper.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

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
        title: Text(context.l10n.premiumTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Premium badge
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [NearfoColors.pink.withOpacity(0.2), NearfoColors.primary.withOpacity(0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_rounded, size: 64, color: NearfoColors.pink),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [NearfoColors.pink, NearfoColors.primary],
              ).createShader(bounds),
              child: Text(
                context.l10n.premiumSubtitle,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.premiumDesc,
              style: TextStyle(color: NearfoColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 32),

            // Features
            _featureItem(Icons.verified_rounded, context.l10n.verifiedBadge, context.l10n.verifiedBadgeDesc),
            _featureItem(Icons.analytics_rounded, context.l10n.advancedAnalytics, context.l10n.advancedAnalyticsDesc),
            _featureItem(Icons.remove_circle_outline, context.l10n.adFreeExp, context.l10n.adFreeExpDesc),
            _featureItem(Icons.speed_rounded, context.l10n.priorityFeed, context.l10n.priorityFeedDesc),
            _featureItem(Icons.palette_rounded, context.l10n.customThemes, context.l10n.customThemesDesc),
            _featureItem(Icons.support_agent_rounded, context.l10n.prioritySupport, context.l10n.prioritySupportDesc),

            const SizedBox(height: 32),

            // Watch Ad for Free Rewards section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [NearfoColors.success.withOpacity(0.1), NearfoColors.primary.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NearfoColors.success.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('🎬', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.watchAdsRewards,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.watchAdsDesc,
                    style: TextStyle(color: NearfoColors.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _RewardedAdButton(
                    icon: Icons.visibility_rounded,
                    label: context.l10n.seeViewers,
                    rewardText: context.l10n.watchAdUnlock,
                  ),
                  const SizedBox(height: 8),
                  _RewardedAdButton(
                    icon: Icons.rocket_launch_rounded,
                    label: context.l10n.boostPost,
                    rewardText: context.l10n.watchAdBoost,
                  ),
                  const SizedBox(height: 8),
                  _RewardedAdButton(
                    icon: Icons.color_lens_rounded,
                    label: context.l10n.unlockChatTheme,
                    rewardText: context.l10n.watchAdUnlock,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Subscription Plans
            Text(context.l10n.choosePlan, style: TextStyle(color: NearfoColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _planCard(
              title: context.l10n.monthlyPlan,
              price: context.l10n.monthlyPrice,
              period: context.l10n.perMonth,
              features: [context.l10n.adFreeBrowsing, context.l10n.verifiedBadge, context.l10n.prioritySupport],
              color: NearfoColors.primary,
              isPopular: false,
            ),
            const SizedBox(height: 12),
            _planCard(
              title: context.l10n.yearlyPlan,
              price: context.l10n.yearlyPrice,
              period: context.l10n.perYear,
              features: [context.l10n.everythingMonthly, context.l10n.advancedAnalytics, context.l10n.customThemes, context.l10n.yearSavings],
              color: NearfoColors.pink,
              isPopular: true,
            ),
            const SizedBox(height: 12),
            _planCard(
              title: context.l10n.lifetimePlan,
              price: context.l10n.lifetimePrice,
              period: context.l10n.oneTime,
              features: [context.l10n.everythingForever, context.l10n.earlyAccess, context.l10n.founderBadge],
              color: NearfoColors.accent,
              isPopular: false,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.paymentComingSoon,
              style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NearfoColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NearfoColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NearfoColors.pink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: NearfoColors.pink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: NearfoColors.pink, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required Color color,
    required bool isPopular,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPopular ? color : NearfoColors.border, width: isPopular ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NearfoColors.text)),
              if (isPopular) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              RichText(
                text: TextSpan(children: [
                  TextSpan(text: price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                  TextSpan(text: period, style: TextStyle(fontSize: 12, color: NearfoColors.textMuted)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: color, size: 16),
                const SizedBox(width: 8),
                Text(f, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
              ],
            ),
          )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Payment integration placeholder
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? color : NearfoColors.card,
                foregroundColor: isPopular ? Colors.white : color,
                side: isPopular ? null : BorderSide(color: color),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(isPopular ? context.l10n.getStarted : context.l10n.choosePlanBtn, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rewarded ad button — user taps to watch an ad and get a reward
class _RewardedAdButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String rewardText;

  const _RewardedAdButton({
    required this.icon,
    required this.label,
    required this.rewardText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final shown = AdService.instance.showRewardedAd(
          onRewardEarned: (amount) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('🎉 ', style: TextStyle(fontSize: 18)),
                    Expanded(child: Text('${context.l10n.rewardUnlocked} $label')),
                  ],
                ),
                backgroundColor: NearfoColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          onAdClosed: () {
            // Ad was closed (user may or may not have earned reward)
          },
        );

        if (!shown) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.adLoading),
              backgroundColor: NearfoColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: NearfoColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NearfoColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: NearfoColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: NearfoColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_filled, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(rewardText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
