import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../l10n/l10n_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<_OnboardingData> _pages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pages = [
      _OnboardingData(
        icon: Icons.location_on_rounded,
        title: context.l10n.onboardingTitle1,
        subtitle: context.l10n.onboardingDesc1,
        gradient: NearfoColors.primaryGradient,
      ),
      _OnboardingData(
        icon: Icons.people_rounded,
        title: context.l10n.onboardingTitle2,
        subtitle: context.l10n.onboardingDesc2,
        gradient: NearfoColors.secondaryGradient,
      ),
      _OnboardingData(
        icon: Icons.public_rounded,
        title: context.l10n.onboardingTitle3,
        subtitle: context.l10n.onboardingDesc3,
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF7C3AED)],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, NearfoRoutes.login),
                child: Text(context.l10n.onboardingSkip, style: TextStyle(color: NearfoColors.textMuted, fontSize: 15)),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: page.gradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: NearfoColors.primary.withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(page.icon, size: 56, color: Colors.white),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          page.title,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          style: TextStyle(fontSize: 16, color: NearfoColors.textMuted, height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: _currentPage == i ? NearfoColors.primaryGradient : null,
                  color: _currentPage == i ? null : NearfoColors.textDim,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 32),

            // Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: NearfoColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: NearfoColors.primary.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < 2) {
                        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                      } else {
                        Navigator.pushReplacementNamed(context, NearfoRoutes.login);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _currentPage < 2 ? context.l10n.next : context.l10n.onboardingGetStarted,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  _OnboardingData({required this.icon, required this.title, required this.subtitle, required this.gradient});
}
