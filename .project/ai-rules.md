# AI Agent Rules

> These rules govern how AI agents should interact with this codebase.

---

## Critical Invariants (NEVER Break These)

### 1. Save Never Loses a Link
Once a URL is saved, extraction/download failure **NEVER** deletes the item. It transitions to `failed` or `online_only`. The URL and metadata are always preserved.

```dart
// CORRECT: Mark as failed, keep the article
await repository.updateArticleStatus(id, ArticleStatus.failed, 
  errorMessage: 'Extraction failed');

// WRONG: Delete on failure
await repository.deleteArticle(id);  // NEVER DO THIS ON FAILURE
```

### 2. Startup Sanitization Is Mandatory
```dart
// In main.dart, BEFORE building UI
final db = await DatabaseHelper.database;
await DatabaseHelper.startupSanitization(db);
```
This query runs EVERY launch:
```sql
UPDATE articles SET status = 'queued'
WHERE status IN ('downloading', 'processing');
```
**Do NOT remove or skip this.** It handles OS-killed processes.

### 3. Zero-Network Reader
Articles with `status = ready` must be readable with ZERO network requests. This includes images — they must be downloaded locally.

```dart
// ReaderScreen loads content from local file
final file = File(article.contentPath!);
final content = await file.readAsString();
```
If you add any network request in the reader path, you break offline reading.

### 4. Atomic Writes
All article content goes through temp-then-rename:
```
/articles/{id}.tmp/  →  verify  →  /articles/{id}/
```
Never write directly to the final directory.

### 5. UUID Filenames for Images
```dart
// CORRECT: UUID-based
final filename = '$imageUuid.jpg';

// WRONG: Original filename from URL
final filename = uri.pathSegments.last;  // PATH TRAVERSAL RISK
```

---

## Do-Not-Modify Zones

These files/patterns are architecturally sensitive. Modify only with explicit approval:

### Core Extraction Pipeline
- `lib/services/extractor/http_extractor.dart` — Layer 1 extraction
- `lib/services/extractor/webview_fallback_extractor.dart` — Layer 2 fallback
- `lib/services/extractor/sanitizer.dart` — Content sanitization

### Download Queue
- `lib/services/downloader/download_queue_manager.dart` — Concurrency control, state machine

### Storage & Database
- `lib/core/database/database_helper.dart` — Schema, migrations, startup sanitization
- `lib/core/storage/storage_helper.dart` — Atomic writes, file management

### State Machine
- `lib/models/article_status.dart` — Status enum and transitions

---

## What NOT to Add (Without Approval)

### Forbidden in MVP
- `workmanager` / background fetch outside app lifecycle
- Cloud sync / Firebase / Supabase
- AI summary / TTS / PDF export / RSS
- `flutter_widget_from_html` (using block-based render)
- Ads (MVP is free to measure retention)
- New packages not in the whitelist (see below)

### Package Whitelist
Only these packages are approved:

**P0:** `sqflite`, `path_provider`, `shared_preferences`, `receive_sharing_intent`, `http`, `html`, `webview_flutter`, `connectivity_plus`, `uuid`, `url_launcher`, `share_plus`, `flutter_local_notifications`, `in_app_purchase`

**P1:** `flutter_image_compress`, `google_mobile_ads`

**Forbidden in MVP:** `hive`, `fl_chart`, `pdf`, `file_picker`, `workmanager`, `flutter_widget_from_html`

---

## Coding Conventions for AI

### 1. Use Repository for Database Access
```dart
// CORRECT
await repository.insertArticle(originalUrl: url, title: title);

// WRONG
final db = await DatabaseHelper.database;
await db.insert('articles', {...});
```

### 2. Return Result Objects, Don't Throw
```dart
// CORRECT
ExtractionResult result = await extractor.extract(url);
if (!result.success) { ... }

// WRONG
try {
  final content = await extractor.extract(url);
} catch (e) { ... }
```

### 3. Human-Readable Error Messages
```dart
// CORRECT
errorMessage: 'Connection timeout'

// WRONG
errorMessage: 'TimeoutException after 15000ms'
```

### 4. Use Enums for Status
```dart
// CORRECT
article.status = ArticleStatus.ready;

// WRONG
article.status = 'ready';
```

### 5. Prefer const Constructors
```dart
// CORRECT
const Text('Hello')

// WRONG (if value is constant)
Text('Hello')
```

### 6. Use super.key
```dart
// CORRECT
const MyWidget({super.key, required this.param});

// WRONG
const MyWidget({Key? key, required this.param}) : super(key: key);
```

---

## File Organization Rules

### What Goes Where

| Code Type | Location |
|---|---|
| Database queries | `repositories/` |
| HTTP/network calls | `core/network/` |
| Content extraction logic | `services/extractor/` |
| Queue management | `services/downloader/` |
| File I/O operations | `core/storage/` |
| UI rendering | `screens/` + `widgets/` |
| Data models | `models/` |
| Shared utilities | `core/` |

### Single Responsibility
Each file does ONE thing:
- `database_helper.dart` → SQLite setup + migrations only
- `url_helper.dart` → URL validation + canonicalization only
- `http_extractor.dart` → HTTP-based extraction only
- `sanitizer.dart` → Content cleaning only

---

## Testing Requirements

### Before Claiming "Done"
Run through the 9 Release Gates:

1. **Save never loses link** — Test with site that definitely fails extraction
2. **Instant feedback** — Share/Paste → "✓ Saved" in < 2 seconds
3. **Download success** — Supported site → `ready` state
4. **Zero-network Reader** — Real Airplane Mode (not simulated)
5. **App-kill recovery** — `adb shell am kill` mid-download → resume on reopen
6. **Graceful failure** — Unsupported site → `online_only`, URL preserved
7. **Clean delete** — Delete → both DB and files gone
8. **Atomic integrity** — `content.json` always valid when `ready`
9. **Storage full** — Handle gracefully, no crash

### Test Matrix
- Network: WiFi / mobile / mid-download loss / slow
- Lifecycle: background, kill mid-download, reboot
- URL: valid, invalid, duplicate, redirect chains, UTM params
- Storage: full disk, partial image failure, delete during download
- Corruption: missing content.json, malformed JSON, orphan files
- Offline: download → Airplane Mode → read 100%

---

## Common Mistakes to Avoid

### 1. Forgetting Startup Sanitization
If you add a new status, add it to the sanitization query:
```dart
static Future<void> startupSanitization(Database db) async {
  await db.rawUpdate('''
    UPDATE articles 
    SET status = 'queued', updated_at = ?
    WHERE status IN ('downloading', 'processing')
  ''', [DateTime.now().toIso8601String()]);
}
```

### 2. Using HTTP URLs in Reader
The reader must load images from LOCAL files, not HTTP URLs:
```dart
// CORRECT
Image.file(File(block.imageUrl!))

// WRONG (breaks offline)
Image.network(block.imageUrl!)
```

### 3. Deleting on Extraction Failure
```dart
// CORRECT
await repository.updateArticleStatus(id, ArticleStatus.failed);

// WRONG
await repository.deleteArticle(id);  // LOSSES THE LINK
```

### 4. Adding Network Requests in Reader
```dart
// CORRECT: Load from local file
final file = File(article.contentPath!);
final content = await file.readAsString();

// WRONG: Fetch from network
final response = await http.get(Uri.parse(article.originalUrl));
```

### 5. Using Original Filename for Images
```dart
// CORRECT: UUID-based
final filename = '${const Uuid().v4()}.jpg';

// WRONG: Path traversal risk
final filename = uri.pathSegments.last;
```

---

## Decision Framework

When facing ambiguity, follow this priority:

1. **Safety first** — Don't lose user data, don't crash
2. **Spec compliance** — Follow `plan1_final_v2.md` exactly
3. **Simplicity** — Prefer simple solutions over clever ones
4. **Consistency** — Match existing patterns in the codebase
5. **When in doubt** — Ask the user, don't guess

### If You Find a Contradiction
- Stop and ask the user
- Don't make assumptions
- Document the decision if approved
