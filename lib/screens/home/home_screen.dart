import 'package:flutter/material.dart';
import '../../models/article.dart';
import '../../models/article_status.dart';
import '../../repositories/article_repository.dart';
import '../../services/downloader/download_queue_manager.dart';
import '../../widgets/article_card.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_loadArticles);
    _loadArticles();
  }

  @override
  void dispose() {
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
          SnackBar(content: Text('Error loading articles: $e')),
        );
      }
    }
  }

  void _showAddUrlDialog() {
    final urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'Paste URL here...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                await _saveUrl(url);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
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
            const SnackBar(content: Text('✓ Saved')),
          );
          _loadArticles();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL already saved')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving URL: $e')),
        );
      }
    }
  }

  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.isEmpty || path == '/') {
        return uri.host;
      }
      final segments = path.split('/');
      final lastSegment = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
      return lastSegment.replaceAll('-', ' ').replaceAll('_', ' ');
    } catch (e) {
      return url;
    }
  }

  Future<void> _deleteArticle(Article article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Article'),
        content: Text('Delete "${article.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
          const SnackBar(content: Text('No unread articles to download')),
        );
      }
      return;
    }

    final articleIds = downloadable.map((a) => a.id).toList();
    widget.downloadQueue.enqueueAll(articleIds);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Queued ${articleIds.length} articles for download')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Link Saver'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
            Tab(text: 'Downloaded'),
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search articles...',
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
          FloatingActionButton.small(
            onPressed: _downloadAllUnread,
            heroTag: 'download_all',
            child: const Icon(Icons.download),
          ),
          const SizedBox(height: 8),
          // Add URL FAB
          FloatingActionButton(
            onPressed: _showAddUrlDialog,
            heroTag: 'add_url',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
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
              'No articles yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share a link from Chrome, Facebook, or Telegram\nto save it for offline reading.',
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
              label: const Text('Paste URL'),
            ),
          ],
        ),
      ),
    );
  }
}
