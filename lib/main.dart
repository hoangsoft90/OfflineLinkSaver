import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/database/database_helper.dart';
import 'repositories/article_repository.dart';
import 'services/downloader/download_queue_manager.dart';
import 'services/share_handler/share_handler.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  ));
}

class OfflineLinkSaverApp extends StatelessWidget {
  final ArticleRepository repository;
  final DownloadQueueManager downloadQueue;
  final ShareHandler shareHandler;

  const OfflineLinkSaverApp({
    super.key,
    required this.repository,
    required this.downloadQueue,
    required this.shareHandler,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Link Saver',
      debugShowCheckedModeBanner: false,
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
        repository: repository,
        downloadQueue: downloadQueue,
      ),
    );
  }
}
