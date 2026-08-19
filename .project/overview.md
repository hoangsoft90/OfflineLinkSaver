# Project Overview

## What Is This App?

Offline Link Saver is an **offline-first read-later** mobile application. It solves a simple problem: save interesting articles now, read them later — even without internet.

### Core User Loop

```
Share link from another app (or paste URL)
    ↓
Instant "✓ Saved" feedback
    ↓
Background download & extraction (while app alive)
    ↓
Clean article content stored locally
    ↓
Read offline, anytime
```

### What It Is NOT

- ❌ A bookmark/URL manager
- ❌ A browser replacement
- ❌ A cloud-synced read-later app (no accounts, no cloud)
- ❌ An RSS reader

---

## Tech Stack

### Framework & Language
- **Flutter 3.x** — cross-platform mobile framework
- **Dart SDK >=3.0.0 <4.0.0**

### Dependencies

| Package | Version | Purpose |
|---|---|---|
| `sqflite` | ^2.3.0 | SQLite database |
| `path_provider` | ^2.1.0 | App document directory access |
| `path` | ^1.8.0 | File path utilities |
| `shared_preferences` | ^2.2.0 | Key-value storage (reader prefs) |
| `receive_sharing_intent` | ^1.4.8 | Android Share Sheet integration |
| `share_plus` | ^7.2.0 | Share content OUT of app |
| `http` | ^1.1.0 | HTTP client for fetching articles |
| `html` | ^0.15.4 | HTML parsing for content extraction |
| `webview_flutter` | ^4.4.0 | WebView fallback extraction |
| `connectivity_plus` | ^5.0.0 | Network status hint (UX only) |
| `uuid` | ^4.2.0 | UUID generation for article IDs & filenames |
| `url_launcher` | ^6.2.0 | Open URLs in external browser |
| `flutter_local_notifications` | ^17.0.0 | Local notifications |
| `in_app_purchase` | ^3.1.0 | Future monetization (P2) |

### Dev Dependencies
| Package | Version | Purpose |
|---|---|---|
| `flutter_test` | SDK | Unit/widget testing |
| `flutter_lints` | ^3.0.0 | Lint rules |

### Platform Support

| Platform | Status | Notes |
|---|---|---|
| Android | ✅ Full support | Share Sheet integration, intent-filter for ACTION_SEND |
| iOS | ⚠️ Partial | Paste URL only; Share Extension planned for P1/P2 |

---

## MVP Scope (Priority Levels)

### P0 — Must Have (Current Focus)
1. Paste URL (primary on iOS)
2. Android Share Sheet (`receive_sharing_intent`)
3. Instant "✓ Saved" feedback
4. Persistent Download Queue (HTTP concurrency = 2, WebView = 1)
5. HTTP Extraction (Layer 1)
6. Local article storage (atomic write)
7. Offline Reader (`ListView.builder` per block, themes, font size)
8. Download status on Library card
9. Retry on `failed`
10. Delete (metadata + content + images)
11. Library tabs: All / Unread / Downloaded + Search
12. Read/unread state
13. URL validation (http/https only)
14. Offline works 100% when `ready`

### P0.5 — Soon After P0
15. Reading progress (`last_scroll_offset`)
16. Download All Unread
17. Cover image priority download

### P1 — After MVP
18. Favorites
19. Storage Manager (clear cache, auto-delete read)
20. Wi-Fi auto-download
21. Full-text search
22. Tags

### P2 — Post-MVP
- Cloud sync, accounts, AI summary/tagging
- Export PDF/Markdown, Browser extension, RSS
- iOS Share Extension (native Xcode target)
- Content-hash duplicate detection
- SQLite FTS for full-text search

---

## Out of Scope for MVP

Do NOT add these without explicit approval:
- `workmanager`/background fetch outside app lifecycle
- iOS Share Extension native
- Cloud sync / Firebase / Supabase
- AI summary, TTS, PDF export, RSS
- `flutter_widget_from_html` (using block-based native render)
- Ads (MVP is free to measure retention)

---

## Accepted Risks

| Risk | Level | Decision |
|---|---|---|
| No WorkManager/background fetch | Medium | Accepted — "background" = persistent queue + resume on reopen |
| WebView fallback can't handle all SPAs/paywalls | High | Accepted — best-effort only |
| iOS Share Sheet needs native extension | High | Accepted — MVP uses Paste URL |
| Store/AdMob policy on crawled content | Medium | Accepted — no ads in MVP, re-verify before enabling |

---

## Privacy & Copy

Marketing/privacy wording must be precise:
> ✅ "Saved content is stored locally on your device. The app does not upload your library to a cloud account. No account required."
> ❌ NOT: "No data ever leaves your device" — false, app fetches from source websites.
