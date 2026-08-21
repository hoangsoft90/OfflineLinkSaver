import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob service — wraps banner, interstitial, and rewarded ad logic.
///
/// Uses Google's official TEST ad unit IDs so every impression is a test impression.
/// Replace with real IDs before production release.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Test Ad Unit IDs (Google official) ──────────────────────────────
  // These are guaranteed to always return ads in any environment.

  static String get _bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
    }
    return '';
  }

  static String get _interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android test interstitial
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial
    }
    return '';
  }

  /// AdMob App IDs (required in AndroidManifest / Info.plist).
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  // ── Interstitial ────────────────────────────────────────────────────

  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;

  /// Pre-load an interstitial ad. Call once at app start and after each show.
  void loadInterstitialAd() {
    if (_interstitialAd != null || _isLoadingInterstitial) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          debugPrint('[AdService] Interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoadingInterstitial = false;
          debugPrint('[AdService] Interstitial failed: ${error.message}');
        },
      ),
    );
  }

  /// Show the interstitial ad if it's loaded. Returns true if shown.
  bool showInterstitialAd({VoidCallback? onDismissed}) {
    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('[AdService] Interstitial not ready');
      onDismissed?.call();
      return false;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        onDismissed?.call();
        // Pre-load next one
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        onDismissed?.call();
        loadInterstitialAd();
      },
    );

    ad.show();
    _interstitialAd = null;
    return true;
  }

  // ── Banner ──────────────────────────────────────────────────────────

  /// Create a banner ad widget. Caller is responsible for disposing it.
  BannerAd createBannerAd({
    AdSize size = AdSize.banner,
    void Function(Ad ad)? onAdLoaded,
    void Function(Ad ad, LoadAdError error)? onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Banner loaded');
          onAdLoaded?.call(ad);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] Banner failed: ${error.message}');
          ad.dispose();
          onAdFailedToLoad?.call(ad, error);
        },
      ),
    );
  }

  // ── Lifecycle ───────────────────────────────────────────────────────

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
