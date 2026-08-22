import 'dart:io';
import 'package:flutter/foundation.dart';

/// AdMob configuration.
///
/// Toggle [testAds] to switch between test and production ad units.
/// In test mode every impression is a test impression — Google will never
/// penalise your account for invalid traffic.
///
/// Cooldown settings prevent showing ads too frequently and protect UX.
class AdsConfig {
  AdsConfig._();

  // ── Master Switches ─────────────────────────────────────────────────

  /// Master switch to completely enable/disable ads.
  /// Set to `true` to show ads, `false` to hide all ads everywhere.
  static const bool enableAds = true;

  /// Set to `false` before publishing to production.
  /// In test mode all ad unit IDs point to Google's official test units.
  static const bool testAds = false;

  // ── Ad Unit IDs ─────────────────────────────────────────────────────

  // ── Test IDs (Google official) ──
  static const Map<String, String> _testBannerAndroid = {
    'adUnitId': 'ca-app-pub-3940256099942544/6300978111',
  };
  static const Map<String, String> _testBannerIos = {
    'adUnitId': 'ca-app-pub-3940256099942544/2934735716',
  };
  static const Map<String, String> _testInterstitialAndroid = {
    'adUnitId': 'ca-app-pub-3940256099942544/1033173712',
  };
  static const Map<String, String> _testInterstitialIos = {
    'adUnitId': 'ca-app-pub-3940256099942544/4411468910',
  };

  // ── Production IDs (real AdMob account) ──
  static const Map<String, String> _prodBannerAndroid = {
    'adUnitId': 'ca-app-pub-6917313063209470/3645357226',
  };
  static const Map<String, String> _prodBannerIos = {
    'adUnitId': 'ca-app-pub-3940256099942544/2934735716', // TODO: replace with real iOS banner ID
  };
  static const Map<String, String> _prodInterstitialAndroid = {
    'adUnitId': 'ca-app-pub-6917313063209470/3708936406',
  };
  static const Map<String, String> _prodInterstitialIos = {
    'adUnitId': 'ca-app-pub-3940256099942544/4411468910', // TODO: replace with real iOS interstitial ID
  };

  // ── Rewarded Ads ──

  static const Map<String, String> _testRewardedAndroid = {
    'adUnitId': 'ca-app-pub-3940256099942544/5224354917',
  };
  static const Map<String, String> _testRewardedIos = {
    'adUnitId': 'ca-app-pub-3940256099942544/1712485313',
  };
  static const Map<String, String> _prodRewardedAndroid = {
    'adUnitId': 'ca-app-pub-6917313063209470/6079948874',
  };
  static const Map<String, String> _prodRewardedIos = {
    'adUnitId': 'ca-app-pub-3940256099942544/1712485313', // TODO: replace with real iOS rewarded ID
  };

  // ── App IDs (required by platform manifests) ────────────────────────

  static const String androidAppId = 'ca-app-pub-6917313063209470~9608130345';
  static const String iosAppId = 'ca-app-pub-6917313063209470~9608130345';

  // ── Cooldown Settings ───────────────────────────────────────────────

  /// Minimum gap between interstitial shows (in seconds).
  static const int interstitialCooldownSeconds = 60;

  /// Minimum gap between banner refreshes (in seconds).
  static const int bannerRefreshCooldownSeconds = 120;

  /// Minimum gap between rewarded shows (in seconds).
  static const int rewardedCooldownSeconds = 120;

  // ── Convenience Getters ─────────────────────────────────────────────

  static String get bannerAdUnitId {
    if (testAds) {
      if (Platform.isAndroid) return _testBannerAndroid['adUnitId']!;
      if (Platform.isIOS) return _testBannerIos['adUnitId']!;
    } else {
      if (Platform.isAndroid) return _prodBannerAndroid['adUnitId']!;
      if (Platform.isIOS) return _prodBannerIos['adUnitId']!;
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (testAds) {
      if (Platform.isAndroid) return _testInterstitialAndroid['adUnitId']!;
      if (Platform.isIOS) return _testInterstitialIos['adUnitId']!;
    } else {
      if (Platform.isAndroid) return _prodInterstitialAndroid['adUnitId']!;
      if (Platform.isIOS) return _prodInterstitialIos['adUnitId']!;
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (testAds) {
      if (Platform.isAndroid) return _testRewardedAndroid['adUnitId']!;
      if (Platform.isIOS) return _testRewardedIos['adUnitId']!;
    } else {
      if (Platform.isAndroid) return _prodRewardedAndroid['adUnitId']!;
      if (Platform.isIOS) return _prodRewardedIos['adUnitId']!;
    }
    return '';
  }

  // ── Debug Logging ───────────────────────────────────────────────────

  static void logConfig() {
    debugPrint('[AdsConfig] enableAds=$enableAds, testAds=$testAds');
    debugPrint('[AdsConfig] banner=$bannerAdUnitId');
    debugPrint('[AdsConfig] interstitial=$interstitialAdUnitId');
    debugPrint('[AdsConfig] rewarded=$rewardedAdUnitId');
    debugPrint('[AdsConfig] cooldown: interstitial=${interstitialCooldownSeconds}s, rewarded=${rewardedCooldownSeconds}s');
  }
}
