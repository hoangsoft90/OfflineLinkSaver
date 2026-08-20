import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../../models/content_block.dart';
import '../../core/network/network_client.dart';

/// HTTP-based article extractor (Layer 1)
/// Fetches HTML and parses using heuristic rules
class HttpExtractor {
  /// Minimum word count to consider extraction successful
  static const int _minWordCount = 200;

  /// File extensions that indicate non-HTML content (not articles)
  static final _binaryExtensions = {
    '.mp3', '.mp4', '.wav', '.flac', '.aac', '.ogg', '.ac3', '.wma',
    '.avi', '.mkv', '.mov', '.wmv', '.webm', '.m4v',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.zip', '.rar', '.7z', '.tar', '.gz',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.ico',
    '.apk', '.exe', '.dmg', '.deb', '.rpm',
  };

  /// Extract article content from URL using HTTP fetch
  Future<ExtractionResult> extract(String url) async {
    try {
      // Quick check: reject known binary file extensions
      final uri = Uri.parse(url);
      final pathLower = uri.path.toLowerCase();
      for (final ext in _binaryExtensions) {
        if (pathLower.endsWith(ext)) {
          return ExtractionResult(
            success: false,
            error: 'Not a webpage (file type: $ext)',
          );
        }
      }

      // Fetch HTML with redirect resolution
      final response = await NetworkClient.fetchWithRedirects(url);
      
      if (response.statusCode != 200) {
        return ExtractionResult(
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      var htmlContent = response.body;
      
      // Strip <script> and <style> tags to reduce document size
      htmlContent = htmlContent.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
      htmlContent = htmlContent.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
      
      // Parse HTML
      final document = html_parser.parse(htmlContent);
      
      // Extract article content using heuristics
      final blocks = _extractBlocks(document);
      
      // Extract metadata
      final title = _extractTitle(document);
      final author = _extractAuthor(document);
      final excerpt = _extractExcerpt(document);
      final coverImage = _extractCoverImage(document, url);

      // Check if we got enough content
      final content = ArticleContent(blocks: blocks);
      if (content.wordCount < _minWordCount) {
        return ExtractionResult(
          success: false,
          error: 'Insufficient content (${content.wordCount} words)',
          needsWebView: true,
        );
      }

      return ExtractionResult(
        success: true,
        content: content,
        title: title,
        author: author,
        excerpt: excerpt,
        coverImage: coverImage,
      );
    } on TimeoutException {
      return ExtractionResult(
        success: false,
        error: 'Connection timeout',
      );
    } catch (e) {
      return ExtractionResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Extract content blocks from HTML document
  List<ContentBlock> _extractBlocks(Document document) {
    final blocks = <ContentBlock>[];

    // Try to find main article content using heuristics
    Element? articleElement = _findArticleElement(document);
    
    if (articleElement == null) {
      // Fallback: try common content containers
      articleElement = document.querySelector('main') ??
          document.querySelector('.post-content') ??
          document.querySelector('.article-content') ??
          document.querySelector('.entry-content');
    }

    if (articleElement == null) {
      // Last resort: use body
      articleElement = document.body;
    }

    if (articleElement == null) return blocks;

    // Process child elements
    for (final element in articleElement.children) {
      _processElement(element, blocks);
    }

    return blocks;
  }

  /// Find article element using common selectors
  Element? _findArticleElement(Document document) {
    // Try <article> tag first
    var article = document.querySelector('article');
    if (article != null) return article;

    // Try common class names
    final classNames = [
      'post-content',
      'article-content',
      'entry-content',
      'story-body',
      'article-body',
      'post-body',
      'content',
    ];

    for (final className in classNames) {
      article = document.querySelector('.$className');
      if (article != null) return article;
    }

    return null;
  }

  /// Process a single HTML element and add to blocks
  void _processElement(Element element, List<ContentBlock> blocks) {
    final tag = element.localName;
    final text = element.text.trim();

    // Skip empty elements and scripts
    if (text.isEmpty || tag == 'script' || tag == 'style') {
      return;
    }

    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        blocks.add(ContentBlock(
          type: BlockType.heading,
          text: text,
          level: int.parse(tag?.substring(1) ?? '1'),
        ));
        break;

      case 'p':
        if (text.isNotEmpty) {
          blocks.add(ContentBlock(
            type: BlockType.paragraph,
            text: text,
          ));
        }
        break;

      case 'img':
        final src = element.attributes['src'];
        final alt = element.attributes['alt'];
        if (src != null && src.isNotEmpty) {
          blocks.add(ContentBlock(
            type: BlockType.image,
            imageUrl: src,
            altText: alt,
          ));
        }
        break;

      case 'blockquote':
        blocks.add(ContentBlock(
          type: BlockType.quote,
          text: text,
        ));
        break;

      case 'ul':
      case 'ol':
        final items = element.children
            .where((child) => child.localName == 'li')
            .map((li) => li.text.trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (items.isNotEmpty) {
          blocks.add(ContentBlock(
            type: BlockType.list,
            items: items,
          ));
        }
        break;

      case 'pre':
      case 'code':
        blocks.add(ContentBlock(
          type: BlockType.code,
          text: text,
          language: element.attributes['class']?.replaceFirst('language-', ''),
        ));
        break;

      default:
        // For other elements, process children recursively
        for (final child in element.children) {
          _processElement(child, blocks);
        }
    }
  }

  /// Extract title from document
  String _extractTitle(Document document) {
    // Try og:title first
    var title = document.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (title != null && title.isNotEmpty) return title;

    // Try <title> tag
    title = document.querySelector('title')?.text;
    if (title != null && title.isNotEmpty) return title;

    // Try h1
    title = document.querySelector('h1')?.text;
    if (title != null && title.isNotEmpty) return title;

    return 'Untitled';
  }

  /// Extract author from document
  String? _extractAuthor(Document document) {
    // Try meta tags
    var author = document.querySelector('meta[name="author"]')?.attributes['content'];
    if (author != null && author.isNotEmpty) return author;

    // Try common class names
    final authorSelectors = [
      '.author',
      '.byline',
      '.article-author',
      '[rel="author"]',
    ];

    for (final selector in authorSelectors) {
      author = document.querySelector(selector)?.text.trim();
      if (author != null && author.isNotEmpty) return author;
    }

    return null;
  }

  /// Extract excerpt from document
  String? _extractExcerpt(Document document) {
    // Try og:description
    var excerpt = document.querySelector('meta[property="og:description"]')?.attributes['content'];
    if (excerpt != null && excerpt.isNotEmpty) return excerpt;

    // Try meta description
    excerpt = document.querySelector('meta[name="description"]')?.attributes['content'];
    if (excerpt != null && excerpt.isNotEmpty) return excerpt;

    // Try first paragraph
    excerpt = document.querySelector('p')?.text.trim();
    if (excerpt != null && excerpt.length > 160) {
      excerpt = '${excerpt.substring(0, 157)}...';
    }

    return excerpt;
  }

  /// Extract cover image URL
  String? _extractCoverImage(Document document, String baseUrl) {
    // Try og:image
    var imageUrl = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Make absolute URL
      return _makeAbsoluteUrl(imageUrl, baseUrl);
    }

    // Try first image in article
    final article = document.querySelector('article') ?? document.querySelector('main');
    if (article != null) {
      final img = article.querySelector('img');
      imageUrl = img?.attributes['src'];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return _makeAbsoluteUrl(imageUrl, baseUrl);
      }
    }

    return null;
  }

  /// Convert relative URL to absolute
  String _makeAbsoluteUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final baseUri = Uri.parse(baseUrl);
    
    if (url.startsWith('//')) {
      return '${baseUri.scheme}:$url';
    }

    if (url.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}$url';
    }

    // Relative URL
    return '${baseUri.scheme}://${baseUri.host}/${url}';
  }
}

/// Result of extraction attempt
class ExtractionResult {
  final bool success;
  final ArticleContent? content;
  final String? title;
  final String? author;
  final String? excerpt;
  final String? coverImage;
  final String? error;
  final bool needsWebView;

  ExtractionResult({
    required this.success,
    this.content,
    this.title,
    this.author,
    this.excerpt,
    this.coverImage,
    this.error,
    this.needsWebView = false,
  });
}
