import 'article_status.dart';

class Article {
  final String id;
  final String originalUrl;
  final String canonicalUrl;
  String title;
  String domain;
  String? author;
  String? excerpt;
  String? coverImagePath;
  String? contentPath;
  ArticleStatus status;
  int extractorVersion;
  bool isRead;
  bool isFavorite;
  double readingProgress;
  String? errorMessage;
  final DateTime createdAt;
  DateTime updatedAt;

  Article({
    required this.id,
    required this.originalUrl,
    required this.canonicalUrl,
    required this.title,
    required this.domain,
    this.author,
    this.excerpt,
    this.coverImagePath,
    this.contentPath,
    required this.status,
    this.extractorVersion = 1,
    this.isRead = false,
    this.isFavorite = false,
    this.readingProgress = 0.0,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_url': originalUrl,
      'canonical_url': canonicalUrl,
      'title': title,
      'domain': domain,
      'author': author,
      'excerpt': excerpt,
      'cover_image_path': coverImagePath,
      'content_path': contentPath,
      'status': status.value,
      'extractor_version': extractorVersion,
      'is_read': isRead ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'reading_progress': readingProgress,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as String,
      originalUrl: map['original_url'] as String,
      canonicalUrl: map['canonical_url'] as String,
      title: map['title'] as String,
      domain: map['domain'] as String,
      author: map['author'] as String?,
      excerpt: map['excerpt'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      contentPath: map['content_path'] as String?,
      status: ArticleStatusExtension.fromString(map['status'] as String),
      extractorVersion: map['extractor_version'] as int? ?? 1,
      isRead: (map['is_read'] as int?) == 1,
      isFavorite: (map['is_favorite'] as int?) == 1,
      readingProgress: (map['reading_progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Article copyWith({
    String? title,
    String? domain,
    String? author,
    String? excerpt,
    String? coverImagePath,
    String? contentPath,
    ArticleStatus? status,
    int? extractorVersion,
    bool? isRead,
    bool? isFavorite,
    double? readingProgress,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return Article(
      id: id,
      originalUrl: originalUrl,
      canonicalUrl: canonicalUrl,
      title: title ?? this.title,
      domain: domain ?? this.domain,
      author: author ?? this.author,
      excerpt: excerpt ?? this.excerpt,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      contentPath: contentPath ?? this.contentPath,
      status: status ?? this.status,
      extractorVersion: extractorVersion ?? this.extractorVersion,
      isRead: isRead ?? this.isRead,
      isFavorite: isFavorite ?? this.isFavorite,
      readingProgress: readingProgress ?? this.readingProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
