# Patterns & Conventions

## Design Patterns

### 1. Repository Pattern
`ArticleRepository` is the single data access layer. All database operations go through it — no raw SQL in widgets or services.

```dart
// Good: through repository
await repository.insertArticle(originalUrl: url, title: title);

// Bad: direct database access in UI
await db.insert('articles', {...});
```

### 2. Self-Heal on Read
When fetching an article, the repository verifies content integrity:

```dart
// ArticleRepository.getArticle()
if (article.status == ArticleStatus.ready) {
  final isValid = await StorageHelper.verifyArticleContent(id);
  if (!isValid) {
    // Content missing/corrupted → mark failed for retry
    await updateArticleStatus(id, ArticleStatus.failed, 
      errorMessage: 'Content file missing or corrupted');
  }
}
```

### 3. Atomic Writes
All file operations use a temp-then-rename pattern:

```
/articles/{id}.tmp/     ← write here first
    ↓ verify
/articles/{id}/         ← rename to final
```

### 4. State Machine (Finite)
Articles follow a strict state machine — no random state jumps:

```
queued → downloading → processing → ready
   ↓         ↓            ↓
failed    failed       failed
   ↓
online_only (permanent failure)
```

### 5. Concurrency Control
Custom semaphore pattern for limiting parallel operations:

```dart
class _Semaphore {
  final int _maxCount;
  int _current;
  // acquire() blocks when _current <= 0
  // release() increments _current
}
```

---

## Coding Conventions

### Dart Style
- Use `camelCase` for variables and functions
- Use `PascalCase` for classes and enums
- Use `snake_case` for file names
- Prefer `final` for immutable variables
- Use `late` sparingly (only when initialization is deferred)

### File Naming
```
article_repository.dart    → snake_case
download_queue_manager.dart → descriptive, not abbreviated
http_extractor.dart        → prefix indicates which extractor
```

### Widget Structure
```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key, required this.param});  // super.key
  
  @override
  Widget build(BuildContext context) {
    return ...;
  }
}
```

### Import Organization
```dart
// 1. Dart/Flutter imports
import 'dart:io';
import 'package:flutter/material.dart';

// 2. Package imports
import 'package:sqflite/sqflite.dart';

// 3. Relative imports
import '../models/article.dart';
import '../core/database/database_helper.dart';
```

### Error Handling Patterns
```dart
// Repository: return null for "not found" or "duplicate"
Future<Article?> insertArticle({...}) async { ... }

// Services: return result objects, never throw
ExtractionResult result = await extractor.extract(url);

// UI: catch and show SnackBar
try {
  await repository.deleteArticle(id);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

---

## Security Measures

### 1. URL Validation
Only allow `http://` and `https://` schemes. Reject dangerous schemes:

```dart
// UrlHelper
static const List<String> _dangerousSchemes = [
  'javascript', 'file', 'data', 'intent', 'mailto', 'tel'
];
```

### 2. Redirect Limits
Maximum 5 redirect hops to prevent infinite loops:

```dart
// NetworkClient
static const int _maxRedirectHops = 5;
```

### 3. Path Traversal Prevention
Image filenames are always UUID-based, never from URL:

```dart
// StorageHelper
static String generateImageFilename(String uuid) {
  return '$uuid.jpg';  // Never use original filename
}
```

### 4. Content Sanitization
All extracted content passes through the Sanitizer before storage:

```dart
// Sanitizer removes:
// - <script>, <iframe>, <object>, <embed>, <form> tags
// - javascript: URLs
// - on*= event attributes
// - Non-http/https image URLs
```

### 5. Response Size Limits
Guard against oversized responses:

```dart
// NetworkClient
static const int _maxResponseSize = 2 * 1024 * 1024; // 2MB
```

### 6. Image Limits
Per-article constraints to prevent storage abuse:

| Limit | Value |
|---|---|
| Max images/article | 15 |
| Max size/image | 5MB |
| Max total offline/article | 50MB |

---

## Naming Conventions

### Status Messages (User-Facing)
Always use human-readable messages, never technical exceptions:

```dart
// Good
'⚠ Download failed'

// Bad
'TimeoutException after 15000ms'
```

### UI Feedback
- Success: `✓ Saved`
- In-progress: `⏳ Downloading…`
- Failure: `⚠ Offline copy unavailable`
- Never expose technical error details to users

---

## Testing Patterns

### Test Matrix (from spec)
- **Network:** WiFi / mobile / mid-download loss / slow
- **Lifecycle:** background, kill mid-download, reboot
- **URL:** valid, invalid, duplicate, redirect chains, UTM params
- **Storage:** full disk, partial image failure, delete during download
- **Corruption:** missing content.json, malformed JSON, orphan files
- **Offline:** download → Airplane Mode → read 100%

### Critical Tests
1. **Gate 1:** Save never loses a link (even on extraction failure)
2. **Gate 4:** Zero-network Reader (real Airplane Mode, not simulated)
3. **Gate 5:** App-kill recovery (`adb shell am kill`, not hot-restart)

---

## UI Patterns

### Library Card States
```
✓ Saved · Offline copy ready         (status = ready)
⏳ Downloading… / Processing…         (status = downloading/processing)
⚠ Offline copy unavailable [Retry]   (status = failed/online_only)
```

### Empty State
Show helpful instructions when Library is empty:
- "Share a link from Chrome, Facebook, or Telegram"
- "Or tap + to paste a URL"

### Search
- P0: title + domain search
- Real-time filtering as user types
- Clear button when search is active

### Reader
- `ListView.builder` for virtualization (NOT one giant Text.rich)
- One widget per ContentBlock
- Theme selector: Light / Dark / Sepia
- Font size slider (12–24)
- Reading position saved on scroll

---

## Code Organization Rules

### What Goes Where

| Code | Location | Rationale |
|---|---|---|
| Database queries | `repositories/` | Data access abstraction |
| HTTP fetching | `core/network/` | Low-level networking |
| Content extraction | `services/extractor/` | Business logic |
| Queue management | `services/downloader/` | Orchestration logic |
| File operations | `core/storage/` | I/O abstraction |
| UI rendering | `screens/` + `widgets/` | Presentation only |
| Data models | `models/` | Shared data structures |

### Single Responsibility
Each file does ONE thing:
- `database_helper.dart` → SQLite setup + migrations
- `url_helper.dart` → URL validation + canonicalization
- `http_extractor.dart` → HTTP-based extraction only
- `sanitizer.dart` → Content cleaning only
