# ThinkSave — Full Feature List

> Offline-first read-later app. Save links from any app, read them offline with a clean reader experience.

---

## 1. Core: Save & Download

| Feature | Description |
|---------|-------------|
| **Add URL manually** | Paste any http/https URL via dialog on home screen |
| **Share Intent (Android)** | Share link from Chrome, Facebook, Telegram, etc. → auto-saves to ThinkSave |
| **Deep-link handling** | Receives `ACTION_SEND` text/plain intents, validates URL, resolves redirects |
| **Duplicate detection** | Canonical URL matching (strips tracking params: utm_*, fbclid, gclid, etc.) |
| **Download queue** | Concurrency-limited queue (3 HTTP + 1 WebView) with retry support |
| **HTTP extractor** | Parses HTML → structured content blocks (headings, paragraphs, images, lists, code, quotes, links) |
| **WebView fallback** | When HTTP extraction fails (JS-rendered pages), falls back to headless WebView |
| **Content sanitizer** | Strips scripts, styles, ads, navigation, footers — keeps clean article body |
| **Image download** | Downloads article images locally for offline reading |
| **Cover image** | Extracts and saves hero/cover image for article cards |
| **Content-Type guard** | Rejects non-HTML responses (binary files, audio, video) before downloading |
| **Size limit** | 5MB response limit with `<script>`/`<style>` stripping to fit modern pages |
| **Auto-retry** | Failed downloads can be retried manually via button |
| **Download All** | One-tap to queue all unread/failed articles for download |

---

## 2. Article Status Machine

```
queued → downloading → processing → ready
                  ↓                ↓
              failed          online_only
                  ↓
            (retry) → queued
```

| Status | Meaning |
|--------|---------|
| `queued` | Waiting in download queue |
| `downloading` | HTTP fetch in progress |
| `processing` | Parsing, sanitizing, normalizing, downloading images |
| `ready` | Complete — offline copy available |
| `failed` | Error occurred (network, timeout, parse failure) — can retry |
| `online_only` | Offline article cannot be created — keeps URL/metadata only |

---

## 3. Offline Reader

| Feature | Description |
|---------|-------------|
| **Clean reader view** | Article rendered as structured content blocks (not raw HTML) |
| **Reading themes** | Light, Dark, Sepia — tap to switch |
| **Font size control** | Slider from 12px to 24px |
| **Reading progress** | Auto-saves scroll position (debounced 500ms), restores on reopen |
| **Mark as read** | Automatically marks article as read when opened |
| **Favorite** | Toggle heart icon to bookmark articles |
| **Share article** | Share title + URL via system share sheet |
| **Open in browser** | Launch original URL in external browser |
| **Delete article** | Confirmation dialog before permanent delete |
| **Article metadata** | Shows author, domain, cover image |
| **Content blocks** | Headings, paragraphs, images (with alt text), blockquotes, ordered lists, code blocks, inline links |
| **Offline images** | Images served from local files, not network |

---

## 4. Home Screen

| Feature | Description |
|---------|-------------|
| **3-tab layout** | All / Unread / Downloaded |
| **Search** | Real-time search by title or domain |
| **Pull-to-refresh** | Swipe down to reload article list |
| **Article cards** | Shows title, domain, status badge, favorite icon |
| **Status badges** | Color-coded: Queued (gray), Downloading (blue), Ready (green), Failed (red) |
| **Empty state** | Friendly illustration + "Paste URL" CTA when no articles |
| **Auto-refresh** | List refreshes automatically when downloads complete/fail (stream listener) |
| **FAB: Add URL** | Floating action button to open add-URL dialog |
| **FAB: Download All** | Small FAB to queue all unread articles |

---

## 5. Search

| Feature | Description |
|---------|-------------|
| **Full-text search** | Search by article title or domain name |
| **Real-time results** | Results update as you type |
| **Clear button** | One-tap to clear search query |
| **Empty state** | Shows "No results found" or "Type to search" |

---

## 6. Settings

| Feature | Description |
|---------|-------------|
| **Language switcher** | English / Tiếng Việt / 简体中文 / System default |
| **Storage stats** | Total articles count, storage used (MB/GB) |
| **App info** | Version number, app name |
| **Privacy policy** | Explanation of local-only storage |
| **Help** | Placeholder for help screen |
| **Report bug** | Placeholder for bug reporting |

---

## 7. Internationalization (i18n)

| Feature | Description |
|---------|-------------|
| **3 languages** | English (en), Vietnamese (vi), Chinese Simplified (zh) |
| **Locale persistence** | Saved to SharedPreferences, restored on app start |
| **System default** | Follows device locale when not manually set |
| **Runtime switching** | Changes apply instantly without app restart |
| **50+ translated strings** | All UI text, error messages, onboarding, status labels |

---

## 8. Onboarding & Guidance

| Feature | Description |
|---------|-------------|
| **Spotlight overlay** | Highlights target widget with circular cut-out + tooltip |
| **Multi-step flow** | 3-step guided tour: Search → Download All → Add URL |
| **Progress dots** | Shows current step / total steps |
| **Skip / Done** | User can skip entire flow or advance step by step |
| **Persistence** | Remembers completed steps in SharedPreferences |
| **FeatureBadge** | "New" dot/label badge on FABs to draw attention |
| **DisabledStateHelper** | Explains why a button is disabled when tapped |
| **Auto-resume** | Flow resumes from last unseen step on app restart |

---

## 9. Safe Back Navigation

| Screen | Behavior |
|--------|----------|
| **HomeScreen** | Clear search → Switch to first tab → Exit (double-back) |
| **ReaderScreen** | Saves reading progress before navigating back |
| **SearchScreen** | Clears search query instead of exiting |
| **SettingsScreen** | Standard back navigation |

---

## 10. Monetization: AdMob

| Feature | Description |
|---------|-------------|
| **Banner ads** | Bottom banner on HomeScreen and ReaderScreen |
| **Interstitial ads** | Full-screen ad shown before opening article reader |
| **Rewarded ads** | Configured (ad unit ID ready) for future use |
| **Test/Production toggle** | `AdsConfig.testAds` flag — true = Google test IDs, false = real IDs |
| **Cooldown system** | Interstitial: 60s cooldown, Banner: 120s refresh cooldown |
| **Safe area** | Ads never obscured by Android system navigation buttons |
| **FAB positioning** | FABs float above banner ads, never overlap |

### Ad Unit IDs

| Type | Test ID | Production ID |
|------|---------|---------------|
| App ID | `ca-app-pub-3940256099942544~3347511713` | `ca-app-pub-6917313063209470~9608130345` |
| Banner | `ca-app-pub-3940256099942544/6300978111` | `ca-app-pub-6917313063209470/3645357226` |
| Interstitial | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-6917313063209470/3708936406` |
| Rewarded | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-6917313063209470/6079948874` |

---

## 11. Network & Security

| Feature | Description |
|---------|-------------|
| **HTTP cleartext** | Allowed for all domains via `network_security_config.xml` |
| **Content-Type validation** | Only accepts HTML-like content types |
| **URL extension check** | Rejects binary file extensions (.mp3, .mp4, .pdf, .zip, etc.) before HTTP request |
| **Response size guard** | 5MB max with script/style stripping |
| **HEAD request timeout** | 8-second timeout for redirect resolution |
| **URL canonicalization** | Strips tracking params for accurate duplicate detection |

---

## 12. Data & Storage

| Feature | Description |
|---------|-------------|
| **SQLite database** | Local article metadata, status, reading progress |
| **File-based content** | Article HTML stored as JSON files per article |
| **Image caching** | Downloaded images stored in app directory |
| **Startup sanitization** | Resets stuck downloads from previous sessions |
| **Storage stats** | Reports total articles and disk usage |

---

## 13. App Identity

| Property | Value |
|----------|-------|
| **Package name** | `com.mindsoft.thinksave` |
| **Display name** | ThinkSave |
| **Version** | 1.0.0+1 |
| **Min SDK** | 21 (Android 5.0) |
| **Target SDK** | 36 (Google Play requirement 31/8/2026) |
| **Icon** | Blue bookmark with green checkmark badge |

---

## 14. CI/CD

| Feature | Description |
|---------|-------------|
| **GitHub Actions** | Auto-build debug APK on push to `main` |
| **Flutter 3.24** | Pinned Flutter version for reproducible builds |
| **Artifact upload** | Debug APK uploaded as build artifact (7-day retention) |

---

## 15. Platform Support

| Platform | Status |
|----------|--------|
| **Android** | ✅ Primary target — share intent, adaptive icons, network security config |
| **iOS** | ✅ Supported — App Icon set, Info.plist configured, GADApplicationIdentifier |
| **Web** | ❌ Not supported (offline-first architecture requires native file system) |

---

## File Structure

```
lib/
├── main.dart                          # App entry, locale, AdMob init
├── l10n/
│   ├── app_en.arb                     # English strings
│   ├── app_vi.arb                     # Vietnamese strings
│   ├── app_zh.arb                     # Chinese strings
│   └── app_localizations.dart         # Generated localization class
├── core/
│   ├── ads/
│   │   ├── ads_config.dart            # AdMob config (test/prod toggle, IDs, cooldown)
│   │   └── ad_service.dart            # Ad loading, showing, lifecycle
│   ├── database/
│   │   └── database_helper.dart       # SQLite setup, queries, sanitization
│   ├── network/
│   │   ├── network_client.dart        # HTTP client with size/ctype guards
│   │   └── url_helper.dart            # URL validation, canonicalization
│   ├── onboarding/
│   │   ├── onboarding_state.dart      # SharedPreferences persistence
│   │   └── onboarding_step.dart       # Step data model
│   └── storage/
│       └── storage_helper.dart        # File system operations
├── models/
│   ├── article.dart                   # Article data model
│   ├── article_status.dart            # Status enum + extensions
│   └── content_block.dart             # Content block types (heading, paragraph, etc.)
├── repositories/
│   └── article_repository.dart        # Database CRUD operations
├── screens/
│   ├── home/home_screen.dart          # Main screen with tabs, search, FABs
│   ├── reader/reader_screen.dart      # Offline reader with themes
│   ├── search/search_screen.dart      # Dedicated search screen
│   └── settings/settings_screen.dart  # Language, storage, about
├── services/
│   ├── downloader/
│   │   └── download_queue_manager.dart # Queue, concurrency, retry
│   ├── extractor/
│   │   ├── http_extractor.dart        # HTML → content blocks
│   │   ├── webview_fallback_extractor.dart # JS-rendered page fallback
│   │   └── sanitizer.dart             # Clean HTML, remove junk
│   └── share_handler/
│       └── share_handler.dart         # Android share intent processing
└── widgets/
    ├── article_card.dart              # Article list item
    ├── status_badge.dart              # Status indicator badge
    ├── reader_controls.dart           # Theme/font/action controls
    └── onboarding/
        ├── spotlight_overlay.dart     # Tooltip + spotlight
        ├── feature_badge.dart         # "New" badge
        ├── disabled_state_helper.dart # Disabled button tooltip
        └── onboarding_coordinator.dart # Step flow manager
```
