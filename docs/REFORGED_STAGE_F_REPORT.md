# Iron Redoubt Reforged — Stage F: Kiểm tra hồi quy & bản build 0.8.0

Ngày: 2026-11-12 · Trạng thái: **xong**. APK đã build + ký + kiểm tra. **Chưa cài lên điện thoại thật** vì `adb devices` trống.

## Bản build

`build/Iron Redoubt-0.8.0-playtest.apk` (53.6 MB; bản 0.7.0 là 53.0 MB). Build lại bằng:

```bash
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1
```

| Mục | Giá trị (đọc bằng `aapt2` / `apksigner`) |
|---|---|
| Package | `com.ironredoubt.game` (không đổi) |
| Phiên bản | `0.8.0-playtest`, **versionCode 8** (> 7, nên **cài đè lên 0.7.0 được**) |
| SDK | min 24 / target 36 |
| ABI | arm64-v8a, armeabi-v7a |
| Quyền | **không có** (offline hoàn toàn) |
| Chữ ký | v2 + v3, cùng khoá playtest Iron Redoubt → `Verifies` |
| Nội dung | font OFL, icon SVG, bản dịch VI có trong APK; **không có** `tests/`, `tools/`, `docs/` |
| Log export | không có error/warning |

## Kiểm tra hồi quy (kết quả thật)

| Hạng mục | Cách kiểm | Kết quả |
|---|---|---|
| Toàn bộ logic | test suite | **`132 passed, 0 failed (227.4s)`**, 0 `SCRIPT ERROR` |
| **Gameplay không đổi** | golden 18 trận (9 màn × 2 cấu hình bot), so 9 chỉ số/trận với baseline ghi **trước** Stage C | khớp 100% |
| Tiến trình chiến dịch | `test_progression`, `test_campaign_levels`, `test_menus` (thẻ màn khoá/mở khớp model) | pass |
| **Save cũ 0.7.0** | `test_save_compat`: file `profile.json` **thật do 0.7.0 ghi** (`tests/fixtures/profile_v070.json`) → load không cần sửa, Lõi/màn/thành tựu giữ nguyên, L7 mở, L8 khoá, save/load lại khớp | pass |
| Settings cũ | `test_hud`: file settings 0.7.0 (không có khoá "Giảm hiệu ứng") → mặc định tắt | pass |
| Điều khiển chạm | `test_placement_input` (kéo-thả, chạm-đặt, huỷ), `test_release` (nút Back tạm dừng/tiếp tục) | pass |
| Ứng dụng nền / mở lại | `test_release` (tự tạm dừng + flush save khi vào nền; mở lại khôi phục tiến trình) | pass |
| Không có mã mạng | `test_release` quét toàn bộ script runtime | pass |
| Bản dịch | `extract_keys.py` + `test_i18n` | 393 key, 0 thiếu |
| Cân bằng (bằng chứng phụ) | `campaign_sim --crosspath`, 3 chiến thuật × 9 màn | 26/27 thắng; chỉ "swarm" thua L6. Giống hệt kết quả trước Reforged |
| Hình ảnh | chụp lại menu, chiến dịch, 3 bản đồ, HUD/panel, kết quả ở 16:9 EN + 20:9 tai thỏ VI | không thấy lỗi mới; số phiên bản hiện `v0.8.0` |
| Hiệu năng | `perf_probe` L8 stress 51 quái, x2, desktop | trung bình 7.0 ms/khung (**không đại diện điện thoại**) |

## Lỗi đã sửa trong cả đợt Reforged (do kiểm tra phát hiện)

- **Stage B:**
  - hiệu ứng trượt bị container ghi đè vị trí;
  - chữ "Qua màn N" bị dọc;
  - tên màn bị lặp số.
- **Stage C/D:**
  - đa giác lục giác "triangulation failed";
  - đạn/hiệu ứng bị thân quái che;
  - thanh máu boss trùng với thanh cũ.
- **Stage E:**
  - panel tháp tràn sang cột thẻ tháp;
  - thiếu glyph "→" trong Be Vietnam Pro;
  - "Restart level" chưa được dịch.
- **Công cụ dev:** chụp ảnh từng ghi đè hồ sơ chơi thử trên desktop. Đã sửa bằng `tools/dev_sandbox.gd`.

## Chưa kiểm chứng (cần máy thật)

1. Cài đặt và chạy trên Android thật: chưa có thiết bị kết nối. Cách làm:
   - cắm điện thoại có bật gỡ lỗi USB rồi chạy `tools\install_apk.bat`;
   - hoặc gửi APK cho tester kèm `docs/PLAYTEST_GUIDE.md`, đã có checklist mới cho 0.8.0.
2. **Hiệu năng trên điện thoại** (FPS, nóng máy, pin): mới chỉ đo trên desktop.
3. Cảm giác chạm, độ dễ đọc trên màn hình nhỏ, độ to âm thanh trên loa điện thoại.
4. Cài đè lên 0.7.0 đang có trên máy: đã kiểm bằng versionCode, khoá và test save, nhưng chưa làm trên máy thật.

## Đánh giá theo tiêu chí nghiệm thu (prompt §17)

| # | Tiêu chí | Trạng thái |
|---|---|---|
| 1 | Menu chính như game thật | ✅ (Stage B) |
| 2 | Chọn màn hấp dẫn | ✅ |
| 3 | 3 bản đồ có bản sắc riêng | ✅ (Stage C) |
| 4 | 4 tháp có thiết kế cơ khí nhận ra được | ✅ (+ nhánh và tiến hoá đổi hình) |
| 5 | 10 quái có hình riêng | ✅ (Stage D) |
| 6 | Đạn/hiệu ứng rõ, đã mắt | ✅ |
| 7 | Tháp phản ứng khi bắn | ✅ |
| 8 | Quái phản ứng khi trúng/chết | ✅ |
| 9 | Boss có trình bày riêng | ✅ (3 pha, thanh máu, telegraph) |
| 10 | HUD đẹp, hợp mobile | ✅ desktop / ⏳ máy thật |
| 11 | Chuyển cảnh & hoạt ảnh UI | ✅ |
| 12 | Logic gameplay không đổi | ✅ golden 100% |
| 13 | Tiến trình & save tương thích | ✅ file 0.7.0 thật |
| 14 | Chơi offline | ✅ không quyền mạng |
| 15 | Hiệu năng hợp mobile | ⏳ chỉ có số desktop; cần đo trên máy |

**Về đồ hoạ (nói thẳng):** toàn bộ là vector SVG và hình vẽ bằng code tự làm cho dự án, không có công cụ tạo ảnh. Đã đạt mức "trông như game thật" theo đánh giá của tôi qua ảnh chụp, nhưng không phải artwork của hoạ sĩ chuyên nghiệp. Nếu sau này có hoạ sĩ, có thể thay từng file trong `assets/art/` mà không phải sửa code.
