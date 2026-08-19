import 'package:flutter/material.dart';

/// Reader controls for theme and font size
class ReaderControls extends StatelessWidget {
  final double fontSize;
  final ValueChanged<double> onFontSizeChanged;
  final ReaderTheme currentTheme;
  final ValueChanged<ReaderTheme> onThemeChanged;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const ReaderControls({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.currentTheme,
    required this.onThemeChanged,
    this.onFavorite,
    this.isFavorite = false,
    this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getThemeColor(),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Theme selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildThemeButton(ReaderTheme.light, 'Light', Icons.light_mode),
              const SizedBox(width: 16),
              _buildThemeButton(ReaderTheme.dark, 'Dark', Icons.dark_mode),
              const SizedBox(width: 16),
              _buildThemeButton(ReaderTheme.sepia, 'Sepia', Icons.auto_stories),
            ],
          ),

          const SizedBox(height: 16),

          // Font size slider
          Row(
            children: [
              const Icon(Icons.text_decrease, size: 20),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12.0,
                  max: 24.0,
                  divisions: 12,
                  onChanged: onFontSizeChanged,
                ),
              ),
              const Icon(Icons.text_increase, size: 20),
            ],
          ),

          const SizedBox(height: 8),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onFavorite != null)
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : null,
                  ),
                  onPressed: onFavorite,
                  tooltip: 'Favorite',
                ),
              if (onShare != null)
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: onShare,
                  tooltip: 'Share',
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(ReaderTheme theme, String label, IconData icon) {
    final isSelected = currentTheme == theme;
    return GestureDetector(
      onTap: () => onThemeChanged(theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getThemeColor() {
    switch (currentTheme) {
      case ReaderTheme.light:
        return Colors.white;
      case ReaderTheme.dark:
        return Colors.grey.shade900;
      case ReaderTheme.sepia:
        return const Color(0xFFF5F0E6);
    }
  }
}

enum ReaderTheme {
  light,
  dark,
  sepia,
}
