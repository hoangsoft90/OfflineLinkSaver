import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/content_block.dart';
import 'http_extractor.dart';

/// WebView fallback extractor (Layer 2)
/// Used when HTTP extractor fails to get enough content
/// Concurrency limited to 1 WebView instance at a time
class WebViewFallbackExtractor {
  static const int _renderTimeoutSeconds = 10;
  static const int _minWordCount = 100; // Lowered to support shorter articles

  /// Extract article using WebView
  /// Returns null if extraction fails
  Future<ExtractionResult?> extract(String url) async {
    try {
      // Create a completer to handle async WebView loading
      final completer = Completer<ExtractionResult?>();
      
      // Create WebView controller
      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String pageUrl) async {
              try {
                // Wait a bit for dynamic content to load
                await Future.delayed(const Duration(seconds: 2));
                
                // Extract content using JavaScript
                final result = await _extractContent(controller, url);
                if (!completer.isCompleted) {
                  completer.complete(result);
                }
              } catch (e) {
                if (!completer.isCompleted) {
                  completer.complete(null);
                }
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            },
          ),
        );

      // Navigate to URL
      await controller.loadRequest(Uri.parse(url));

      // Wait for extraction with timeout
      final result = await completer.future.timeout(
        const Duration(seconds: _renderTimeoutSeconds),
        onTimeout: () {
          return null;
        },
      );

      return result;
    } catch (e) {
      return null;
    }
  }

  /// Extract content from loaded WebView using JavaScript
  Future<ExtractionResult?> _extractContent(
    WebViewController controller,
    String originalUrl,
  ) async {
    try {
      // JavaScript to extract article content
      final script = '''
        (function() {
          // Find article content
          var article = document.querySelector('article') ||
                       document.querySelector('main') ||
                       document.querySelector('.post-content') ||
                       document.querySelector('.article-content') ||
                       document.querySelector('.entry-content');
          
          if (!article) article = document.body;
          if (!article) return null;
          
          // Extract text content
          var blocks = [];
          var elements = article.querySelectorAll('h1, h2, h3, h4, h5, h6, p, img, blockquote, ul, ol, pre, code');
          
          elements.forEach(function(el) {
            var tag = el.tagName.toLowerCase();
            var text = el.textContent.trim();
            
            if (tag.charAt(0) === 'h' && '123456'.indexOf(tag.charAt(1)) !== -1) {
              blocks.push({
                type: 'heading',
                text: text,
                level: parseInt(tag.charAt(1))
              });
            } else if (tag === 'p' && text.length > 0) {
              blocks.push({
                type: 'paragraph',
                text: text
              });
            } else if (tag === 'img') {
              var src = el.getAttribute('src');
              var alt = el.getAttribute('alt');
              if (src) {
                blocks.push({
                  type: 'image',
                  imageUrl: src,
                  altText: alt
                });
              }
            } else if (tag === 'blockquote') {
              blocks.push({
                type: 'quote',
                text: text
              });
            } else if (tag === 'ul' || tag === 'ol') {
              var items = [];
              el.querySelectorAll('li').forEach(function(li) {
                items.push(li.textContent.trim());
              });
              if (items.length > 0) {
                blocks.push({
                  type: 'list',
                  items: items
                });
              }
            } else if (tag === 'pre' || tag === 'code') {
              blocks.push({
                type: 'code',
                text: text,
                language: el.className.replace('language-', '')
              });
            }
          });
          
          // Extract metadata
          var title = document.querySelector('meta[property="og:title"]')?.content ||
                     document.title;
          var author = document.querySelector('meta[name="author"]')?.content ||
                      document.querySelector('.author')?.textContent;
          var excerpt = document.querySelector('meta[property="og:description"]')?.content ||
                       document.querySelector('meta[name="description"]')?.content;
          var coverImage = document.querySelector('meta[property="og:image"]')?.content;
          
          return JSON.stringify({
            blocks: blocks,
            title: title,
            author: author,
            excerpt: excerpt,
            coverImage: coverImage
          });
        })();
      ''';

      final result = await controller.runJavaScriptReturningResult(script);
      
      if (result.toString() == 'null') {
        return null;
      }

      // Parse result
      final jsonStr = result.toString();
      if (jsonStr.isEmpty) return null;

      // Parse JSON
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }

      // Parse blocks
      final blocks = <ContentBlock>[];
      final blocksList = json['blocks'] as List<dynamic>?;
      if (blocksList != null) {
        for (final blockJson in blocksList) {
          if (blockJson is Map<String, dynamic>) {
            final block = _parseBlock(blockJson);
            if (block != null) blocks.add(block);
          }
        }
      }

      // Extract metadata
      final title = json['title'] as String? ?? 'Untitled';
      final author = json['author'] as String?;
      final excerpt = json['excerpt'] as String?;
      final coverImage = json['coverImage'] as String?;

      final content = ArticleContent(blocks: blocks);
      
      if (content.wordCount < _minWordCount) {
        return ExtractionResult(
          success: false,
          error: 'Insufficient content (${content.wordCount} words)',
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
    } catch (e) {
      return null;
    }
  }

  /// Parse a single block from JSON map
  ContentBlock? _parseBlock(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String?;
      if (type == null) return null;

      final text = json['text'] as String?;
      final imageUrl = json['imageUrl'] as String?;
      final altText = json['altText'] as String?;
      final level = json['level'] as int?;

      // Parse items array if present
      List<String>? items;
      final itemsList = json['items'] as List<dynamic>?;
      if (itemsList != null) {
        items = itemsList.cast<String>();
      }

      return ContentBlock(
        type: BlockType.values.firstWhere(
          (t) => t.name == type,
          orElse: () => BlockType.paragraph,
        ),
        text: text,
        imageUrl: imageUrl,
        altText: altText,
        level: level,
        items: items,
      );
    } catch (e) {
      return null;
    }
  }
}
