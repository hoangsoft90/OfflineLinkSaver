/// Types of content blocks in an article
enum BlockType {
  heading,
  paragraph,
  image,
  quote,
  list,
  code,
  link,
}

/// A single content block in an article
class ContentBlock {
  final BlockType type;
  final String? text;
  final String? imageUrl;
  final String? altText;
  final String? caption;
  final List<String>? items; // For lists
  final int? level; // For headings (1-6)
  final String? language; // For code blocks
  final String? url; // For links

  ContentBlock({
    required this.type,
    this.text,
    this.imageUrl,
    this.altText,
    this.caption,
    this.items,
    this.level,
    this.language,
    this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      'imageUrl': imageUrl,
      'altText': altText,
      'caption': caption,
      'items': items,
      'level': level,
      'language': language,
      'url': url,
    };
  }

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: BlockType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BlockType.paragraph,
      ),
      text: json['text'] as String?,
      imageUrl: json['imageUrl'] as String?,
      altText: json['altText'] as String?,
      caption: json['caption'] as String?,
      items: (json['items'] as List<dynamic>?)?.cast<String>(),
      level: json['level'] as int?,
      language: json['language'] as String?,
      url: json['url'] as String?,
    );
  }
}

/// Complete article content
class ArticleContent {
  final List<ContentBlock> blocks;

  ArticleContent({required this.blocks});

  Map<String, dynamic> toJson() {
    return {
      'blocks': blocks.map((b) => b.toJson()).toList(),
    };
  }

  factory ArticleContent.fromJson(Map<String, dynamic> json) {
    return ArticleContent(
      blocks: (json['blocks'] as List<dynamic>)
          .map((b) => ContentBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert blocks to plain text for word count
  String toPlainText() {
    return blocks
        .where((b) => b.text != null)
        .map((b) => b.text!)
        .join(' ');
  }

  /// Get word count
  int get wordCount {
    return toPlainText().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
}
