import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'core/database/database_helper.dart';
import 'repositories/article_repository.dart';
import 'services/downloader/download_queue_manager.dart';
import 'services/share_handler/share_handler.dart';
import 'screens/home/home_screen.dart';

/// SharedPreferences key for persisted locale choice.
const String _kLocalePrefKey = 'app_locale';

/// Returns the user's saved locale, or null to follow the system default.
Future<Locale?> _loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kLocalePrefKey);
  if (code == null || code.isEmpty) return null;
  // Support "en", "vi", etc.
  return Locale(code);
}

/// Persists the user's locale choice.
Future<void> saveLocale(Locale locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLocalePrefKey, locale.languageCode);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted locale before building UI
  final savedLocale = await _loadSavedLocale();

  // Run startup sanitization before building UI
  // This resets any stuck downloads from previous sessions
  final db = await DatabaseHelper.database;
  await DatabaseHelper.startupSanitization(db);

  // Initialize repository and services
  final repository = ArticleRepository();
  final downloadQueue = DownloadQueueManager(repository: repository);
  final shareHandler = ShareHandler(
    repository: repository,
    downloadQueue: downloadQueue,
  );

  // Initialize share handler for Android
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

  /// Access state from anywhere via [OfflineLinkSaverApp.of(context)].
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

  /// Change the app locale at runtime.
  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    saveLocale(locale);
  }

  /// Reset to system default locale.
  void clearLocale() {
    setState(() => _locale = null);
    saveLocale(Locale('')); // empty = system default
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Link Saver',
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
