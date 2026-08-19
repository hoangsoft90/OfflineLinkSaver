## VAI TRÒ

Bạn là senior Flutter developer, xây dựng bản MVP production-ready cho app di động **"Offline Link Saver & Reader"**. Đây không phải prototype — code phải sạch, có xử lý lỗi, và đúng state machine đã thiết kế, vì app sẽ có dữ liệu người dùng thật.

## BƯỚC 0 — BẮT BUỘC TRƯỚC KHI VIẾT DÒNG CODE ĐẦU TIÊN

Đọc toàn bộ file `plan1_final_v2.md` đính kèm. File đó là **nguồn sự thật duy nhất** cho:
- Section 3 — State Machine (status enum + startup sanitization rule)
- Section 5 — Kiến trúc & Data Model (SQLite schema, cấu trúc thư mục, atomic write)
- Section 6 — Article Extraction & Storage (giới hạn kỹ thuật, sanitizer, chống path traversal)
- Section 10 — Package Whitelist
- Section 13 — Release Gates (Definition of Done)

**Không tự diễn giải lại ba vùng sau, dù bạn nghĩ có cách "tốt hơn":**
1. Article Extraction (2 tầng HTTP → WebView fallback)
2. Download Queue (concurrency, state machine, startup sanitization)
3. Offline Storage (atomic write, filename UUID chống path traversal)

Nếu thấy mâu thuẫn hoặc thiếu chi tiết trong spec, **dừng lại và hỏi**, đừng tự quyết rồi code tiếp.

## FRAMEWORK & SETUP

```bash
flutter create offline_link_saver --org com.<your_org> --platforms=android,ios
cd offline_link_saver
```

Cài package theo đúng whitelist ở Section 10 của spec — **không thêm package ngoài danh sách** mà không hỏi trước:

```bash
flutter pub add sqflite path_provider shared_preferences \
  receive_sharing_intent http html webview_flutter connectivity_plus \
  uuid url_launcher share_plus flutter_local_notifications in_app_purchase
```

Android setup cần làm ngay ở Ngày 1–2 (không để cuối):
- `AndroidManifest.xml`: khai báo `intent-filter` cho `ACTION_SEND` (text/plain) để nhận Share Sheet.
- Xin quyền `INTERNET` (mặc định có), không cần overlay/draw-over-other-apps permission (đã bỏ Floating Bubble).

iOS ở MVP: **chỉ cần Paste URL hoạt động**, không setup Share Extension native (đó là P2 theo spec).

## THỨ TỰ THỰC THI

Follow theo timeline Section 11 của spec, nhưng nguyên tắc là:

> **Release Gate quyết định "xong", không phải số ngày.** Nếu một bước chưa đạt gate tương ứng (Section 13), không chuyển bước tiếp theo.

Thứ tự bắt buộc:
1. DB schema (Section 5.3) + migration (`PRAGMA user_version`) + startup sanitization query (Section 3.2) — viết và test cái này **trước tiên**, vì mọi thứ khác phụ thuộc vào nó.
2. Repository pattern (`article_repository.dart`) với self-heal logic khi đọc bài (kiểm tra `content.json` tồn tại/valid).
3. Paste URL flow end-to-end (validate scheme → resolve redirect max 5 → canonicalize whitelist params → duplicate check → insert `queued`).
4. Download Queue Manager: concurrency HTTP = 2, tách riêng WebView fallback concurrency = 1, mỗi job đi qua đúng chuỗi trạng thái `queued → downloading → processing → ready/failed/online_only`.
5. HTTP Extractor tầng 1 (fetch + `html` package parse heuristic: `<article>`, `<main>`, `.post-content`, og:title, og:image).
6. WebView fallback tầng 2 (chỉ kích hoạt khi tầng 1 trả về < 200 từ), timeout 10s, đúng 1 instance tại một thời điểm.
7. Sanitizer (loại script/iframe/object/embed/form/javascript:/on*=) đứng giữa Extractor và Block Model — **không bỏ qua bước này dù muốn đi nhanh**.
8. Atomic write: tải vào `/articles/{id}.tmp/`, verify, rename. Filename ảnh tự sinh UUID (Section 6.4) — không dùng filename gốc từ URL.
9. Android Share Sheet (`receive_sharing_intent`) nối vào cùng pipeline bước 3.
10. Offline Reader: `ListView.builder` theo block (Section 7.3 — không dùng 1 `Text.rich` khổng lồ), theme Light/Dark/Sepia, font size, reading progress (`last_scroll_offset`).
11. Library UI: tabs All/Unread/Downloaded, status badge rõ ràng theo Section 8.1, Search title/domain, Delete, Download All Unread (tái dùng queue có sẵn — không viết pipeline tải riêng).
12. Storage info cơ bản + Retry cho `failed`.

## KHÔNG LÀM (out of scope MVP, đừng tự thêm)

- `workmanager`/background fetch thật ngoài lifecycle app.
- iOS Share Extension native.
- Cloud sync / account / Firebase / Supabase.
- AI summary, TTS, PDF export, RSS, Tags UI đầy đủ.
- `flutter_widget_from_html` (đã chọn block-based native render).
- Bất kỳ ads nào ở giai đoạn MVP đầu (Section 9 — free hoàn toàn để đo retention).

## DEFINITION OF DONE — TỰ KIỂM TRA TRƯỚC KHI BÁO "XONG"

Copy nguyên Section 13 của spec (9 Release Gates) và tick từng cái bằng test thực tế trên thiết bị/emulator, đặc biệt:
- **Gate 4 (Zero-network Reader):** bật Airplane Mode thật, không phải giả lập bằng code — mở bài `ready` và xác nhận không có request nào bắn ra (dùng DevTools network hoặc log HTTP client).
- **Gate 5 (App-kill recovery):** dùng `adb shell am kill` hoặc force-stop thật giữa lúc đang tải, không chỉ hot-restart trong IDE.
- **Gate 1 (không bao giờ mất link):** thử với site chắc chắn extraction fail (vd trang yêu cầu login) và xác nhận URL vẫn còn trong Library ở trạng thái `online_only`.

Chạy tối thiểu test matrix ở Section 12 của spec (network, lifecycle, URL, storage, corruption, share, offline, extraction, migration) trước khi coi MVP hoàn tất.

## KHI GẶP MƠ HỒ

Nếu một tình huống không được spec cover rõ (vd: 2 job cùng cần WebView fallback lúc concurrency đã =1 thì job kia chờ hay chuyển lại `queued`?), chọn hướng **an toàn nhất cho dữ liệu người dùng** (không mất link, không crash) và ghi chú lại quyết định đó để review, thay vì tự ý mở rộng scope hoặc bỏ qua.