import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads_config.dart';

/// AdMob service — wraps banner, interstitial, and rewarded ad logic.
///
/// Reads all ad unit IDs from [AdsConfig]. Respects cooldown timers
/// to prevent spamming the user with ads.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Interstitial ────────────────────────────────────────────────────

  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;

  /// Timestamp (milliseconds since epoch) of the last interstitial shown.
  int _lastInterstitialShownAt = 0;

  /// Returns `true` if enough time has passed since the last interstitial.
  bool get _interstitialCooledDown {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - _lastInterstitialShownAt) >
        AdsConfig.interstitialCooldownSeconds * 1000;
  }

  /// Pre-load an interstitial ad. Call once at app start and after each show.
  void loadInterstitialAd() {
    if (_interstitialAd != null || _isLoadingInterstitial) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId,
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

  /// Show the interstitial ad if it's loaded AND cooldown has passed.
  /// Returns `true` if the ad was actually shown.
  ///
  /// [onDismissed] is called whether the ad was shown or not (fallback path).
  bool showInterstitialAd({VoidCallback? onDismissed}) {
    // Cooldown check
    if (!_interstitialCooledDown) {
      debugPrint('[AdService] Interstitial on cooldown, skipping');
      onDismissed?.call();
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('[AdService] Interstitial not ready');
      onDismissed?.call();
      return false;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _lastInterstitialShownAt = DateTime.now().millisecondsSinceEpoch;
        ad.dispose();
        _interstitialAd = null;
        onDismissed?.call();
        loadInterstitialAd(); // pre-load next
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

  /// Timestamp of the last banner ad creation per key.
  final Map<String, int> _lastBannerCreatedAt = {};

  /// Create a banner ad widget. Caller is responsible for disposing it.
  ///
  /// [tag] is used for cooldown tracking — pass a unique string per screen.
  BannerAd createBannerAd({
    String tag = 'default',
    AdSize size = AdSize.banner,
    void Function(Ad ad)? onAdLoaded,
    void Function(Ad ad, LoadAdError error)? onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: AdsConfig.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _lastBannerCreatedAt[tag] = DateTime.now().millisecondsSinceEpoch;
          debugPrint('[AdService] Banner loaded ($tag)');
          onAdLoaded?.call(ad);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] Banner failed ($tag): ${error.message}');
          ad.dispose();
          onAdFailedToLoad?.call(ad, error);
        },
      ),
    );
  }

  /// Returns `true` if the banner for [tag] was created recently (within cooldown).
  bool bannerIsRecent(String tag) {
    final last = _lastBannerCreatedAt[tag];
    if (last == null) return false;
    return (DateTime.now().millisecondsSinceEpoch - last) <
        AdsConfig.bannerRefreshCooldownSeconds * 1000;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
