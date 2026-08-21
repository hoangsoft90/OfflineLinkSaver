import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'core/ads/ads_config.dart';
import 'core/ads/ad_service.dart';
import 'core/database/database_helper.dart';
import 'repositories/article_repository.dart';
import 'services/downloader/download_queue_manager.dart';
import 'services/share_handler/share_handler.dart';
import 'screens/home/home_screen.dart';

/// SharedPreferences key for persisted locale choice.
const String _kLocalePrefKey = 'app_locale';

/// Sentry DSN — get yours at https://sentry.io
const String _sentryDsn =
    'https://b8ff5f1d968fe812b3e07f8d7ba51527@o4505474077753344.ingest.us.sentry.io/4511947859820544';

/// Returns the user's saved locale, or null to follow the system default.
Future<Locale?> _loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kLocalePrefKey);
  if (code == null || code.isEmpty) return null;
  return Locale(code);
}

/// Persists the user's locale choice.
Future<void> saveLocale(Locale locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLocalePrefKey, locale.languageCode);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Flutter framework errors → Sentry ──
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  // ── Dart async errors (uncaught exceptions in zones) → Sentry ──
  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };

  // ── Sentry init (wraps appRunner in its own error zone) ──
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => _runApp(),
  );
}

Future<void> _runApp() async {
  // Initialize Google Mobile Ads SDK
  AdsConfig.logConfig();
  await MobileAds.instance.initialize();
  AdService.instance.loadInterstitialAd();

  // Load persisted locale
  final savedLocale = await _loadSavedLocale();

  // Startup sanitization
  final db = await DatabaseHelper.database;
  await DatabaseHelper.startupSanitization(db);

  // Initialize repository and services
  final repository = ArticleRepository();
  final downloadQueue = DownloadQueueManager(repository: repository);
  final shareHandler = ShareHandler(
    repository: repository,
    downloadQueue: downloadQueue,
  );
  shareHandler.initialize();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(OfflineLinkSaverApp(
    repository: repository,
    downloadQueue: downloadQueue,
    shareHandler: shareHandler,
    initialLocale: savedLocale,
  ));
}

class OfflineLinkSaverApp extends StatefulWidget {
  final ArticleRepository repository;
  final DownloadQueueManager downloadQueue;
  final ShareHandler shareHandler;
  final Locale? initialLocale;

  const OfflineLinkSaverApp({
    super.key,
    required this.repository,
    required this.downloadQueue,
    required this.shareHandler,
    this.initialLocale,
  });

  static _OfflineLinkSaverAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_OfflineLinkSaverAppState>()!;
  }

  @override
  State<OfflineLinkSaverApp> createState() => _OfflineLinkSaverAppState();
}

class _OfflineLinkSaverAppState extends State<OfflineLinkSaverApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    saveLocale(locale);
  }

  void clearLocale() {
    setState(() => _locale = null);
    saveLocale(Locale(''));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThinkSave',
      debugShowCheckedModeBanner: false,

      // ── Localization ──
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── Themes ──
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,

      home: HomeScreen(
        repository: widget.repository,
        downloadQueue: widget.downloadQueue,
      ),
    );
  }
}
