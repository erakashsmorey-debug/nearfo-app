import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized ad management service for Nearfo.
/// Handles banner, interstitial, and rewarded ads via Google AdMob.
///
/// HOW TO SET UP:
/// 1. Create AdMob account at https://admob.google.com
/// 2. Add your app (Android + iOS)
/// 3. Create ad units (banner, interstitial, rewarded)
/// 4. Replace the test IDs below with your real ad unit IDs
/// 5. Replace the App ID in AndroidManifest.xml and Info.plist
class AdService {
  static final AdService _instance = AdService._();
  static AdService get instance => _instance;
  AdService._();

  bool _isInitialized = false;

  // ============================================================
  // REAL-TIME TRACKING COUNTERS (persisted locally)
  // ============================================================
  int bannerImpressions = 0;
  int interstitialImpressions = 0;
  int rewardedImpressions = 0;
  int bannerClicks = 0;
  int interstitialClicks = 0;
  int totalImpressions = 0;

  /// Load saved counters from SharedPreferences
  Future<void> _loadCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = prefs.getString('ad_date') ?? '';
      if (savedDate != today) {
        // Reset daily counters
        await prefs.setString('ad_date', today);
        await prefs.setInt('ad_banner_imp', 0);
        await prefs.setInt('ad_inter_imp', 0);
        await prefs.setInt('ad_reward_imp', 0);
        await prefs.setInt('ad_banner_clicks', 0);
        await prefs.setInt('ad_inter_clicks', 0);
        bannerImpressions = 0;
        interstitialImpressions = 0;
        rewardedImpressions = 0;
        bannerClicks = 0;
        interstitialClicks = 0;
      } else {
        bannerImpressions = prefs.getInt('ad_banner_imp') ?? 0;
        interstitialImpressions = prefs.getInt('ad_inter_imp') ?? 0;
        rewardedImpressions = prefs.getInt('ad_reward_imp') ?? 0;
        bannerClicks = prefs.getInt('ad_banner_clicks') ?? 0;
        interstitialClicks = prefs.getInt('ad_inter_clicks') ?? 0;
      }
      totalImpressions = bannerImpressions + interstitialImpressions + rewardedImpressions;
    } catch (e) {
      debugPrint('[AdService] Failed to load counters: $e');
    }
  }

  Future<void> _incrementCounter(String key, String field) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + 1);
      // Update in-memory values
      switch (field) {
        case 'banner_imp': bannerImpressions = current + 1; break;
        case 'inter_imp': interstitialImpressions = current + 1; break;
        case 'reward_imp': rewardedImpressions = current + 1; break;
        case 'banner_click': bannerClicks = current + 1; break;
        case 'inter_click': interstitialClicks = current + 1; break;
      }
      totalImpressions = bannerImpressions + interstitialImpressions + rewardedImpressions;
    } catch (e) {
      debugPrint('[AdService] Counter increment error: $e');
    }
  }

  // ============================================================
  // AD UNIT IDs (Real AdMob IDs — Nearfo Android & iOS)
  // ============================================================
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7737354605781991/2549688706'; // Nearfo Feed Banner (Android)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7737354605781991/8742569106'; // Nearfo Feed Banner (iOS)
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7737354605781991/2244733650'; // Nearfo Interstitial (Android)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7737354605781991/9823456107'; // Nearfo Interstitial (iOS)
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7737354605781991/7771424902'; // Nearfo Rewarded (Android)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7737354605781991/7654321908'; // Nearfo Rewarded (iOS)
    }
    return '';
  }

  // ============================================================
  // CACHED ADS (preloaded for instant display)
  // ============================================================
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  /// Counter to show interstitial every N actions (not too aggressive)
  int _actionCount = 0;
  static const int _interstitialFrequency = 5; // Show ad every 5 actions

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Initialize the Mobile Ads SDK. Safe to call from main().
  /// This method never throws — all errors are caught and logged.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final initStatus = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Google Mobile Ads initialized');
      // Log adapter statuses for debugging
      initStatus.adapterStatuses.forEach((adapter, status) {
        debugPrint('[AdService] Adapter: $adapter — ${status.state}');
      });

      // Load saved impression counters
      await _loadCounters();

      // Preload ads so they're ready when needed (delayed to avoid startup bottleneck)
      Future.delayed(const Duration(seconds: 2), () {
        _loadInterstitialAd();
        _loadRewardedAd();
      });
    } catch (e, stack) {
      debugPrint('[AdService] Failed to initialize: $e');
      debugPrint('[AdService] Stack: $stack');
      // Don't rethrow — ads failing should never crash the app
    }
  }

  // ============================================================
  // BANNER ADS (shown at bottom of screens)
  // ============================================================

  /// Create a banner ad widget. Call this in your screen's initState().
  /// Remember to dispose it in dispose().
  BannerAd createBannerAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner, // 320x50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Banner ad loaded');
          _incrementCounter('ad_banner_imp', 'banner_imp');
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] Banner ad failed: ${error.message}');
          ad.dispose();
          onFailed?.call();
        },
        onAdOpened: (ad) {
          debugPrint('[AdService] Banner ad clicked');
          _incrementCounter('ad_banner_clicks', 'banner_click');
        },
        onAdClosed: (ad) => debugPrint('[AdService] Banner ad closed'),
      ),
    );
  }

  // ============================================================
  // INTERSTITIAL ADS (full-screen, shown between actions)
  // ============================================================

  /// Load an interstitial ad in background (preloading)
  void _loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Interstitial ad loaded');
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _incrementCounter('ad_inter_imp', 'inter_imp');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(); // Preload next one
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[AdService] Interstitial show failed: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial load failed: ${error.message}');
          _isInterstitialLoading = false;
          // Retry after delay
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  /// Record a user action. Shows interstitial every N actions.
  /// Call this on screen transitions like opening a chat, viewing a profile, etc.
  void recordAction() {
    _actionCount++;
    if (_actionCount >= _interstitialFrequency) {
      showInterstitialAd();
      _actionCount = 0;
    }
  }

  /// Force show an interstitial ad (if one is loaded)
  bool showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      return true;
    } else {
      _loadInterstitialAd();
      return false;
    }
  }

  // ============================================================
  // REWARDED ADS (user watches for a reward)
  // ============================================================

  /// Load a rewarded ad in background
  void _loadRewardedAd() {
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Rewarded ad loaded');
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _incrementCounter('ad_reward_imp', 'reward_imp');
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded ad load failed: ${error.message}');
          _isRewardedLoading = false;
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  /// Check if a rewarded ad is ready
  bool get isRewardedAdReady => _rewardedAd != null;

  /// Show a rewarded ad. Returns true if shown successfully.
  /// [onRewardEarned] is called when the user earns the reward (watched full ad).
  /// [onAdClosed] is called when the ad is dismissed (whether reward earned or not).
  bool showRewardedAd({
    required void Function(int amount) onRewardEarned,
    VoidCallback? onAdClosed,
  }) {
    if (_rewardedAd == null) {
      _loadRewardedAd();
      return false;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // Preload next one
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded show failed: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
        onRewardEarned(reward.amount.toInt());
      },
    );

    return true;
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}
