# Architecture

## Layered Architecture

The app follows a clean layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer                               │
│  ┌──────────┐ ┌──────────────┐ ┌────────────────────────┐  │
│  │ screens/  │ │  widgets/    │ │   main.dart (entry)    │  │
│  └──────────┘ └──────────────┘ └────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                             │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────────┐     │
│  │ extractor/   │ │ downloader/  │ │ share_handler/   │     │
│  │ (2-tier)     │ │ (queue mgr)  │ │ (Android share)  │     │
│  └─────────────┘ └──────────────┘ └──────────────────┘     │
├─────────────────────────────────────────────────────────────┤
│                  Repository Layer                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              ArticleRepository                       │    │
│  │  (CRUD, self-heal, query builders)                  │    │
│  └─────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│                     Core Layer                               │
│  ┌────────────┐ ┌────────────────┐ ┌───────────────────┐   │
│  │ database/   │ │   network/     │ │    storage/       │   │
│  │ (SQLite)    │ │ (HTTP + URL)   │ │ (files + atomic)  │   │
│  └────────────┘ └────────────────┘ └───────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Dependency Rules
- **UI → Services → Repository → Core** (downward only)
- Core has NO dependencies on upper layers
- Services depend only on Core + Repository
- UI depends on everything but doesn't contain business logic

---

## Directory Structure

```
lib/
├── main.dart                          # Entry point, startup sanitization
├── core/                              # Foundation layer
│   ├── database/
│   │   └── database_helper.dart       # SQLite singleton, schema, migrations
│   ├── network/
│   │   ├── network_client.dart        # HTTP fetch with redirects + timeout
│   │   └── url_helper.dart            # URL validation, canonicalization
│   └── storage/
│       └── storage_helper.dart        # File I/O, atomic writes, UUID filenames
├── models/                            # Data models
│   ├── article.dart                   # Article entity (with copyWith, toMap/fromMap)
│   ├── article_status.dart            # Status enum + extensions
│   └── content_block.dart             # Block-based content model
├── repositories/                      # Data access
│   └── article_repository.dart        # SQLite CRUD + self-heal logic
├── services/                          # Business logic
│   ├── extractor/
│   │   ├── http_extractor.dart        # Layer 1: HTTP fetch + HTML parse
│   │   ├── webview_fallback_extractor.dart  # Layer 2: WebView fallback
│   │   └── sanitizer.dart             # Content sanitization
│   ├── downloader/
│   │   └── download_queue_manager.dart # Queue with concurrency control
│   └── share_handler/
│       └── share_handler.dart         # Android share intent handling
├── screens/                           # UI screens
│   ├── home/
│   │   └── home_screen.dart           # Library with tabs + search + FABs
│   ├── reader/
│   │   └── reader_screen.dart         # Offline reader (ListView per block)
│   ├── search/
│   │   └── search_screen.dart         # Search by title/domain
│   └── settings/
│       └── settings_screen.dart       # Storage info, about, privacy
└── widgets/                           # Reusable UI components
    ├── article_card.dart              # Article list card with status
    ├── status_badge.dart              # Status indicator badge
    └── reader_controls.dart           # Theme/font/action controls
```

---

## Data Flow: Save a Link

### Flow 1: Share from Another App (Android)

```
Chrome/Facebook/Telegram
    ↓ (Android Share Sheet)
receive_sharing_intent
    ↓
ShareHandler._handleSharedText()
    ↓
URL Validation (UrlHelper.isValidUrl)
    ↓
Redirect Resolution (NetworkClient.fetchHead, max 5 hops)
    ↓
Canonicalization (UrlHelper.canonicalizeUrl — strip utm_*, fbclid, etc.)
    ↓
Duplicate Check (ArticleRepository.searchArticles)
    ↓ (if new)
INSERT into SQLite (status: queued)
    ↓
UI shows "✓ Saved" INSTANTLY (no waiting)
    ↓
DownloadQueueManager.enqueue()
    ↓
    ┌─ [HTTP slots available?] ──── YES ───→ Start download
    └─ NO ──→ Wait in queue
```

### Flow 2: Download & Extraction Pipeline

```
DownloadQueueManager._processArticle(articleId)
    ↓
UPDATE status → downloading
    ↓
HTTP Extractor (Layer 1)
    ├─ Success (≥200 words) ──→ Continue
    └─ Fail (<200 words / error) ──→ WebView Fallback (Layer 2)
         ├─ Success ──→ Continue
         └─ Fail ──→ status = failed / online_only
    ↓
Sanitizer (remove <script>, <iframe>, javascript:, on*=)
    ↓
UPDATE status → processing
    ↓
Create temp dir: /articles/{id}.tmp/
    ↓
Write content.json (JSON format)
    ↓
Download images (UUID filenames, max 15, max 5MB each)
    ↓
Verify content.json exists + valid
    ↓
Atomic rename: .tmp/ → final/
    ↓
UPDATE SQLite: content_path, status → ready
```

### Flow 3: Read Offline

```
HomeScreen → tap ArticleCard (status=ready)
    ↓
ReaderScreen._loadContent()
    ↓
Read content.json from disk
    ↓
Parse ArticleContent.fromJson()
    ↓
Render via ListView.builder (one widget per block)
    ↓
Restore reading position (last_scroll_offset)
    ↓
Mark as read
    ↓
ZERO network requests (Airplane Mode compatible)
```

---

## Startup Sequence

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Run startup sanitization (resets stuck downloads)
  final db = await DatabaseHelper.database;
  await DatabaseHelper.startupSanitization(db);
  
  // 2. Initialize services
  final repository = ArticleRepository();
  final downloadQueue = DownloadQueueManager(repository: repository);
  final shareHandler = ShareHandler(repository: repository, downloadQueue: downloadQueue);
  shareHandler.initialize();
  
  // 3. Lock orientations
  await SystemChrome.setPreferredOrientations([...]);
  
  // 4. Launch app
  runApp(OfflineLinkSaverApp(...));
}
```

### Why Startup Sanitization Is Mandatory

If the OS kills the app mid-download, articles stay in `downloading`/`processing` status permanently. The sanitization query resets them to `queued` so they resume on next launch:

```sql
UPDATE articles SET status = 'queued'
WHERE status IN ('downloading', 'processing');
```

---

## Concurrency Model

### Download Queue

| Resource | Concurrency | Purpose |
|---|---|---|
| HTTP downloads | 2 parallel | Main extraction pipeline |
| WebView fallback | 1 at a time | Resource-heavy, only when HTTP fails |

### Implementation
- Custom `_Semaphore` class for concurrency control
- HTTP semaphore: `acquire()` before download, `release()` after
- WebView semaphore: acquired only when Layer 1 fails
- Queue is processed via `Timer.periodic(100ms)` polling

---

## File System Layout

```
/articles/{id}.tmp/          # Active download (may be incomplete)
    content.json
    images/{uuid}.jpg
/articles/{id}/              # Verified, ready for reading
    content.json
    images/{uuid}.jpg
```

### Atomic Write Pattern
1. Write to `{id}.tmp/` directory
2. Verify `content.json` exists and is valid JSON
3. Rename `.tmp/` to final directory
4. If step 2-3 fails, `.tmp/` is cleaned up on next startup

### Image Filename Convention
- Always UUID-based: `{uuid}.jpg`
- NEVER use original filename from URL
- Prevents path traversal attacks (`../../etc/passwd`)

---

## Database Schema

```sql
CREATE TABLE articles (
    id TEXT PRIMARY KEY,                    -- UUID v4
    original_url TEXT NOT NULL,             -- Never overwritten
    canonical_url TEXT NOT NULL UNIQUE,     -- After redirect + strip tracking
    title TEXT NOT NULL,
    domain TEXT NOT NULL,
    author TEXT,                            -- Nullable
    excerpt TEXT,
    cover_image_path TEXT,                  -- Local path, UUID filename
    content_path TEXT,                      -- Path to content.json
    status TEXT NOT NULL DEFAULT 'queued',  -- ArticleStatus enum value
    extractor_version INTEGER DEFAULT 1,    -- For re-extraction marking
    is_read INTEGER DEFAULT 0,              -- Boolean
    is_favorite INTEGER DEFAULT 0,          -- Boolean (P1)
    reading_progress REAL DEFAULT 0.0,      -- 0.0–1.0 (P0.5)
    error_message TEXT,                     -- Human-readable, nullable
    created_at TEXT NOT NULL,               -- ISO 8601
    updated_at TEXT NOT NULL                -- ISO 8601
);

-- Indexes
CREATE INDEX idx_articles_status ON articles(status);
CREATE INDEX idx_articles_is_read ON articles(is_read);
CREATE INDEX idx_articles_canonical_url ON articles(canonical_url);
CREATE INDEX idx_articles_domain ON articles(domain);
```

### Migration Strategy
- Use `PRAGMA user_version` for version tracking
- Currently at version 1 (base schema)
- Future migrations must preserve existing data

---

## External Integrations

### Android Share Sheet
- `receive_sharing_intent` listens for `ACTION_SEND` with `text/plain`
- AndroidManifest.xml must declare intent-filter for `ACTION_SEND`
- Handles both initial share (app opened via share) and subsequent shares

### In-App Purchase (P2)
- `in_app_purchase` package included but not wired up
- Future: Pro tier for remove ads, custom themes, export

### Connectivity Hint
- `connectivity_plus` shows offline indicator in UI
- Does NOT gate downloads — downloader always tries real network requests
- "WiFi connected" ≠ "Internet reachable"
