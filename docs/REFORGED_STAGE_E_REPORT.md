# Iron Redoubt Reforged — Stage E: HUD, âm thanh & hoàn thiện

Ngày: 2026-11-12 · Trạng thái: **xong, chờ duyệt trước Stage F**.
Ảnh chụp: `docs/reforged_stage_e/`. Có 4 tỉ lệ màn hình (16:9, 19.5:9, 20:9 có tai thỏ giả lập, 4:3), cả 2 ngôn ngữ, và các màn `*_results_*`, `*_pause_menu`, `*_toasts_banner`.

## HUD trong trận (`ui/hud/hud.gd`, viết lại)

**Thanh trên:**
- **HP căn cứ:** icon tim + thanh màu (xanh → cam → đỏ), nháy đỏ khi mất máu.
- **Tiền:** icon + số **đếm lên/xuống mượt**.
- **Wave:** dạng "WAVE 5/12".
- **Trạng thái bản đồ:**
  - Châu Thổ hiện ☀ Ngày / ☾ Đêm, kèm báo trước "Ngày → Đêm".
  - Lăng Kính hiện cổng đang mở, kèm báo trước "Bắc → Nam" bằng màu cam.
- **Bên phải:**
  - **đếm ngược 0:12** giữa các wave, hoặc **số quái còn lại** khi đang đánh;
  - nút **BẮT ĐẦU / GỌI SỚM +thưởng**;
  - nút **x1/x2** (chuyển cam khi x2);
  - nút **tạm dừng**.

**Thẻ tháp (cột phải):**
- Mỗi thẻ có hình tháp thật, tên theo màu tháp và giá kèm icon tiền.
- Thiếu tiền: thẻ mờ, giá chuyển **đỏ**. Đang chọn: thẻ viền sáng.
- Tên dài (ví dụ "Thương Quang") vẫn vừa thẻ.

**Phản hồi:**

| Sự kiện | Phản hồi |
|---|---|
| Thiếu tiền | Ô tiền **rung + nháy đỏ**, thông báo "Không đủ tiền", âm lỗi |
| Đặt sai chỗ | Thông báo cam (lý do thật từ `PlacementRules`), âm lỗi; bóng xem trước vẫn có X |
| Xây / nâng cấp / tiến hoá / bán | **Số bay lên** tại tháp (-100, T2, "Đã tiến hoá", +70). Bán thì có thêm thông báo |
| Wave bắt đầu / dọn xong | **Banner lớn** phóng to rồi mờ dần ("WAVE 5" kèm +thưởng gọi sớm; "ĐÃ DỌN WAVE 1 +40") |
| Boss xuất hiện | Banner đỏ, chớp đỏ nhẹ, rung nhẹ |
| Boss đổi pha | Thông báo đỏ |
| EMP | Chớp đỏ nhẹ, rung nhẹ |
| Synergy | Chip xanh ở góc dưới trái |

Thông báo hiện tối đa 3 cái cùng lúc, cái cũ tự biến mất.

**Các màn phủ:**
- **Tạm dừng:** panel nảy vào; nút có icon Tiếp tục / Cài đặt / Chơi lại màn / Thoát.
- **Kết quả:**
  - tiêu đề CHIẾN THẮNG / THẤT BẠI có hiệu ứng nảy;
  - nền tia sáng xanh xoay khi thắng, viền đỏ khi thua;
  - 4 chỉ số có icon **đếm lên** (HP, wave, số quái hạ, thời gian);
  - phần thưởng hiện **lần lượt** thành từng chip có icon (+Lõi, lần đầu, không mất máu, tháp mới, màn mới, thử thách, thành tựu);
  - nút **Màn tiếp theo** nổi bật.
- Sửa lỗi cũ: nút "Restart level" trước đây không được dịch; giờ là "Chơi lại màn".

## Panel quản lý tháp (`ui/hud/tower_panel.gd`, viết lại)

- **Chân dung tháp động**, dùng đúng hình của tháp đang chọn: thấy nhánh, tiến hoá, nòng xoay.
- Tên + nhánh chính/phụ.
- **Chỉ số có icon:** sát thương ⚡, tốc bắn ⏱, tầm ◎, kèm dòng phụ (xuyên giáp, lan, quái bay, buff, bị EMP, đã đầu tư).
- **3 thẻ nhánh:**
  - pip hình thoi (đã mua / còn mua được / vượt giới hạn);
  - mô tả bậc tiếp theo, hoặc **lý do bị khoá**;
  - **xem trước thay đổi chỉ số**, ví dụ "Sát thương 12 → 20  Xuyên giáp 0 → 2". Phần này tính trên một tháp tạm rồi huỷ ngay, không đụng vào trận;
  - nút mua có giá, chữ đỏ nếu chưa đủ tiền;
  - nhánh chính có viền màu tháp.
- **Thẻ tiến hoá** viền cam.
- Nút **Bán +hoàn tiền**: chạm lần đầu chuyển đỏ "Xác nhận", chạm lần 2 thì bán.
- Luật nhánh chính/phụ **không đổi** (vẫn đọc `UpgradeRules`).
- Sửa lỗi phát hiện khi chụp ảnh: panel bị tràn sang cột thẻ tháp (rộng tối thiểu 1276px). Giờ chữ dài trong nút tự cắt "…", panel rộng 1134px, vừa cả tiếng Việt.

## Âm thanh (`tools/audio_gen/gen_audio.gd`)

- **Bộ SFX sci-fi mới:**
  - thêm **tổng hợp FM** cho tiếng kim loại/chuông;
  - 15 âm cũ được làm lại;
  - **5 âm mới:** nổ (`explosion`), trúng khiên (`shield_hit`), lỗi UI (`ui_error`), dọn xong wave (`wave_clear`), boss đổi pha (`boss_phase`).
- Vẫn **100% tự tổng hợp bằng code**, không dùng mẫu âm ngoài (`audio/LICENSES.md` đã cập nhật).
- Không file nào bị cắt đỉnh (đỉnh cao nhất 0.68).
- Âm lượng từng loại được cân lại (`GAIN`), đạn bắn nhỏ hơn. Vẫn có bộ giới hạn âm trùng và biến thiên cao độ.
- Cài đặt nhạc/SFX giữ nguyên. Nhạc nền giữ nguyên.

## Tuỳ chọn "Giảm hiệu ứng" + rung màn hình

- Settings có thêm **Giảm hiệu ứng**, lưu trong `settings.cfg`. File cũ 0.7.0 không có khoá này thì mặc định tắt.
- **Rung màn hình** rất nhẹ (≤ 6px, ≤ 0.5s), chỉ khi:
  - boss xuất hiện;
  - EMP;
  - boss chết;
  - quái lọt vào căn cứ (2px).
- Khi bật "Giảm hiệu ứng": **tắt rung và chớp**, giảm một nửa mảnh vỡ, giảm tia lửa khi trúng, bỏ cột sáng lúc tiến hoá.

## Kiểm chứng (kết quả thật)

- **Test suite:** `131 passed, 0 failed (237.0s)`, gồm **golden 18 trận khớp 100%**. Không có `SCRIPT ERROR`.
- **Test mới** `tests/unit/test_hud.gd` (3 test):
  - "Giảm hiệu ứng" lưu/đọc được, file cũ thì mặc định tắt;
  - xem trước nâng cấp có thay đổi chỉ số nhưng **không đổi tháp thật**;
  - HUD có đủ thẻ tháp, nút bắt đầu, và Back mở/đóng menu tạm dừng.
- `extract_keys.py`: 393 key, 0 thiếu (thêm 14 chuỗi tiếng Việt).
- Đã kiểm tra font: Be Vietnam Pro **thiếu ký tự "→"**, nên dòng xem trước dùng Chakra Petch.
- **Đo trên desktop** (L8 stress, 51 quái, x2): trung bình 7.0 ms/khung. **Không đại diện cho điện thoại.**
- **Công cụ chụp ảnh không còn ghi vào hồ sơ thật:**
  - thêm `tools/dev_sandbox.gd` để các tool dùng bộ nhớ tạm;
  - đã kiểm tra `profile.json` không đổi thời gian sửa sau khi chạy.

  Trước bản sửa này, các tool chụp ảnh (từ Phase 4–5 đến Stage D) **có ghi đè hồ sơ chơi thử trên desktop của dự án** (`%APPDATA%\Godot\app_userdata\Iron Redoubt\profile.json`). Chỉ máy tính này bị ảnh hưởng, không phải điện thoại.

## Giới hạn / chưa làm

- Ảnh "thông báo + banner" được dàn dựng: tôi gọi trực tiếp thông báo và banner để chụp cùng lúc.
- Nhạc nền chưa làm bản "combat" riêng (Stage A ghi là tuỳ chọn).
- Chưa thử trên điện thoại thật: cảm giác chạm, độ to âm thanh trên loa điện thoại, hiệu năng.
- Phiên bản vẫn 0.7.0. Bản 0.8.0 + APK là Stage F.
