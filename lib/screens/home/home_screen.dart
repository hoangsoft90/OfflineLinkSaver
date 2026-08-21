import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../core/onboarding/onboarding_state.dart';
import '../../core/onboarding/onboarding_step.dart';
import '../../models/article.dart';
import '../../models/article_status.dart';
import '../../repositories/article_repository.dart';
import '../../services/downloader/download_queue_manager.dart';
import '../../widgets/article_card.dart';
import '../../widgets/onboarding/feature_badge.dart';
import '../../widgets/onboarding/onboarding_coordinator.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ArticleRepository repository;
  final DownloadQueueManager downloadQueue;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.downloadQueue,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Article> _articles = [];
  bool _isLoading = true;
  StreamSubscription<DownloadProgress>? _downloadSub;
  bool _isDisposed = false;
  final OnboardingState _onboardingState = OnboardingState();

  // GlobalKeys for onboarding target widgets
  final GlobalKey _addUrlKey = GlobalKey();
  final GlobalKey _downloadAllKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // BUG 5: Only reload when tab animation settles, not on every index change
    _tabController.animation?.addListener(() {
      // animation fires twice per tab change — this listener is on the animation
      // so we don't need indexIsChanging guard here
    });
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadArticles();
      }
    });
    _loadArticles();
    _initOnboarding();

    // BUG 10: Listen to download progress and refresh article list
    _downloadSub = widget.downloadQueue.progressStream.listen((_) {
      // Extra safety: check mounted after async gap in _loadArticles too
      if (mounted && !_isDisposed) _loadArticles();
    });
  }

  Future<void> _initOnboarding() async {
    await _onboardingState.init();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _downloadSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);

    try {
      List<Article> articles;
      
      switch (_tabController.index) {
        case 0: // All
          articles = await widget.repository.getArticles(
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          );
          break;
        case 1: // Unread
          articles = await widget.repository.getUnreadArticles();
          if (_searchQuery.isNotEmpty) {
            articles = articles.where((a) => 
              a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.domain.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
          }
          break;
        case 2: // Downloaded
          articles = await widget.repository.getDownloadedArticles();
          if (_searchQuery.isNotEmpty) {
            articles = articles.where((a) => 
              a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.domain.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
          }
          break;
        default:
          articles = [];
      }

      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorLoadingArticles(e.toString()))),
        );
      }
    }
  }

  void _showAddUrlDialog() {
    final urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).addUrlTitle),
        content: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).addUrlHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                await _saveUrl(url);
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUrl(String url) async {
    try {
      // Insert article with queued status
      final article = await widget.repository.insertArticle(
        originalUrl: url,
        title: _extractTitleFromUrl(url),
      );

      if (article != null) {
        // Enqueue for download
        widget.downloadQueue.enqueue(article.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).savedSuccess)),
          );
          _loadArticles();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).urlAlreadySaved)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorSavingUrl(e.toString()))),
        );
      }
    }
  }

  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceFirst('www.', '');
      final path = uri.path;
      if (path.isEmpty || path == '/') {
        return host;
      }
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return host;
      // Use last meaningful segment, clean up
      final lastSegment = segments.last;
      final cleaned = lastSegment
          .replaceAll(RegExp(r'[_-]'), ' ')
          // BUG 2: Fixed regex — \.(html?) was double-escaped, now matches .html correctly
          .replaceAll(RegExp(r'\.(html?|php|aspx?)$'), '');
      if (cleaned.length < 3) return host;
      return '$host / $cleaned';
    } catch (e) {
      return url;
    }
  }

  Future<void> _deleteArticle(Article article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteArticleTitle),
        content: Text(AppLocalizations.of(context).deleteArticleConfirm(article.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repository.deleteArticle(article.id);
      _loadArticles();
    }
  }

  void _retryDownload(Article article) {
    widget.downloadQueue.enqueue(article.id);
    _loadArticles();
  }

  Future<void> _downloadAllUnread() async {
    final unreadArticles = await widget.repository.getUnreadArticles();
    final downloadable = unreadArticles.where((a) => 
      a.status == ArticleStatus.queued ||
      a.status == ArticleStatus.failed ||
      a.status == ArticleStatus.online_only
    ).toList();

    if (downloadable.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).noUnreadToDownload)),
        );
      }
      return;
    }

    final articleIds = downloadable.map((a) => a.id).toList();
    widget.downloadQueue.enqueueAll(articleIds);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).queuedCount(articleIds.length))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define onboarding steps for this screen
    final onboardingSteps = [
      OnboardingStep(
        id: 'search',
        targetKey: _searchKey,
        title: AppLocalizations.of(context).onboardingSearchTitle,
        message: AppLocalizations.of(context).onboardingSearchMessage,
        position: TooltipPosition.bottom,
        stepNumber: 1,
        totalSteps: 3,
      ),
      OnboardingStep(
        id: 'download_all',
        targetKey: _downloadAllKey,
        title: AppLocalizations.of(context).onboardingDownloadAllTitle,
        message: AppLocalizations.of(context).onboardingDownloadAllMessage,
        position: TooltipPosition.left,
        stepNumber: 2,
        totalSteps: 3,
      ),
      OnboardingStep(
        id: 'add_url',
        targetKey: _addUrlKey,
        title: AppLocalizations.of(context).onboardingAddUrlTitle,
        message: AppLocalizations.of(context).onboardingAddUrlMessage,
        position: TooltipPosition.left,
        stepNumber: 3,
        totalSteps: 3,
      ),
    ];

    return OnboardingCoordinator(
      flowId: 'home_v1',
      state: _onboardingState,
      steps: onboardingSteps,
      child: Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppLocalizations.of(context).homeTabAll),
            Tab(text: AppLocalizations.of(context).homeTabUnread),
            Tab(text: AppLocalizations.of(context).homeTabDownloaded),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    repository: widget.repository,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: _searchKey,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadArticles();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _loadArticles();
              },
            ),
          ),

          // Article list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _articles.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadArticles,
                        child: ListView.builder(
                          itemCount: _articles.length,
                          itemBuilder: (context, index) {
                            final article = _articles[index];
                            return ArticleCard(
                              article: article,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReaderScreen(
                                      article: article,
                                      repository: widget.repository,
                                    ),
                                  ),
                                );
                              },
                              onDelete: () => _deleteArticle(article),
                              onRetry: () => _retryDownload(article),
                              onToggleFavorite: () async {
                                await widget.repository.toggleFavorite(article.id);
                                _loadArticles();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Download All Unread FAB
          FeatureBadge(
            key: _downloadAllKey,
            visible: true,
            label: AppLocalizations.of(context).badgeNew,
            variant: BadgeVariant.label,
            child: FloatingActionButton.small(
              onPressed: _downloadAllUnread,
              heroTag: 'download_all',
              child: const Icon(Icons.download),
            ),
          ),
          const SizedBox(height: 8),
          // Add URL FAB
          FeatureBadge(
            key: _addUrlKey,
            visible: true,
            variant: BadgeVariant.dot,
            child: FloatingActionButton(
              onPressed: _showAddUrlDialog,
              heroTag: 'add_url',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    ),
    ); // end OnboardingCoordinator
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).emptyStateTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).emptyStateBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddUrlDialog,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).pasteUrl),
            ),
          ],
        ),
      ),
    );
  }
}
