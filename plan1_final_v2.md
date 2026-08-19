# Offline Link Saver & Reader — Design Spec (Final v2)

> Idea ID: #29 | Framework: Flutter
> Nguồn: `plan1.md` → `plan1_final.md` → hardening từ `plan1_final_review1..3.md`
> Trạng thái: **Sẵn sàng đóng băng để giao Coding Agent** sau khi các mục P0 dưới đây được tuân thủ đúng nghĩa đen — không để agent tự diễn giải lại State Machine, Extraction, hay Offline Storage.

---

## 1. Product Positioning

**Không xây:** ❌ Bookmark / URL manager.
**Xây:** ✅ Offline-first Read-Later app.

> **Save once. Read anywhere. Even offline.**

Core loop:
```
Share link → Save instantly → Download in background (khi app còn sống) → Clean article → Read later, kể cả không mạng
```

**Wording marketing/privacy phải chính xác** (đã sửa so với bản trước):
> ✅ "Saved content is stored locally on your device. The app does not upload your library to a cloud account. No account required."
> ❌ Không dùng: "No data ever leaves your device" — sai, vì app vẫn gửi request tới website nguồn khi tải bài.

---

## 2. Luồng chính (User Flows)

### Flow 1 — Save từ app khác (Android P0, iOS P1)
```
Chrome/Facebook/Telegram → Share → Offline Link Saver
→ UI hiện "✓ Saved" NGAY LẬP TỨC (không chờ extraction)
→ background: Resolve redirect (max 5 hops) → Validate scheme (chỉ http/https)
→ Canonicalize (whitelist tracking params) → Duplicate check
→ Insert SQLite (status: queued) → Download Queue xử lý
```

### Flow 2 — Save thủ công (Android + iOS, P0 — đường chính trên iOS)
```
Mở app → nút "+" → Paste URL → cùng pipeline validate/canonicalize/queue ở trên
```

### Flow 3 — Đọc offline
```
Library → chọn bài (status=ready) → Reader → đọc, ZERO network request
→ đóng app → mở lại → tiếp tục từ last_scroll_offset (P0-lite)
```

### Flow 4 — Extraction fail
```
Download → không extract được → status: online_only
→ UI: "Offline copy unavailable — Open in browser when online" + nút [Retry] [Open original]
```
**Không expose lỗi kỹ thuật cho user** (không hiện `TimeoutException`, `DOMParserException`...). Message luôn human-readable.

### Flow 5 — Duplicate
```
User share URL đã tồn tại (theo canonical_url) → popup "Already saved on [date]"
→ [Open] hoặc nếu status=failed/online_only → [Retry download]
```

### Flow 6 — Download All Unread (P0.5)
```
Library → nút "Prepare for Offline" → tất cả bài status IN (queued, failed, online_only) và is_read=false
→ được ENQUEUE vào CÙNG Download Queue hiện có (không tạo cơ chế tải riêng)
→ vẫn tuân thủ concurrency = 2 (HTTP) / 1 (WebView fallback)
→ UI hiện tiến trình "12/40 downloaded"
```

---

## 3. State Machine (đã hardening)

### 3.1 Enum trạng thái
```dart
enum ArticleStatus {
  queued,       // chờ trong hàng đợi
  downloading,  // đang fetch HTTP
  processing,   // đang parse/sanitize/normalize/tải ảnh
  ready,        // hoàn tất, đọc offline 100%
  failed,       // lỗi CÓ THỂ retry (network, timeout, parse tạm thời)
  online_only,  // đã XÁC ĐỊNH không tạo được offline article — vẫn giữ URL/metadata
}
```
Phân biệt rõ: `failed` = có khả năng thành công nếu retry; `online_only` = kết luận cuối cùng, không auto-retry mà cần user hành động hoặc website thay đổi.

### 3.2 Startup sanitization — BẮT BUỘC, chạy mỗi lần app mở
```sql
UPDATE articles SET status = 'queued'
WHERE status IN ('downloading', 'processing');
```
Lý do: nếu OS kill process khi đang `downloading`/`processing`, item sẽ kẹt vĩnh viễn nếu không có bước này. Đây là **must-have implementation rule**, không phải optional.

### 3.3 Semantics "background download" — chốt wording chính xác
**Không promise:** "App tự động tải khi bị kill/ở background vô thời hạn."
**Promise đúng:**
> Downloads start automatically while the app process is available (foreground hoặc background ngắn hạn của OS), và queue được lưu bền vững (SQLite). Nếu process bị OS kill, khi user mở lại app, các item `queued`/`downloading`/`processing` cũ sẽ tự động resume.

Không dùng `workmanager`/background fetch thật ở MVP — đây là rủi ro product **đã được chấp nhận có chủ đích**, ghi rõ trong risk log, không phải thiếu sót.

`connectivity_plus` chỉ là **hint UX** (hiện icon "offline"), không phải điều kiện quyết định có download hay không — downloader luôn thử request thật và tự xử lý timeout/lỗi, vì "WiFi connected" không đồng nghĩa "Internet reachable".

---

## 4. MVP Scope (đã điều chỉnh ưu tiên)

### P0 — Bắt buộc
1. Paste URL (chính trên iOS)
2. Android Share Sheet (`receive_sharing_intent`, không phải `share_plus`)
3. Save phản hồi tức thì ("✓ Saved" trước khi extraction xong)
4. Persistent Download Queue (concurrency HTTP = 2, WebView fallback = 1)
5. HTTP Extraction (tầng 1)
6. Local article storage (atomic write — mục 6)
7. Offline Reader: `ListView.builder` theo block (không dùng 1 `Text.rich` khổng lồ — xem mục 7.3), font size, theme Light/Dark/Sepia
8. Download status hiển thị rõ trên Library card
9. Retry khi `failed`
10. Delete (xóa cả metadata + content + images, khác với "Clear image cache" — mục 8.2)
11. Library: tabs All / Unread / Downloaded (`Downloaded` = `status == ready`) + Search (title, domain)
12. Read/unread state
13. URL validation (chỉ chấp nhận `http://`, `https://`; reject `javascript:`, `file:`, `data:`, `intent:`...)
14. Offline hoạt động 100% khi `ready` — release gate bắt buộc

### P0.5 — Ngay sau P0, chi phí thấp / giá trị cao
15. Reading progress (`last_scroll_offset`, đơn giản, không cần analytics)
16. Download All Unread (tái dùng queue hiện có — Flow 6)
17. Cover image ưu tiên tải trước inline images (mục 6.3)

### P1
18. Favorites (ưu tiên hơn Tags)
19. Storage Manager chi tiết (Clear image cache, Auto-delete read sau 30 ngày)
20. Wi-Fi auto-download
21. Search theo content/excerpt (không chỉ title/domain)
22. Tags (hạ từ P1 ban đầu — tốn scope UI, để sau Favorites)

### P2 — Sau MVP
- Cloud sync, Account, AI summary/tagging, Text-to-Speech
- Export PDF/Markdown, Browser extension, RSS, Archive/Trash, Collections
- Content-hash duplicate detection (khớp bài trùng dù URL khác — amp/mobile domain)
- SQLite FTS cho search full-text
- iOS Share Extension đầy đủ (native Xcode target + App Group)
- Article refresh (source cập nhật → offline copy cũ) — MVP coi saved article gần như immutable, nhưng kiến trúc không giả định nó *phải* immutable mãi mãi

---

## 5. Kiến trúc & Data Model

### 5.1 Kiến trúc tổng thể
```
Android Share / Paste URL
        │
        ▼
URL Validate (scheme http/https only)
        │
        ▼
Redirect Resolver (max 5 hops) ──► Canonicalize (whitelist strip: utm_*, fbclid, gclid, msclkid, ref, mc_cid, mc_eid)
        │
        ▼
SQLite Duplicate Check (theo canonical_url)
 ├── [Trùng] ──► "Already saved on [date]" / [Open] / [Retry nếu lỗi]
 └── [Mới] ───► Insert SQLite (status: queued) → UI "✓ Saved" ngay
        │
        ▼
Persistent Download Queue (HTTP concurrency = 2)
        │
        ▼
HTTP Extractor (Tầng 1: fetch + parse bằng package `html`)
 ├── (Đủ nội dung, ví dụ ≥200 từ) ──────────────────────────────┐
 └── (Không đủ / SPA) ──► WebView Fallback (Tầng 2, BEST-EFFORT)│
       concurrency = 1, timeout render = 10s,                    │
       max page size riêng, không để queue kẹt ở `processing`    │
                                                                  ▼
                                              HTML Sanitizer
                                    (loại <script>, <iframe>, <object>,
                                     <embed>, <form>, javascript:, on*=)
                                                                  │
                                                                  ▼
                                          Normalized Block Model
                                        (heading/paragraph/image/quote/list)
                                                                  │
                                                                  ▼
                                    Tải assets vào /articles/{id}.tmp/
                                    (cover image ưu tiên trước inline images;
                                     filename tự sinh UUID, KHÔNG dùng
                                     filename gốc từ URL — chống path traversal)
                                                                  │
                                                                  ▼
                            Verify: content.json tồn tại + valid JSON
                            + assets bắt buộc đã có → rename .tmp → chính thức
                                                                  │
                                                                  ▼
                                    Update SQLite (status: ready)
                                                                  │
                                                                  ▼
                                              Offline Reader
                                          (ListView.builder theo block)
```

### 5.2 Cấu trúc thư mục Flutter
```
lib/
├── main.dart                 # gọi startup sanitization (mục 3.2) trước khi build UI
├── core/
│   ├── database/              # sqflite helper + migration (PRAGMA user_version)
│   ├── network/                # http client, redirect resolver, connectivity hint
│   └── storage/                # path_provider file manager, atomic write helper
├── models/
│   ├── article.dart
│   └── article_status.dart
├── repositories/
│   └── article_repository.dart   # self-heal: kiểm tra content.json khi getArticle()
├── services/
│   ├── extractor/                 # ArticleExtractor interface
│   │   ├── http_extractor.dart
│   │   ├── webview_fallback_extractor.dart
│   │   └── sanitizer.dart
│   ├── downloader/                 # DownloadQueueManager (concurrency tách riêng HTTP/WebView)
│   └── share_handler/               # receive_sharing_intent wiring (Android)
├── screens/
│   ├── home/                # Library: All/Unread/Downloaded + Search + Download All Unread
│   ├── reader/                # Offline Reader
│   ├── search/
│   └── settings/                # Storage manager, reader prefs, privacy policy
└── widgets/
    ├── article_card.dart      # hiện rõ trạng thái: Saved / Downloading / Ready / Offline unavailable
    ├── status_badge.dart
    └── reader_controls.dart
```

### 5.3 SQLite schema (bảng `articles`)
| field | type | ghi chú |
|---|---|---|
| id | TEXT (UUID) | |
| original_url | TEXT | **không bao giờ overwrite**, giữ để audit/debug |
| canonical_url | TEXT | sau redirect resolve + whitelist strip; UNIQUE |
| title | TEXT | |
| domain | TEXT | |
| author | TEXT | nullable |
| excerpt | TEXT | |
| cover_image_path | TEXT | local path, filename tự sinh UUID |
| content_path | TEXT | path tới content.json |
| status | ENUM | mục 3.1 |
| extractor_version | INTEGER | dùng để đánh dấu bài cần re-extract khi thuật toán nâng cấp — **re-extraction là maintenance nền, KHÔNG block app startup** dù có bao nhiêu bài |
| is_read | BOOL | |
| is_favorite | BOOL | P1 |
| reading_progress | DOUBLE | 0.0–1.0, P0.5 |
| error_message | TEXT | nullable, human-readable, hiển thị khi `failed`/`online_only` |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | cập nhật mỗi lần thay đổi status |

Migration: dùng `PRAGMA user_version` + migration script rõ ràng ngay từ v1, để tránh vỡ dữ liệu khi cập nhật schema sau này.

### 5.4 FileSystem
```
/articles/{id}.tmp/          # khi đang tải, có thể chứa dữ liệu dở dang
    content.json
    images/{uuid}.jpg
/articles/{id}/              # CHỈ tồn tại sau khi verify xong (mục 5.1)
    content.json
    images/{uuid}.jpg
```
**Backup policy:** loại trừ cả SQLite database lẫn thư mục `/articles/` khỏi auto-backup của OS (Android Auto Backup / iCloud), để tránh trường hợp cài lại app trên máy mới với DB được backup nhưng file bị thiếu (dangling reference). Nếu vì lý do nào đó vẫn cho phép backup, `article_repository.getArticle()` bắt buộc self-heal: kiểm tra `content.json` tồn tại + valid JSON trước khi trả về; nếu thiếu/hỏng → tự chuyển `status = 'failed'`.

---

## 6. Article Extraction & Storage — chi tiết hardening

### 6.1 Nguyên tắc chung
- `ArticleExtractor` là interface, implementation thay được không đụng UI/Repository.
- Không hứa hỗ trợ 100% website — chỉ promise "Supported articles", test 15–20 site phổ biến trước release.
- **WebView fallback là best-effort, không phải cơ chế đảm bảo.** Nhiều trường hợp vẫn fail: bot protection, cookie consent chặn, infinite scroll, paywall, auth-gated content. Đây là behavior chấp nhận được, không phải bug.

### 6.2 Giới hạn kỹ thuật (chốt số cứng, không để agent tự quyết)
| Giới hạn | Giá trị | Ghi chú |
|---|---|---|
| Timeout fetch HTTP | 15s | quá thì chuyển `failed`, có thể auto-retry |
| Max response size (an toàn kỹ thuật, không phải "rule extraction") | 2MB | HTML lớn không có nghĩa article dài — có thể do JSON/tracking script; đây là **safety guard**, gọi đúng tên |
| WebView render timeout | 10s | quá thì fallback coi là fail |
| WebView concurrency | 1 | tách riêng khỏi HTTP concurrency = 2 |
| Max redirect hops | 5 | chống redirect loop |
| Max ảnh/bài | 15 | ưu tiên cover trước, rồi mới inline theo thứ tự DOM |
| Max size/ảnh | 5MB | vượt thì skip ảnh đó, không fail cả bài |
| Max tổng dung lượng offline/bài | ví dụ 50MB (chốt số cụ thể theo product) | vượt → giữ text, bỏ bớt ảnh cuối, đánh dấu "partial assets" thay vì fail toàn bộ |

### 6.3 Quy tắc xử lý lỗi ảnh
Nếu text + cấu trúc article extract đầy đủ nhưng một số ảnh tải lỗi (vd 3/15): **bài viết vẫn `ready`**, Reader hiển thị placeholder cho ảnh thiếu. Không đánh fail toàn bài chỉ vì lỗi ảnh phụ.

### 6.4 Bảo mật khi parse & lưu
- Sanitizer bắt buộc đứng giữa Extractor và Block Model: loại bỏ `<script>`, `<iframe>`, `<object>`, `<embed>`, `<form>`, `javascript:`, mọi thuộc tính `on*=`.
- Chỉ chấp nhận ảnh có scheme `http://`/`https://` trước khi tải.
- **Tên file ảnh lưu local phải tự sinh (UUID), không bao giờ dùng filename gốc trích từ URL** — tránh path traversal (`../../etc/...`) ghi đè file ngoài thư mục `/images/`.

---

## 7. Offline Reader

### 7.1 Nội dung hiển thị
Title, author, source/domain, date, ảnh cover, nội dung dạng heading/paragraph/list/blockquote/image local, link (mở qua `url_launcher`, cần mạng), thanh chỉnh font size, theme Light/Dark/Sepia, nút quay lại/yêu thích/chia sẻ/xóa.

### 7.2 "Saved" và "Available offline" là hai trạng thái UX khác nhau
- **Stage 1 — Saved:** URL đã vào Library, hiện ngay sau share/paste, không chờ extraction.
- **Stage 2 — Available offline:** content đã `ready`.
Một bài `online_only` vẫn là **save thành công**, chỉ là chưa có bản offline — UI phải phản ánh đúng phân biệt này, không gộp chung thành "lỗi".

### 7.3 Render bằng `ListView.builder`, không dùng 1 `Text.rich` khổng lồ
Vì content đã ở dạng block-based JSON, hãy render mỗi block (heading/paragraph/image/quote) là 1 item riêng trong `ListView.builder` để có virtualization tự nhiên. Dồn toàn bộ bài dài (5.000–10.000 từ + nhiều ảnh) vào một `Text.rich`/`WidgetSpan` duy nhất sẽ gây rebuild nặng và giật khi scroll/đổi font size trên thiết bị yếu.

### 7.4 Release gate riêng cho Reader
Mở bài `ready` ở Airplane Mode: text, title, author, source, cover, inline images, reading position, theme, font size đều hiển thị đúng, và **Reader tuyệt đối không phát sinh HTTP request nào**.

---

## 8. Library UX

### 8.1 Trạng thái hiển thị trên card (rõ ràng, không mơ hồ)
```
✓ Saved · Offline copy ready         (status = ready)
⏳ Downloading… / Processing…         (status = downloading/processing)
⚠ Offline copy unavailable [Retry]   (status = failed/online_only)
```
Empty state khi Library trống: hướng dẫn share link từ Chrome/Facebook/Telegram, hoặc bấm "+" paste URL.

### 8.2 Delete vs Clear image cache — hai hành vi khác nhau
- **Delete:** xóa metadata + content + toàn bộ `/articles/{id}/` — không thể khôi phục.
- **Clear image cache (P1):** giữ metadata + text, chỉ xóa ảnh optional; bài vẫn `ready`, Reader hiển thị placeholder cho ảnh đã xóa.

### 8.3 Search
- P0: title + domain.
- P1: mở rộng excerpt + content.
- P2: SQLite FTS full-text.
Không thiết kế schema khóa cứng vào chỉ title/domain — để dành đường nâng cấp.

---

## 9. Monetization

- **MVP giai đoạn 1:** Free hoàn toàn, không ads — đo retention trước.
- **Sau khi có data:** Free (ads chỉ ở Library, không bao giờ trong Reader hay trên nội dung crawl) + Pro one-time IAP (remove ads, custom theme, export sau này).
- Wording đúng: **"No artificial app storage limit"** thay vì "Unlimited storage" — điện thoại vẫn có giới hạn vật lý, tránh hiểu nhầm app đảm bảo dung lượng vô hạn.
- **Store/AdMob policy compliance phải được re-verify trước khi bật monetization**, không coi việc "không đặt ads trên nội dung crawl + có attribution" là guarantee tuyệt đối về chính sách — chỉ là mitigation tốt.

---

## 10. Package Whitelist

**P0:** `sqflite`, `path_provider`, `shared_preferences`, `receive_sharing_intent` (Android), `http`/`dio`, `html`, `webview_flutter` (fallback ẩn), `connectivity_plus` (hint only), `uuid`, `url_launcher`, `share_plus` (chỉ dùng để share ra ngoài, không phải nhận), `flutter_local_notifications`, `in_app_purchase`.

**P1:** `flutter_image_compress`, `google_mobile_ads` (chỉ bật sau khi qua P0, xem mục 9).

**Không đưa vào MVP:** `hive` (đã chọn hẳn sqflite), `fl_chart`, `pdf`, `file_picker`, `workmanager`/background fetch thật, `flutter_widget_from_html` (đã chọn render native theo block thay vì HTML clean).

---

## 11. Timeline (7 ngày là target, không phải deadline cứng)

| Ngày | Nội dung |
|---|---|
| 1 | Architecture, DB schema + migration, models, Library UI, Paste URL |
| 2 | `receive_sharing_intent` (Android) + Persistent Queue + startup sanitization + HTTP fetch |
| 3 | Article Extractor 2 tầng + Sanitizer + atomic write + status |
| 4 | Offline Reader (`ListView.builder`) + theme + font size + reading progress |
| 5 | Search, duplicate/redirect resolve, retry, Download All Unread, storage info |
| 6 | Test matrix (mục 12) — offline, kill app, network loss, corrupted data, nhiều site |
| 7 | Polish UI + edge cases + release gates review |

Nguyên tắc: **release gate quyết định "done", không phải số ngày.** Nếu Ngày 3 (extraction) chưa đạt gate, không chuyển sang Ngày 4 chỉ vì lịch. Nếu Coding Agent không đạt target, kéo dài lên 8–9 ngày còn hơn ship MVP extraction fail liên tục.

---

## 12. Test Matrix

- **Network:** WiFi / mobile data / mất mạng giữa chừng / mạng chậm.
- **Lifecycle:** app background, app bị kill giữa `downloading`/`processing`, khởi động lại điện thoại → verify queue resume đúng qua startup sanitization.
- **URL:** hợp lệ, không hợp lệ (scheme bị reject), trùng lặp, có redirect/shortlink (test max 5 hops), có UTM lẫn query hợp lệ khác (`?id=`, `?v=`), site không hỗ trợ.
- **Storage:** hết dung lượng giữa lúc tải, tải ảnh fail một phần, xóa bài giữa lúc đang download.
- **Local data corruption (mới):** `content.json` missing, `content.json` malformed, ảnh missing, DB row tồn tại nhưng thư mục mất, thư mục tồn tại nhưng DB row mất → app phải tự heal, không crash.
- **Share:** Chrome, Facebook, Telegram, Reddit (Android).
- **Offline (quan trọng nhất):** download xong → Airplane Mode → mở bài → đọc được 100%, zero network request.
- **Extraction:** test 15–20 site đa dạng (báo, blog, SPA) để đo tỷ lệ thành công thực tế, bao gồm cả case WebView fallback fail (bot protection/paywall) → phải rơi về `online_only` gracefully, không kẹt ở `processing`.
- **DB migration:** giả lập v1 schema → app update → v2 schema, verify không mất dữ liệu.

---

## 13. Release Gates — Definition of Done (danh sách canonical, đã gộp & khử trùng)

MVP chỉ được coi là hoàn tất khi đạt đủ 9 gate sau:

1. **Save không bao giờ mất link (invariant cốt lõi):** một khi URL đã save thành công, lỗi extraction/download **không bao giờ** tự động xóa item — chỉ chuyển `failed`/`online_only`.
2. **Instant feedback:** Share/Paste → UI hiện "✓ Saved" trong vài giây, không chờ extraction.
3. **Download thành công:** site được hỗ trợ → `ready` trong thời gian hợp lý.
4. **Zero-network Reader:** Airplane Mode, bài `ready` → đọc được 100% text/ảnh/theme/font/reading-position, không có bất kỳ HTTP request nào.
5. **App-kill recovery:** kill app khi đang tải 5 bài → mở lại → các item tự động quay về `queued` (qua startup sanitization) và resume tải.
6. **Graceful failure:** site không hỗ trợ → URL vẫn được giữ, status `online_only`/`failed`, Retry hoạt động, error message human-readable.
7. **Dọn dẹp triệt để:** bấm Delete → cả metadata trong DB lẫn toàn bộ `/articles/{id}/` trên đĩa biến mất hoàn toàn.
8. **Atomic file integrity:** mở một bài `ready` → `content.json` luôn tồn tại + valid; nếu không, app tự self-heal chuyển `failed` và hiện Retry, không crash.
9. **Storage full handled gracefully:** hết dung lượng giữa lúc tải → app bắt lỗi, giữ trạng thái `queued`/`failed` (không đánh sai state), thông báo rõ ràng, không crash.

---

## 14. Rủi ro đã biết & chấp nhận có chủ đích (Accepted Risks)

| Rủi ro | Mức độ | Quyết định |
|---|---|---|
| Không dùng WorkManager/background fetch thật | Trung bình | Chấp nhận ở MVP — "background download" chỉ nghĩa là queue bền vững + resume khi mở lại app |
| WebView fallback không giải quyết được mọi SPA/paywall/bot-protection | Cao | Chấp nhận — best-effort, không promise 100% website |
| iOS Share Sheet cần native Share Extension phức tạp | Cao | Chấp nhận — MVP iOS dùng Paste URL, Share Extension để P1/P2 |
| Store/AdMob policy về nội dung crawl chưa được xác nhận chính thức | Trung bình | Chấp nhận — MVP không bật ads, re-verify policy trước khi bật |
| Duplicate detection chỉ theo canonical URL, chưa theo content-hash | Thấp | Chấp nhận ở MVP — content-hash để P2 |

---

## 15. Kết luận

`plan1_final_v2.md` giữ nguyên toàn bộ product direction đã chốt từ các vòng trước (Offline-first Read-Later, bỏ Floating Bubble, block-based storage, no-cloud), đồng thời hardening đầy đủ các lỗ hổng State Machine, Atomic Write, Canonicalization, WebView Fallback, Security (path traversal, sanitization), Reader Performance, và Release Gates đã được 3 vòng review + phản biện chỉ ra. Trọng tâm cuối cùng:

> **Save không bao giờ mất → Download có state machine chuẩn (kể cả khi app bị kill) → Extraction fail gracefully → Content được sanitize/normalize an toàn → `ready` nghĩa là đọc 100% offline → Reader mượt với bài dài → app kill vẫn resume đúng.**

Đừng để Coding Agent tự "sáng tạo" lại ở ba vùng: **Article Extraction, Download Queue, và Offline Storage** — đây là ba nơi nếu agent tự diễn giải sẽ tạo ra bug khó phát hiện sau khi app đã có dữ liệu người dùng thật.