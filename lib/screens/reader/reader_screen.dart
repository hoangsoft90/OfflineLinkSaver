import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ads/ad_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/article.dart';
import '../../models/content_block.dart';
import '../../repositories/article_repository.dart';
import '../../widgets/reader_controls.dart';

class ReaderScreen extends StatefulWidget {
  final Article article;
  final ArticleRepository repository;

  const ReaderScreen({
    super.key,
    required this.article,
    required this.repository,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  ArticleContent? _content;
  bool _isLoading = true;
  String? _error;
  double _fontSize = 16.0;
  ReaderTheme _currentTheme = ReaderTheme.light;
  final ScrollController _scrollController = ScrollController();
  late Article _article;

  // ── AdMob ──
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _loadContent();
    _setupScrollListener();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = AdService.instance.createBannerAd(
      size: AdSize.banner,
      onAdLoaded: (_) {
        if (mounted) setState(() => _isBannerAdLoaded = true);
      },
    )..load();
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _bannerAd?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // BUG 1+9: Debounced scroll listener that guards against Infinity
  Timer? _scrollDebounce;

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      // BUG 1: Guard against Infinity/zero maxScrollExtent
      if (maxScroll <= 0 || maxScroll.isInfinite) return;
      final currentScroll = _scrollController.offset;
      final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
      // BUG 9: Debounce — only save after 500ms of no scrolling
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(const Duration(milliseconds: 500), () {
        widget.repository.updateReadingProgress(_article.id, progress);
      });
    });
  }

  Future<void> _loadContent() async {
    try {
      if (_article.contentPath == null) {
        setState(() {
          _error = AppLocalizations.of(context).readerContentNotAvailable;
          _isLoading = false;
        });
        return;
      }

      final file = File(_article.contentPath!);
      if (!await file.exists()) {
        setState(() {
          _error = AppLocalizations.of(context).readerContentFileMissing;
          _isLoading = false;
        });
        return;
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final content = ArticleContent.fromJson(json);

      setState(() {
        _content = content;
        _isLoading = false;
      });

      // Mark as read
      if (!_article.isRead) {
        await widget.repository.markAsRead(_article.id);
        setState(() {
          _article = _article.copyWith(isRead: true);
        });
      }

      // Restore reading position
      if (_article.readingProgress > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final maxScroll = _scrollController.position.maxScrollExtent;
            final targetScroll = maxScroll * _article.readingProgress;
            _scrollController.jumpTo(targetScroll);
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).readerFailedToLoad(e.toString());
        _isLoading = false;
      });
    }
  }

  void _toggleFavorite() async {
    await widget.repository.toggleFavorite(_article.id);
    setState(() {
      _article = _article.copyWith(isFavorite: !_article.isFavorite);
    });
  }

  void _shareArticle() {
    final text = '${_article.title}\n\n${_article.originalUrl}';
    Share.share(text);
  }

  void _deleteArticle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteArticleTitle),
        content: Text(AppLocalizations.of(context).deleteArticleConfirm(_article.title)),
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
      await widget.repository.deleteArticle(_article.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _openInBrowser() async {
    final url = Uri.parse(_article.originalUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Color _getBackgroundColor() {
    switch (_currentTheme) {
      case ReaderTheme.light:
        return Colors.white;
      case ReaderTheme.dark:
        return Colors.grey.shade900;
      case ReaderTheme.sepia:
        return const Color(0xFFF5F0E6);
    }
  }

  Color _getTextColor() {
    switch (_currentTheme) {
      case ReaderTheme.light:
        return Colors.black87;
      case ReaderTheme.dark:
        return Colors.white70;
      case ReaderTheme.sepia:
        return const Color(0xFF5B4636);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _article.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _article.isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareArticle,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Banner Ad ──
          if (_isBannerAdLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          if (_content != null)
            ReaderControls(
              fontSize: _fontSize,
              onFontSizeChanged: (size) {
                setState(() => _fontSize = size);
              },
              currentTheme: _currentTheme,
              onThemeChanged: (theme) {
                setState(() => _currentTheme = theme);
              },
              onFavorite: _toggleFavorite,
              isFavorite: _article.isFavorite,
              onShare: _shareArticle,
              onDelete: _deleteArticle,
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).readerFailedToLoad(''),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: Text(AppLocalizations.of(context).readerOpenInBrowser),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_content == null || _content!.blocks.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).readerNoContent),
      );
    }

    return Container(
      color: _getBackgroundColor(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _content!.blocks.length + 2, // +2 for header and footer
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildArticleHeader();
          } else if (index == _content!.blocks.length + 1) {
            return _buildArticleFooter();
          } else {
            return _buildContentBlock(_content!.blocks[index - 1]);
          }
        },
      ),
    );
  }

  Widget _buildArticleHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          _article.title,
          style: TextStyle(
            fontSize: _fontSize + 8,
            fontWeight: FontWeight.bold,
            color: _getTextColor(),
          ),
        ),
        const SizedBox(height: 8),

        // Metadata
        Row(
          children: [
            if (_article.author != null && _article.author!.isNotEmpty) ...[
              Icon(Icons.person, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                _article.author!,
                style: TextStyle(
                  fontSize: _fontSize - 2,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Icon(Icons.language, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              _article.domain,
              style: TextStyle(
                fontSize: _fontSize - 2,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cover image
        // BUG 8: Use local file if cover image was downloaded, else network
        if (_article.coverImagePath != null && _article.coverImagePath!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _article.coverImagePath!.startsWith('http')
                ? Image.network(
                    _article.coverImagePath!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : Image.file(
                    File(_article.coverImagePath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        const SizedBox(height: 16),

        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildArticleFooter() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).readerFooter,
          style: TextStyle(
            fontSize: _fontSize - 4,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildContentBlock(ContentBlock block) {
    switch (block.type) {
      case BlockType.heading:
        return _buildHeading(block);
      case BlockType.paragraph:
        return _buildParagraph(block);
      case BlockType.image:
        return _buildImage(block);
      case BlockType.quote:
        return _buildQuote(block);
      case BlockType.list:
        return _buildList(block);
      case BlockType.code:
        return _buildCode(block);
      case BlockType.link:
        return _buildLink(block);
    }
  }

  Widget _buildHeading(ContentBlock block) {
    final fontSize = _fontSize + ((block.level ?? 1) * 2);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        block.text ?? '',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: _getTextColor(),
        ),
      ),
    );
  }

  Widget _buildParagraph(ContentBlock block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        block.text ?? '',
        style: TextStyle(
          fontSize: _fontSize,
          height: 1.6,
          color: _getTextColor(),
        ),
      ),
    );
  }

  Widget _buildImage(ContentBlock block) {
    if (block.imageUrl == null || block.imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if it's a local file path
    final isLocal = !block.imageUrl!.startsWith('http://') && 
                    !block.imageUrl!.startsWith('https://');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isLocal
                ? Image.file(
                    File(block.imageUrl!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildImagePlaceholder();
                    },
                  )
                : Image.network(
                    block.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildImagePlaceholder();
                    },
                  ),
          ),
          if (block.altText != null && block.altText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                block.altText!,
                style: TextStyle(
                  fontSize: _fontSize - 4,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image,
        size: 48,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildQuote(ContentBlock block) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Text(
        block.text ?? '',
        style: TextStyle(
          fontSize: _fontSize,
          fontStyle: FontStyle.italic,
          color: _getTextColor(),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildList(ContentBlock block) {
    if (block.items == null || block.items!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: block.items!.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key + 1}. ',
                  style: TextStyle(
                    fontSize: _fontSize,
                    color: _getTextColor(),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: 1.6,
                      color: _getTextColor(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCode(ContentBlock block) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _currentTheme == ReaderTheme.dark
            ? Colors.grey.shade800
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          block.text ?? '',
          style: TextStyle(
            fontSize: _fontSize - 2,
            fontFamily: 'monospace',
            color: _getTextColor(),
          ),
        ),
      ),
    );
  }

  Widget _buildLink(ContentBlock block) {
    if (block.url == null || block.url!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final url = Uri.parse(block.url!);
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        child: Text(
          block.text ?? block.url!,
          style: TextStyle(
            fontSize: _fontSize,
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
