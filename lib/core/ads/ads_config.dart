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

  // ── Master Switch ───────────────────────────────────────────────────

  /// Set to `false` before publishing to production.
  /// In test mode all ad unit IDs point to Google's official test units.
  static const bool testAds = true;

  // ── Ad Unit IDs ─────────────────────────────────────────────────────

  // Test IDs — always return ads, safe for development.
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

  // Production IDs — TODO: replace with your real AdMob ad unit IDs.
  static const Map<String, String> _prodBannerAndroid = {
    'adUnitId': 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  };
  static const Map<String, String> _prodBannerIos = {
    'adUnitId': 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  };
  static const Map<String, String> _prodInterstitialAndroid = {
    'adUnitId': 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  };
  static const Map<String, String> _prodInterstitialIos = {
    'adUnitId': 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  };

  // ── App IDs (required by platform manifests) ────────────────────────

  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  // ── Cooldown Settings ───────────────────────────────────────────────

  /// Minimum gap between interstitial shows (in seconds).
  /// Prevents spamming the user with full-screen ads.
  static const int interstitialCooldownSeconds = 60;

  /// Minimum gap between banner refreshes is handled by the SDK;
  /// this controls how often we *create* new banner instances in Flutter.
  static const int bannerRefreshCooldownSeconds = 120;

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

  // ── Debug Logging ───────────────────────────────────────────────────

  static void logConfig() {
    debugPrint('[AdsConfig] testAds=$testAds');
    debugPrint('[AdsConfig] banner=$bannerAdUnitId');
    debugPrint('[AdsConfig] interstitial=$interstitialAdUnitId');
    debugPrint('[AdsConfig] cooldown=${interstitialCooldownSeconds}s');
  }
}
