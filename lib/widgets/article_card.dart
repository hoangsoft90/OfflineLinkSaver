import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/article.dart';
import '../models/article_status.dart';
import '../models/category.dart';
import 'status_badge.dart';

/// Card widget for displaying article in library
class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onDownload;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<String?>? onCategoryChanged;
  final List<Category> categories;

  const ArticleCard({
    super.key,
    required this.article,
    this.onTap,
    this.onDelete,
    this.onRetry,
    this.onDownload,
    this.onToggleFavorite,
    this.onCategoryChanged,
    this.categories = const [],
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = article.categoryId != null
        ? categories.where((c) => c.id == article.categoryId).map((c) => c.name).firstOrNull
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: article.status == ArticleStatus.ready ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and favorite
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onToggleFavorite != null)
                    IconButton(
                      icon: Icon(
                        article.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: article.isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: onToggleFavorite,
                    ),
                ],
              ),

              // Category badge
              if (categoryName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Domain and author
              if (article.domain.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    article.domain,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),

              if (article.author != null && article.author!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    AppLocalizations.of(context).articleAuthor(article.author!),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),

              // Excerpt
              if (article.excerpt != null && article.excerpt!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    article.excerpt!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 12),

              // Footer with status and actions
              Row(
                children: [
                  // Status badge
                  StatusBadge(
                    status: article.status,
                    onRetry: article.status.canBeRetried ? onRetry : null,
                  ),

                  const Spacer(),

                  // Download button (for non-ready articles)
                  if (onDownload != null)
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: onDownload,
                      color: Colors.blue,
                      tooltip: AppLocalizations.of(context).download,
                    ),

                  // Category picker button
                  if (onCategoryChanged != null && categories.isNotEmpty)
                    PopupMenuButton<String?>(
                      icon: Icon(
                        Icons.label_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                      tooltip: AppLocalizations.of(context).category,
                      onSelected: onCategoryChanged,
                      itemBuilder: (context) => [
                        PopupMenuItem<String?>(
                          value: null,
                          child: Text(AppLocalizations.of(context).noCategory),
                        ),
                        ...categories.map((cat) => PopupMenuItem<String?>(
                          value: cat.id,
                          child: Row(
                            children: [
                              Icon(Icons.circle, size: 12, color: cat.toColor),
                              const SizedBox(width: 8),
                              Text(cat.name),
                            ],
                          ),
                        )),
                      ],
                    ),

                  // Delete button
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: onDelete,
                      color: Colors.grey,
                    ),
                ],
              ),

              // Reading progress bar
              if (article.readingProgress > 0 && article.status == ArticleStatus.ready)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: article.readingProgress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).articlePercentRead(
                          (article.readingProgress * 100).toInt(),
                        ),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(BuildContext context) {
    if (article.categoryId == null) return Theme.of(context).colorScheme.primary;
    final cat = categories.where((c) => c.id == article.categoryId).firstOrNull;
    return cat?.toColor ?? Theme.of(context).colorScheme.primary;
  }
}
