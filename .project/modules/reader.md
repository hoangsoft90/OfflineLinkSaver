# Module: Reader

## Overview

The Reader module provides offline reading of downloaded articles. It renders content from local files using a block-based approach with virtualization for performance.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  ReaderScreen                        │
│  - Load content from local file                     │
│  - Render via ListView.builder                      │
│  - Manage reading position                          │
│  - Theme and font size controls                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                Content Rendering                     │
│  - One widget per ContentBlock                      │
│  - Virtualized via ListView.builder                 │
│  - Supports all block types                         │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              Local File System                       │
│  - Read content.json from disk                      │
│  - Load images from /images/ directory              │
│  - ZERO network requests                            │
└─────────────────────────────────────────────────────┘
```

---

## ReaderScreen

### File: `lib/screens/reader/reader_screen.dart`

### Responsibilities

1. Load article content from local file
2. Render content blocks in a scrollable list
3. Track and restore reading position
4. Mark articles as read
5. Provide theme and font size controls

### Key Properties

```dart
class ReaderScreen extends StatefulWidget {
  final Article article;
  final ArticleRepository repository;
  
  // State
  ArticleContent? _content;
  bool _isLoading = true;
  String? _error;
  double _fontSize = 16.0;
  ReaderTheme _currentTheme = ReaderTheme.light;
  final ScrollController _scrollController = ScrollController();
  late Article _article;
}
```

---

## Content Loading

### Load from Local File

```dart
Future<void> _loadContent() async {
  try {
    if (_article.contentPath == null) {
      setState(() {
        _error = 'Content not available';
        _isLoading = false;
      });
      return;
    }

    final file = File(_article.contentPath!);
    if (!await file.exists()) {
      setState(() {
        _error = 'Content file missing';
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
      _error = 'Failed to load content: $e';
      _isLoading = false;
    });
  }
}
```

### Zero-Network Guarantee

The reader makes **ZERO network requests**:
- Content loaded from local `content.json`
- Images loaded from local `/images/` directory
- No external URLs fetched
- Compatible with Airplane Mode

---

## Content Rendering

### ListView.builder Approach

```dart
Widget _buildContent() {
  if (_content == null || _content!.blocks.isEmpty) {
    return const Center(child: Text('No content available'));
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
```

### Why ListView.builder?

- **Virtualization:** Only renders visible blocks
- **Performance:** Handles long articles (5,000–10,000 words) smoothly
- **Memory efficient:** Doesn't load all widgets at once
- **Font size changes:** No rebuild of entire article

### NOT Text.rich

The spec explicitly forbids using one giant `Text.rich`:
> "Dồn toàn bộ bài dài (5.000–10.000 từ + nhiều ảnh) vào một `Text.rich`/`WidgetSpan` duy nhất sẽ gây rebuild nặng và giật khi scroll/đổi font size trên thiết bị yếu."

---

## Block Renderers

### Heading

```dart
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
```

### Paragraph

```dart
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
```

### Image

```dart
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
```

### Quote

```dart
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
```

### List

```dart
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
```

### Code

```dart
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
```

### Link

```dart
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
```

---

## Reading Position

### Save Position

```dart
void _setupScrollListener() {
  _scrollController.addListener(() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      final progress = currentScroll / maxScroll;
      
      // Save reading progress
      widget.repository.updateReadingProgress(
        _article.id,
        progress.clamp(0.0, 1.0),
      );
    }
  });
}
```

### Restore Position

```dart
// After loading content
if (_article.readingProgress > 0) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = maxScroll * _article.readingProgress;
      _scrollController.jumpTo(targetScroll);
    }
  });
}
```

### Progress Format

- Stored as `double` (0.0–1.0)
- `0.0` = start of article
- `1.0` = end of article
- Updated on every scroll event (debounced)

---

## Theming

### Theme Enum

```dart
enum ReaderTheme {
  light,
  dark,
  sepia,
}
```

### Theme Colors

```dart
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
```

### Font Size

- Range: 12.0 – 24.0
- Default: 16.0
- Adjusted via slider in ReaderControls
- Applied to all text elements
- Headings are scaled relative to base size

---

## ReaderControls

### File: `lib/widgets/reader_controls.dart`

### Features

1. **Theme selector** — Light / Dark / Sepia buttons
2. **Font size slider** — 12–24 range
3. **Action buttons** — Favorite, Share, Delete

### Usage

```dart
bottomNavigationBar: _content != null
    ? ReaderControls(
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
      )
    : null,
```

---

## Error Handling

### Content Not Available

```dart
if (_article.contentPath == null) {
  setState(() {
    _error = 'Content not available';
    _isLoading = false;
  });
  return;
}
```

### File Missing

```dart
final file = File(_article.contentPath!);
if (!await file.exists()) {
  setState(() {
    _error = 'Content file missing';
    _isLoading = false;
  });
  return;
}
```

### Image Load Failure

```dart
errorBuilder: (context, error, stackTrace) {
  return _buildImagePlaceholder();
},
```

### Error State UI

```dart
Widget _buildErrorState() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text('Failed to load content', ...),
          const SizedBox(height: 8),
          Text(_error!, ...),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
          ),
        ],
      ),
    ),
  );
}
```

---

## Actions

### Toggle Favorite

```dart
void _toggleFavorite() async {
  await widget.repository.toggleFavorite(_article.id);
  setState(() {
    _article = _article.copyWith(isFavorite: !_article.isFavorite);
  });
}
```

### Share Article

```dart
void _shareArticle() {
  final text = '${_article.title}\n\n${_article.originalUrl}';
  Share.share(text);
}
```

### Delete Article

```dart
void _deleteArticle() async {
  final confirmed = await showDialog<bool>(...);
  if (confirmed == true) {
    await widget.repository.deleteArticle(_article.id);
    if (mounted) Navigator.pop(context);
  }
}
```

### Open in Browser

```dart
void _openInBrowser() async {
  final url = Uri.parse(_article.originalUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  }
}
```

---

## Performance Considerations

### Why ListView.builder?

1. **Virtualization:** Only renders visible blocks
2. **Memory:** Doesn't load all widgets at once
3. **Scroll performance:** Smooth even with 1000+ blocks
4. **Font size changes:** No rebuild of entire article

### Image Loading

- Images loaded from local files (no network)
- Error builder shows placeholder on failure
- No lazy loading needed (already local)

### Scroll Performance

- Scroll listener saves position on every event
- No debounce needed (position is just a double)
- `clamp(0.0, 1.0)` prevents out-of-range values

---

## Testing

### Test Cases

1. **Load content** — Read content.json from disk
2. **Render blocks** — All block types display correctly
3. **Theme switching** — Light/Dark/Sepia work
4. **Font size** — Slider adjusts text size
5. **Reading position** — Save and restore works
6. **Mark as read** — Article marked read on open
7. **Favorite toggle** — Heart icon toggles
8. **Delete** — Confirmation dialog, then remove
9. **Open in browser** — Launches external browser
10. **Share** — Opens share sheet with title + URL
11. **Error state** — Missing content shows error
12. **Image placeholder** — Missing image shows placeholder
13. **Airplane Mode** — Reader works with no network

### Performance Tests

1. **Long article** — 10,000 words renders smoothly
2. **Many images** — 15 images load without lag
3. **Font size change** — No jank on slider move
4. **Scroll performance** — Smooth scroll through long article
