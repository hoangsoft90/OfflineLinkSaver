# context.md — Project Context & History

> What this project is, where it came from, and where it's going.

## Origin

Offline Link Saver was designed through 3 rounds of spec review:
- `plan1.md` → `plan1_final.md` → `plan1_final_v2.md`
- Hardened for state machine, atomic write, security, and release gates

**Core idea:** Save once. Read anywhere. Even offline.

## Product Positioning

- ✅ Offline-first Read-Later app
- ❌ NOT a bookmark/URL manager
- ❌ NOT a cloud-synced app (no accounts)
- ❌ NOT an RSS reader

## Design Decisions (Accepted Risks)

| Decision | Why |
|---|---|
| No WorkManager/background fetch | "Background" = persistent queue + resume on reopen. Simpler, fewer edge cases. |
| WebView is best-effort | SPA/paywall/bot-protection sites → `online_only`. Acceptable for MVP. |
| Block-based render (not flutter_widget_from_html) | Better performance, virtualization, theme control. |
| No ads in MVP | Free to measure retention first. Ads later in Library only, never in Reader. |
| SQLite (not Hive) | Mature, proven, FTS-ready for future search. |
| Paste URL on iOS (no Share Extension) | Native Share Extension is complex. MVP uses paste as primary on iOS. |

## User Flows

### Flow 1: Share from App (Android)
```
Chrome/Facebook/Telegram → Share → App → "✓ Saved" instantly
→ Background: resolve redirects → canonicalize → queue → extract → save
```

### Flow 2: Paste URL (iOS + Android)
```
App → "+" → Paste URL → same pipeline as Flow 1
```

### Flow 3: Read Offline
```
Library → tap ready article → Reader → zero network requests
→ close app → reopen → continue from last position
```

### Flow 4: Extraction Fail
```
Download fails → status: online_only
→ UI: "Offline copy unavailable" + [Retry] [Open original]
```

## Platform Status

| Platform | Share Input | Share Extension | Status |
|---|---|---|---|
| Android | Share Sheet (receive_sharing_intent) | N/A | ✅ Full |
| iOS | Paste URL | Not implemented (P2) | ⚠️ Partial |

## Monetization Plan

- **MVP:** 100% free, no ads
- **After retention data:** Free (ads in Library only) + Pro one-time IAP
- **Pro features:** Remove ads, custom themes, export (future)

## Privacy Wording

> ✅ "Saved content is stored locally on your device. The app does not upload your library to a cloud account. No account required."
> ❌ NOT: "No data ever leaves your device" — app fetches from source websites.

## Future Roadmap

### P1 (After MVP)
- Favorites
- Storage Manager (clear cache, auto-delete read after 30 days)
- Wi-Fi auto-download
- Full-text search

### P2 (Post-MVP)
- Cloud sync / accounts
- AI summary / tagging / TTS
- Export PDF/Markdown
- Browser extension
- RSS
- iOS Share Extension (native Xcode target)
- Content-hash duplicate detection
- SQLite FTS full-text search
- Ads (Library only, never in Reader)
