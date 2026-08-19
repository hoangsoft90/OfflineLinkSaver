# Offline Link Saver

An offline-first read-later app that saves links for offline reading. Built with Flutter.

## Features

- **Save links instantly** - Share from Chrome, Facebook, Telegram, or paste URLs directly
- **Offline reading** - Download articles and read them without internet
- **Smart extraction** - Automatic content extraction with WebView fallback
- **Reading progress** - Track your reading position
- **Themes** - Light, Dark, and Sepia reading modes
- **Search** - Find articles by title or domain
- **Favorites** - Mark important articles

## Getting Started

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Android Studio or VS Code
- Android SDK (for Android development)
- Xcode (for iOS development)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd offline_link_saver
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Architecture

The app follows a clean architecture pattern:

```
lib/
├── main.dart                    # App entry point
├── core/                        # Core utilities
│   ├── database/               # SQLite database helper
│   ├── network/                # HTTP client and URL utilities
│   └── storage/                # File storage management
├── models/                      # Data models
│   ├── article.dart           # Article model
│   ├── article_status.dart    # Status enum
│   └── content_block.dart     # Content block model
├── repositories/                # Data layer
│   └── article_repository.dart # Article database operations
├── services/                    # Business logic
│   ├── extractor/             # Content extraction
│   ├── downloader/            # Download queue
│   └── share_handler/         # Android share integration
├── screens/                     # UI screens
│   ├── home/                  # Library screen
│   ├── reader/                # Offline reader
│   ├── search/                # Search screen
│   └── settings/              # Settings
└── widgets/                     # Reusable widgets
    ├── article_card.dart      # Article list card
    ├── status_badge.dart      # Status indicator
    └── reader_controls.dart   # Reader theme/font controls
```

## How It Works

1. **Save a link** - Share from other apps or paste URL in app
2. **Download** - App extracts content in background
3. **Read offline** - Open downloaded articles without internet
4. **Manage** - Search, favorite, delete articles

## Technical Details

### State Machine

Articles go through these states:
- `queued` → `downloading` → `processing` → `ready`
- Or `failed`/`online_only` if extraction fails

### Content Extraction

1. **HTTP Layer** - Fast HTML fetch and parse
2. **WebView Fallback** - For JavaScript-heavy sites
3. **Sanitizer** - Removes dangerous content

### Storage

- **Atomic writes** - Content saved to temp directory, then moved
- **UUID filenames** - Prevents path traversal attacks
- **Self-healing** - Detects and recovers from corrupted content

## Platform Support

### Android
- Full support with Share Sheet integration
- Receives shared URLs from other apps

### iOS
- Paste URL support
- Share Extension planned for future release

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- All the package authors who made this possible
