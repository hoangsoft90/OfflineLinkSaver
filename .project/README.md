# Offline Link Saver — Knowledge Items

> Last updated: August 2026

## Project Summary

**Offline Link Saver** is an offline-first read-later mobile app built with Flutter. Users save links from Chrome, Facebook, Telegram (or paste URLs), and the app downloads article content for offline reading — no account required.

**Tagline:** *Save once. Read anywhere. Even offline.*

---

## Quick Links

| Document | Description |
|---|---|
| [overview.md](./overview.md) | Product overview, tech stack, dependencies, platform support |
| [architecture.md](./architecture.md) | Layered architecture, data flow, directory structure |
| [patterns.md](./patterns.md) | Design patterns, conventions, security measures |
| [state.md](./state.md) | State machine, data models, SQLite schema |
| [ai-rules.md](./ai-rules.md) | Rules for AI agents, do-not-modify zones, coding conventions |
| [modules/](./modules/) | Per-module deep dives (extractor, downloader, reader, etc.) |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart SDK >=3.0.0 <4.0.0) |
| Database | SQLite via `sqflite` |
| Storage | `path_provider` + atomic writes |
| HTTP | `http` package |
| HTML Parsing | `html` package |
| WebView Fallback | `webview_flutter` |
| Android Share | `receive_sharing_intent` |
| Notifications | `flutter_local_notifications` |
| Monetization | `in_app_purchase` (P2) |

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer                          │
│  screens/ (HomeScreen, ReaderScreen, etc.)          │
│  widgets/ (ArticleCard, StatusBadge, ReaderControls)│
├─────────────────────────────────────────────────────┤
│               Services Layer                        │
│  extractor/ (HTTP + WebView + Sanitizer)            │
│  downloader/ (DownloadQueueManager)                 │
│  share_handler/ (Android Share Sheet)               │
├─────────────────────────────────────────────────────┤
│              Repository Layer                       │
│  ArticleRepository (CRUD + self-heal)               │
├─────────────────────────────────────────────────────┤
│                Core Layer                           │
│  database/ (SQLite + migrations)                    │
│  network/ (HTTP client + URL helpers)               │
│  storage/ (File I/O + atomic writes)                │
└─────────────────────────────────────────────────────┘
```

---

## Current Status

- **Version:** 1.0.0+1
- **MVP Scope:** P0 features implemented (see [overview.md](./overview.md))
- **Platforms:** Android (full support), iOS (paste URL only, Share Extension planned)
- **State:** Core pipeline working — paste/share → queue → extract → save → read offline

---

## Key Invariants

1. **Save never loses a link** — extraction failure → `failed`/`online_only`, never delete
2. **Zero-network Reader** — `ready` articles read 100% offline
3. **App-kill recovery** — startup sanitization resets stuck items to `queued`
4. **Atomic writes** — temp dir → verify → rename; UUID filenames prevent path traversal
