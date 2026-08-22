import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ads/ad_service.dart';
import '../../l10n/app_localizations.dart';
import '../../core/onboarding/onboarding_state.dart';
import '../../core/onboarding/onboarding_step.dart';
import '../../models/article.dart';
import '../../models/article_status.dart';
import '../../models/category.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/category_repository.dart';
import '../../services/downloader/download_queue_manager.dart';
import '../../widgets/article_card.dart';
import '../../widgets/onboarding/feature_badge.dart';
import '../../widgets/onboarding/onboarding_coordinator.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ArticleRepository repository;
  final CategoryRepository categoryRepository;
  final DownloadQueueManager downloadQueue;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.categoryRepository,
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

  // Category & filter state
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _showFavoritesOnly = false;

  // ── AdMob ──
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // GlobalKeys for onboarding target widgets
  final GlobalKey _addUrlKey = GlobalKey();
  final GlobalKey _downloadAllKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadArticles();
      }
    });
    _loadArticles();
    _loadCategories();
    _initOnboarding();

    _downloadSub = widget.downloadQueue.progressStream.listen((_) {
      if (mounted && !_isDisposed) _loadArticles(silent: true);
    });
  }

  Future<void> _initOnboarding() async {
    await _onboardingState.init();
  }

  void _loadBannerAd() {
    _bannerAd = AdService.instance.createBannerAd(
      tag: 'home',
      size: AdSize.banner,
      onAdLoaded: (_) {
        if (mounted) setState(() => _isBannerAdLoaded = true);
      },
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _downloadSub?.cancel();
    _bannerAd?.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await widget.categoryRepository.getAll();
    if (mounted) setState(() => _categories = categories);
  }

  Future<void> _loadArticles({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      List<Article> articles;

      switch (_tabController.index) {
        case 0: // All
          articles = await widget.repository.getArticles(
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
            categoryId: _selectedCategoryId,
            isFavorite: _showFavoritesOnly ? true : null,
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
          if (_selectedCategoryId != null) {
            articles = articles.where((a) => a.categoryId == _selectedCategoryId).toList();
          }
          if (_showFavoritesOnly) {
            articles = articles.where((a) => a.isFavorite).toList();
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
          if (_selectedCategoryId != null) {
            articles = articles.where((a) => a.categoryId == _selectedCategoryId).toList();
          }
          if (_showFavoritesOnly) {
            articles = articles.where((a) => a.isFavorite).toList();
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
    String? selectedCategoryId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).addUrlTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).addUrlHint,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                  onSubmitted: (value) async {
                    final url = urlController.text.trim();
                    if (url.isNotEmpty) {
                      await _saveUrl(url, selectedCategoryId);
                      if (mounted) Navigator.pop(dialogContext);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Category picker
                Text(
                  AppLocalizations.of(context).category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // "None" option
                    ChoiceChip(
                      label: Text(AppLocalizations.of(context).none),
                      selected: selectedCategoryId == null,
                      onSelected: (_) => setDialogState(() => selectedCategoryId = null),
                    ),
                    // Category options
                    ..._categories.map((cat) => ChoiceChip(
                      avatar: Icon(Icons.circle, size: 12, color: cat.toColor),
                      label: Text(cat.name),
                      selected: selectedCategoryId == cat.id,
                      onSelected: (_) => setDialogState(() => selectedCategoryId = cat.id),
                    )),
                    // Add new category
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(AppLocalizations.of(context).addCategory),
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _showCategoryManageDialog();
                        // Re-open add URL dialog after managing categories
                        if (mounted) _showAddUrlDialog();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  await _saveUrl(url, selectedCategoryId);
                  if (mounted) Navigator.pop(dialogContext);
                }
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveUrl(String url, String? categoryId) async {
    try {
      final article = await widget.repository.insertArticle(
        originalUrl: url,
        title: _extractTitleFromUrl(url),
        categoryId: categoryId,
      );

      if (article != null) {
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
      if (path.isEmpty || path == '/') return host;
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return host;
      final lastSegment = segments.last;
      final cleaned = lastSegment
          .replaceAll(RegExp(r'[_-]'), ' ')
          .replaceAll(RegExp(r'\.(html?|php|aspx?)$'), '');
      if (cleaned.length < 3) return host;
      return '$host / $cleaned';
    } catch (e) {
      return url;
    }
  }

  // ── Category Management ──

  Future<void> _showCategoryManageDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _CategoryManageDialog(
        categoryRepository: widget.categoryRepository,
        onCategoriesChanged: () => _loadCategories(),
      ),
    );
  }

  // ── Download single article ──

  void _downloadArticle(Article article) {
    widget.downloadQueue.enqueue(article.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).downloadQueued)),
    );
    _loadArticles(silent: true);
  }

  // ── Article actions ──

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

  void _openReader(Article article) {
    // Show interstitial ad if enabled, then navigate
    if (AdService.instance.showInterstitialAd(
      onDismissed: () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(
                article: article,
                repository: widget.repository,
              ),
            ),
          ).then((_) => _loadArticles(silent: true));
        }
      },
    )) {
      // Ad shown, will navigate on dismiss
      return;
    }
    // No ad ready, navigate immediately
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          article: article,
          repository: widget.repository,
        ),
      ),
    ).then((_) => _loadArticles(silent: true));
  }

  @override
  Widget build(BuildContext context) {
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
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_searchQuery.isNotEmpty) {
            _searchController.clear();
            setState(() => _searchQuery = '');
            _loadArticles();
          } else if (_tabController.index != 0) {
            _tabController.animateTo(0);
          } else if (_selectedCategoryId != null || _showFavoritesOnly) {
            setState(() {
              _selectedCategoryId = null;
              _showFavoritesOnly = false;
            });
            _loadArticles();
          } else {
            Navigator.of(context).pop();
          }
        },
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

              // ── Filter chips (category + favorites) ──
              _buildFilterChips(),

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
                                  onTap: () => _openReader(article),
                                  onDelete: () => _deleteArticle(article),
                                  onRetry: () => _retryDownload(article),
                                  onDownload: article.status != ArticleStatus.ready
                                      ? () => _downloadArticle(article)
                                      : null,
                                  onToggleFavorite: () async {
                                    await widget.repository.toggleFavorite(article.id);
                                    _loadArticles();
                                  },
                                  onCategoryChanged: (catId) async {
                                    await widget.repository.setCategory(article.id, catId);
                                    _loadArticles();
                                  },
                                  categories: _categories,
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          bottomNavigationBar: (_isBannerAdLoaded && _bannerAd != null)
              ? SafeArea(
                  top: false,
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                )
              : null,
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 58),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasFilters = _selectedCategoryId != null || _showFavoritesOnly;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Favorites toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: _showFavoritesOnly ? Colors.red : null,
              ),
              label: Text(AppLocalizations.of(context).filterFavorites),
              selected: _showFavoritesOnly,
              onSelected: (selected) {
                setState(() => _showFavoritesOnly = selected);
                _loadArticles();
              },
            ),
          ),

          // Clear all filter
          if (hasFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.clear, size: 16),
                label: Text(AppLocalizations.of(context).clearFilters),
                onPressed: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _showFavoritesOnly = false;
                  });
                  _loadArticles();
                },
              ),
            ),

          // Category chips
          ..._categories.map((cat) {
            final isSelected = _selectedCategoryId == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () => _showCategoryManageDialog(),
                child: FilterChip(
                  avatar: Icon(Icons.circle, size: 12, color: cat.toColor),
                  label: Text(cat.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedCategoryId = selected ? cat.id : null);
                    _loadArticles();
                  },
                ),
              ),
            );
          }),

          // Manage categories button
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ActionChip(
              avatar: const Icon(Icons.settings, size: 16),
              label: Text(AppLocalizations.of(context).manage),
              onPressed: () => _showCategoryManageDialog(),
            ),
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
            Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).emptyStateTitle,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).emptyStateBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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

// ── Category Management Dialog ──

class _CategoryManageDialog extends StatefulWidget {
  final CategoryRepository categoryRepository;
  final VoidCallback onCategoriesChanged;

  const _CategoryManageDialog({
    required this.categoryRepository,
    required this.onCategoriesChanged,
  });

  @override
  State<_CategoryManageDialog> createState() => _CategoryManageDialogState();
}

class _CategoryManageDialogState extends State<_CategoryManageDialog> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepository.getAll();
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    String selectedColor = '#2196F3';
    final colors = ['#2196F3', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0', '#00BCD4', '#F44336', '#795548'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).addCategory),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).categoryNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final hex = c.replaceFirst('#', '');
                    final color = Color(int.parse('FF$hex', radix: 16));
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == c
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: selectedColor == c
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await widget.categoryRepository.create(
        nameController.text.trim(),
        color: selectedColor,
      );
      widget.onCategoriesChanged();
      await _load();
    }
  }

  Future<void> _editCategory(Category category) async {
    final nameController = TextEditingController(text: category.name);
    String selectedColor = category.color;
    final colors = ['#2196F3', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0', '#00BCD4', '#F44336', '#795548'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).editCategory),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final hex = c.replaceFirst('#', '');
                    final color = Color(int.parse('FF$hex', radix: 16));
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == c
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: selectedColor == c
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await widget.categoryRepository.update(
        category.id,
        name: nameController.text.trim(),
        color: selectedColor,
      );
      widget.onCategoriesChanged();
      await _load();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteCategory),
        content: Text(AppLocalizations.of(context).deleteCategoryConfirm(category.name)),
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
      await widget.categoryRepository.delete(category.id);
      widget.onCategoriesChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).manageCategories),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: _categories.isEmpty
                  ? Text(
                      AppLocalizations.of(context).noCategories,
                      style: TextStyle(color: Colors.grey.shade500),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return ListTile(
                          leading: Icon(Icons.circle, color: cat.toColor, size: 20),
                          title: Text(cat.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editCategory(cat),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, size: 20, color: Colors.red.shade300),
                                onPressed: () => _deleteCategory(cat),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        TextButton.icon(
          onPressed: _addCategory,
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context).addCategory),
        ),
      ],
    );
  }
}
