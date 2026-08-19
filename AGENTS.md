# AGENTS.md — Project Agent Instructions

> For any AI coding agent working on this project. Read this FIRST.

## Project Identity

**Offline Link Saver** — Offline-first read-later mobile app (Flutter).
Users save links, app downloads content, users read offline.

**Spec source of truth:** `plan1_final_v2.md` — DO NOT deviate from it without asking.

## Quick Start

```bash
flutter pub get
flutter run
```

## Architecture (4 Layers)

```
UI (screens/ + widgets/)
    ↓
Services (extractor/ + downloader/ + share_handler/)
    ↓
Repository (article_repository.dart)
    ↓
Core (database/ + network/ + storage/)
```

## Critical Invariants

1. **Save NEVER loses a link.** Extraction failure → `failed`/`online_only`, never delete.
2. **Zero-network Reader.** `ready` articles must work in Airplane Mode. No network requests in reader path.
3. **Startup sanitization.** Runs EVERY launch. Resets stuck `downloading`/`processing` → `queued`.
4. **Atomic writes.** Write to `.tmp/` → verify → rename. Never write directly to final dir.
5. **UUID filenames.** Images always `{uuid}.jpg`. NEVER use original filename from URL.

## Do NOT

- Add `workmanager` or background fetch outside app lifecycle
- Add cloud sync / Firebase / Supabase
- Add `flutter_widget_from_html` (using block-based render)
- Add packages not in whitelist (`plan1_final_v2.md` §10)
- Delete articles on extraction failure
- Make network requests in the Reader

## Key Files

| File | Role |
|---|---|
| `lib/main.dart` | Entry point, startup sanitization |
| `lib/models/article_status.dart` | State machine enum (DO NOT add states without approval) |
| `lib/core/database/database_helper.dart` | SQLite schema, migrations |
| `lib/core/storage/storage_helper.dart` | Atomic writes, file management |
| `lib/services/downloader/download_queue_manager.dart` | Queue, concurrency, pipeline |
| `lib/services/extractor/http_extractor.dart` | Layer 1 extraction |
| `lib/services/extractor/sanitizer.dart` | Content sanitization |
| `lib/repositories/article_repository.dart` | CRUD + self-heal |

## Testing Before "Done"

Run through 9 Release Gates (`plan1_final_v2.md` §13). Especially:
- **Gate 4:** Real Airplane Mode, not simulated
- **Gate 5:** `adb shell am kill`, not hot-restart
- **Gate 1:** Test with site that definitely fails extraction

## Lint Rules

Project uses `flutter_lints` with strict rules. Key ones:
- `prefer_const_constructors`
- `prefer_final_locals`
- `use_key_in_widget_constructors` (use `super.key`)
- `always_use_package_imports`
- `require_trailing_commas`
- `sort_child_properties_last`

Run `flutter analyze` before committing.
