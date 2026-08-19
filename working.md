# working.md — Current Status & Active Work

> Updated: August 2026

## Current State

**Phase:** MVP Core Pipeline — Implementation in progress
**Version:** 1.0.0+1
**Git:** Not initialized (no commits yet)

## What's Built (Working)

### Core Pipeline ✅
- [x] SQLite database with schema + migrations
- [x] Article model with copyWith, toMap/fromMap
- [x] ArticleStatus enum with 6 states
- [x] ContentBlock model (block-based content)
- [x] ArticleRepository with CRUD + self-heal
- [x] Startup sanitization in main.dart

### Extraction Pipeline ✅
- [x] HTTP Extractor (Layer 1) — fetch + HTML parse
- [x] WebView Fallback Extractor (Layer 2) — JavaScript rendering
- [x] Sanitizer — removes dangerous content
- [x] ExtractionResult data class

### Download Queue ✅
- [x] DownloadQueueManager with concurrency control
- [x] HTTP concurrency = 2, WebView = 1
- [x] State machine transitions
- [x] Image download with UUID filenames
- [x] Progress reporting stream

### Storage ✅
- [x] Atomic writes (temp → verify → rename)
- [x] UUID filenames for images
- [x] Content verification
- [x] Storage usage stats

### Share Handler ✅
- [x] Android Share Sheet (receive_sharing_intent)
- [x] URL validation + canonicalization
- [x] Duplicate detection
- [x] Instant "✓ Saved" feedback

### UI Screens ✅
- [x] HomeScreen with tabs (All/Unread/Downloaded)
- [x] Search by title/domain
- [x] Add URL dialog (paste URL)
- [x] Download All Unread FAB
- [x] ReaderScreen with block rendering
- [x] Theme selector (Light/Dark/Sepia)
- [x] Font size slider
- [x] Reading progress save/restore
- [x] SettingsScreen with storage info

### Widgets ✅
- [x] ArticleCard with status display
- [x] StatusBadge with retry button
- [x] ReaderControls with theme/font/actions

## What's NOT Built Yet

### Not Started
- [ ] Tests (unit, widget, integration)
- [ ] iOS Share Extension (P2)
- [ ] Cloud sync / accounts (P2)
- [ ] AI summary / tagging (P2)
- [ ] Export PDF/Markdown (P2)
- [ ] RSS support (P2)
- [ ] Ads / monetization (P2)
- [ ] Storage Manager — clear cache, auto-delete (P1)
- [ ] Wi-Fi auto-download (P1)
- [ ] SQLite FTS full-text search (P2)

### Partially Done
- [ ] `flutter_local_notifications` — included but not wired up
- [ ] `in_app_purchase` — included but not configured
- [ ] `connectivity_plus` — used as UX hint only

## Known Issues / Tech Debt

1. **No tests** — Need unit tests for repository, extractor, sanitizer
2. **No git repo** — Should initialize and make first commit
3. **Cover image in reader** — Currently loads from network (breaks offline)
4. **Error handling** — Some catch blocks are generic, could be more specific
5. **WebView extractor** — Returns null on some edge cases (acceptable per spec)

## Next Steps (Priority Order)

### Immediate (P0 Completion)
1. Initialize git repository + first commit
2. Add unit tests for core modules
3. Test extraction on 15-20 real websites
4. Verify all 9 Release Gates on real device
5. Fix any issues found during testing

### Short Term (P0.5)
6. Download All Unread UI feedback (progress indicator)
7. Reading progress indicator on ArticleCard
8. Cover image local storage (currently network-only)

### Medium Term (P1)
9. Favorites screen/tab
10. Storage Manager (clear image cache, auto-delete read)
11. Wi-Fi auto-download preference

## Testing Checklist

Run through `plan1_final_v2.md` §12 Test Matrix:
- [ ] Network: WiFi / mobile / mid-download loss / slow
- [ ] Lifecycle: background / kill mid-download / reboot
- [ ] URL: valid / invalid / duplicate / redirects / UTM
- [ ] Storage: full disk / partial image failure / delete during download
- [ ] Corruption: missing content.json / malformed JSON / orphan files
- [ ] Share: Chrome / Facebook / Telegram / Reddit (Android)
- [ ] Offline: download → Airplane Mode → read 100%
- [ ] Extraction: 15-20 diverse sites
- [ ] DB migration: v1 → v2 simulation

## Release Gates (Plan1 §13)

MVP is done when ALL 9 pass:
1. [ ] Save never loses link
2. [ ] Instant "✓ Saved" feedback
3. [ ] Download succeeds for supported sites
4. [ ] Zero-network Reader (real Airplane Mode)
5. [ ] App-kill recovery (adb shell am kill)
6. [ ] Graceful failure (online_only for unsupported)
7. [ ] Clean delete (DB + files gone)
8. [ ] Atomic file integrity (content.json always valid)
9. [ ] Storage full handled gracefully
