import '../../models/content_block.dart';

/// Sanitizer for article content
/// Removes dangerous elements and attributes
class Sanitizer {
  /// Sanitize content blocks
  /// Removes dangerous content and validates URLs
  List<ContentBlock> sanitize(List<ContentBlock> blocks) {
    return blocks.map((block) => _sanitizeBlock(block)).where((block) => block != null).cast<ContentBlock>().toList();
  }

  /// Sanitize a single content block
  ContentBlock? _sanitizeBlock(ContentBlock block) {
    switch (block.type) {
      case BlockType.image:
        return _sanitizeImage(block);
      case BlockType.link:
        return _sanitizeLink(block);
      case BlockType.paragraph:
      case BlockType.heading:
      case BlockType.quote:
        return _sanitizeText(block);
      case BlockType.list:
        return _sanitizeList(block);
      case BlockType.code:
        return _sanitizeCode(block);
    }
  }

  /// Sanitize image block - only allow http/https URLs
  ContentBlock? _sanitizeImage(ContentBlock block) {
    final url = block.imageUrl;
    if (url == null || url.isEmpty) return null;

    // Only allow http/https
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null; // Skip image with invalid URL
    }

    return block;
  }

  /// Sanitize link block
  ContentBlock? _sanitizeLink(ContentBlock block) {
    final url = block.url;
    if (url == null || url.isEmpty) return null;

    // Reject dangerous schemes
    if (url.startsWith('javascript:') ||
        url.startsWith('data:') ||
        url.startsWith('file:') ||
        url.startsWith('intent:')) {
      return null;
    }

    return block;
  }

  /// Sanitize text block - remove on* attributes
  ContentBlock _sanitizeText(ContentBlock block) {
    if (block.text == null) return block;

    // Clean text content - remove any HTML tags that might be embedded
    var cleanText = block.text!
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<iframe[^>]*>.*?</iframe>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<object[^>]*>.*?</object>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<embed[^>]*>.*?</embed>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<form[^>]*>.*?</form>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove any remaining HTML tags
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), ''); // Remove on* attributes

    return ContentBlock(
      type: block.type,
      text: cleanText,
      level: block.level,
      caption: block.caption,
    );
  }

  /// Sanitize list block
  ContentBlock _sanitizeList(ContentBlock block) {
    if (block.items == null) return block;

    // Clean each item
    final cleanItems = block.items!
        .map((item) => item
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), ''))
        .where((item) => item.isNotEmpty)
        .toList();

    return ContentBlock(
      type: block.type,
      items: cleanItems,
    );
  }

  /// Sanitize code block
  ContentBlock _sanitizeCode(ContentBlock block) {
    if (block.text == null) return block;

    // Code blocks should preserve content but remove any script tags
    var cleanText = block.text!
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    return ContentBlock(
      type: block.type,
      text: cleanText,
      language: block.language,
    );
  }

  /// Check if content needs sanitization
  static bool needsSanitization(List<ContentBlock> blocks) {
    for (final block in blocks) {
      if (block.text != null) {
        if (block.text!.contains('<script') ||
            block.text!.contains('<iframe') ||
            block.text!.contains('javascript:')) {
          return true;
        }
      }
      if (block.imageUrl != null) {
        if (!block.imageUrl!.startsWith('http')) {
          return true;
        }
      }
    }
    return false;
  }
}
