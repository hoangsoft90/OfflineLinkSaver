# operating_rules.md — How to Work on This Project

> Rules that every session must follow. Non-negotiable.

---

## 1. Before Writing Code

1. Read `AGENTS.md` (agent instructions)
2. Read `CLAUDE.md` (Claude-specific rules)
3. Check `working.md` for current status
4. Read `.project/state.md` if touching state machine
5. Read `.project/ai-rules.md` if unsure about constraints

---

## 2. State Machine Rules

The article status machine is sacred. Do NOT modify without explicit approval.

```
queued → downloading → processing → ready
   ↓         ↓            ↓
failed    failed       failed
   ↓
online_only
```

**Never:**
- Skip a state (e.g., queued → ready directly)
- Add new states without asking
- Delete an article on failure
- Remove startup sanitization

---

## 3. File System Rules

### Atomic Writes
```
/articles/{id}.tmp/     ← write here first
    ↓ verify
/articles/{id}/         ← rename to final
```
Never write directly to final directory.

### Image Filenames
```dart
// ALWAYS: UUID-based
final filename = '${const Uuid().v4()}.jpg';

// NEVER: Original filename
final filename = uri.pathSegments.last;  // PATH TRAVERSAL RISK
```

### Self-Heal on Read
When fetching a `ready` article, always verify `content.json` exists and is valid.

---

## 4. Network Rules

### Allowed
- HTTP requests in `services/extractor/` (extraction)
- HTTP requests in `core/network/` (network client)
- HTTP requests in `services/downloader/` (image download)

### Forbidden
- ❌ Network requests in `screens/reader/` (breaks offline)
- ❌ Network requests in `widgets/` (breaks offline)
- ❌ Network requests in `repositories/` (data layer only)

### Concurrency
| Resource | Limit |
|---|---|
| HTTP downloads | 2 parallel |
| WebView fallback | 1 at a time |
| Images/article | 15 max |
| Image size | 5MB max |

---

## 5. Error Handling Rules

### User-Facing Messages
Always human-readable, never technical:
```dart
// ✅ CORRECT
'⚠ Download failed'
'Connection timeout'

// ❌ WRONG
'TimeoutException after 15000ms'
'Error: SocketException: Connection refused'
```

### Error States
- `failed` = retryable (network, timeout, temporary)
- `online_only` = permanent (bot protection, paywall)

### Never Crash
- Catch exceptions in repository methods
- Catch exceptions in service methods
- Show SnackBar for UI errors
- Return null for "not found"

---

## 6. UI Rules

### Library Card States
```
✓ Saved · Offline copy ready         (status = ready)
⏳ Downloading… / Processing…         (status = downloading/processing)
⚠ Offline copy unavailable [Retry]   (status = failed/online_only)
```

### Empty State
Show helpful instructions, not blank screen.

### Search
- P0: title + domain only
- Real-time filtering
- Clear button when active

### Reader
- `ListView.builder` per block (NOT one Text.rich)
- Theme: Light / Dark / Sepia
- Font size: 12–24
- Reading position saved on scroll

---

## 7. Package Rules

### Whitelist (Only These)
**P0:** `sqflite`, `path_provider`, `shared_preferences`, `receive_sharing_intent`, `http`, `html`, `webview_flutter`, `connectivity_plus`, `uuid`, `url_launcher`, `share_plus`, `flutter_local_notifications`, `in_app_purchase`

**Forbidden in MVP:** `hive`, `fl_chart`, `pdf`, `file_picker`, `workmanager`, `flutter_widget_from_html`

### Adding Packages
1. Check whitelist first
2. If not in whitelist, ask before adding
3. Justify the need
4. No bundled dependencies

---

## 8. Testing Rules

### Before Claiming "Done"
Run through 9 Release Gates (`plan1_final_v2.md` §13).

### Critical Tests
- **Gate 4:** Real Airplane Mode (not simulated)
- **Gate 5:** `adb shell am kill` (not hot-restart)
- **Gate 1:** Site that definitely fails extraction

### Test Matrix
- Network: WiFi / mobile / loss / slow
- Lifecycle: background / kill / reboot
- URL: valid / invalid / duplicate / redirects
- Storage: full / partial failure / delete during download
- Corruption: missing files / malformed JSON
- Offline: download → Airplane Mode → read 100%

---

## 9. Git Rules

### Before Commit
1. `flutter analyze` — no errors
2. `flutter test` — all pass (when tests exist)
3. Review changes — no unintended modifications

### Commit Messages
```
<type>(<scope>): <description>

Types: feat, fix, refactor, test, docs, chore
Scope: core, extractor, downloader, reader, ui, models
```

### Branch Strategy
- `main` — stable, releasable
- `feature/*` — new features
- `fix/*` — bug fixes

---

## 10. Session Continuity

### When Starting a Session
1. Read `working.md` for current status
2. Check `git status` for uncommitted work
3. Review recent changes
4. Pick up where left off

### When Ending a Session
1. Update `working.md` with progress
2. Commit changes (if any)
3. Note any blockers or decisions made
4. Update todos if available

### Information Hierarchy
```
AGENTS.md          ← Agent instructions (start here)
CLAUDE.md          ← Claude-specific rules
working.md         ← Current status & next steps
context.md         ← Project history & decisions
operating_rules.md ← Rules for working on project
.project/          ← Detailed knowledge base
plan1_final_v2.md  ← Full spec (authoritative)
```
