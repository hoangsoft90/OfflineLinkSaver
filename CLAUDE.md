# CLAUDE.md — Claude Code Agent Instructions

> Claude-specific conventions. Also read `AGENTS.md` and `.project/README.md`.

## Identity

I am Buffy (Codebuff). This project uses Freebuff. Keep role consistent.

## Project Context

**Offline Link Saver** — Flutter offline-first read-later app.
- **Spec:** `plan1_final_v2.md` (authoritative, don't reinterpret)
- **Knowledge Base:** `.project/` folder (architecture, patterns, state, modules)
- **SDK:** Dart >=3.0.0 <4.0.0, Flutter 3.x

## Simplenote MCP

Config: `~/mcp.json` | Auth: `~/.config/simplenote-mcp/auth.json`
Package: `@automattic/simplenote-mcp` | User: `kd.hoangweb@gmail.com`

Call via stdio JSON-RPC. See `.agents/skills/simplenote-mcp.md` for full usage.
Quick: `list_notes`, `create_note`, `search_notes`, `update_note`, `trash_note`.

## File Reading Priority

When starting work, read in this order:
1. `AGENTS.md` — Agent instructions
2. `.project/README.md` — Project overview & quick links
3. `.project/state.md` — State machine & data models
4. `.project/ai-rules.md` — Do-not-modify zones
5. `plan1_final_v2.md` — Full spec (only if needed)

## Code Style

```dart
// Use super.key, const constructors
const MyWidget({super.key, required this.param});

// Package imports first, then relative
import 'package:flutter/material.dart';
import '../models/article.dart';

// Return null for "not found", don't throw
Future<Article?> getArticle(String id) async { ... }

// Result objects over exceptions
ExtractionResult result = await extractor.extract(url);

// Human-readable errors, never technical exceptions
errorMessage: 'Connection timeout'  // not 'TimeoutException after 15000ms'
```

## Edit Rules

- Prefer editing existing files over creating new ones
- Fewest changes that address the request
- Match existing code style (snake_case files, camelCase vars)
- Verify non-trivial changes with `flutter analyze`

## Forbidden Actions

- Don't run `git push` or destructive git commands without asking
- Don't install packages not in whitelist
- Don't add network requests in the reader path
- Don't delete articles on extraction failure
- Don't remove startup sanitization from `main.dart`

## State Machine (Memorize This)

```
queued → downloading → processing → ready
   ↓         ↓            ↓
failed    failed       failed
   ↓
online_only
```

- `failed` = retryable
- `online_only` = permanent (needs user action)
- Stuck items → startup sanitization resets to `queued`

## Concurrency Limits

| Resource | Limit |
|---|---|
| HTTP downloads | 2 parallel |
| WebView fallback | 1 at a time |
| Images/article | 15 max |
| Image size | 5MB max |
| Total article | 50MB max |

## If Stuck

- Check `.project/modules/` for module-specific docs
- Check `plan1_final_v2.md` for spec details
- When in doubt, ask the user — don't guess
