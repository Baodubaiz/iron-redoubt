# Iron Redoubt — Hướng dẫn cài đặt & Playtest (v0.9.0-playtest · Khe Nứt)

Bản này là **game độc lập, chơi offline 100%**: không cần đăng nhập, không cần mạng, và không kết nối GameHub.
Tiến trình được lưu ngay trên máy.

## 1. Yêu cầu

- Điện thoại **Android 7.0 trở lên** (API 24+), CPU ARM (gần như mọi điện thoại hiện nay).
- Khoảng 150 MB bộ nhớ trống.
- Game chơi ở **màn hình ngang**.

## 2. Cài APK

File: `Iron Redoubt-0.9.0-playtest.apk` (~54 MB).

> **Từ 0.7.0 / 0.8.0 lên 0.9.0:** cài đè trực tiếp, tiến trình được giữ nguyên (cùng package `com.ironredoubt.game`, cùng khoá ký, versionCode 8 → 9). Ai đã qua màn 9 sẽ mở được màn 10 ngay.

### Cách A — gửi file trực tiếp (dành cho tester)

1. Nhận file `.apk` qua Google Drive, Zalo, Telegram hoặc email, rồi tải về điện thoại.
2. Mở file vừa tải (trong thông báo tải xuống hoặc ứng dụng **Files / Tệp**).
3. Nếu Android hỏi, cho phép **"Cài ứng dụng không rõ nguồn gốc"** cho ứng dụng bạn dùng để mở file (Chrome, Files, Zalo…), rồi quay lại và bấm **Cài đặt**.
4. Nếu **Google Play Protect** cảnh báo "ứng dụng không xác định", chọn **Chi tiết → Vẫn cài đặt**. Cảnh báo này xuất hiện vì bản playtest không phát hành qua Play Store.
5. Mở **Iron Redoubt** từ màn hình chính.

### Cách B — cài qua USB (dành cho dev)

1. Trên điện thoại, bật **Tùy chọn nhà phát triển → Gỡ lỗi USB**.
2. Cắm cáp vào máy tính và chấp nhận hộp thoại "Cho phép gỡ lỗi USB".
3. Trong thư mục dự án, chạy:

   ```bash
   tools\install_apk.bat
   ```

   Script sẽ cài đè và tự mở game.

### Cập nhật / gỡ

- **Bản mới hơn** (cùng khoá ký playtest) cài **đè lên** bản cũ, giữ nguyên tiến trình.
- **Gỡ ứng dụng** sẽ **xoá toàn bộ tiến trình**.

## 3. Lưu ý cho tester

- **Lưu tự động:** game lưu sau mỗi trận, sau mỗi lần mua research, và khi bạn chuyển ra ngoài ứng dụng.
- **Đóng giữa trận:** trận đó sẽ không được lưu. Tiến trình chiến dịch thì vẫn còn.
- **Nút Back** của Android:
  - Trong trận: tạm dừng / tiếp tục.
  - Ở các menu: quay về menu chính.
  - Ở menu chính: thoát game.
- **Chuyển app hoặc tắt màn hình:** trận tự tạm dừng. Khi quay lại, bấm **Resume**.
- **Daily / Weekly challenge** dùng giờ của điện thoại (UTC), nên đổi giờ máy sẽ làm lịch thay đổi. Đây là giới hạn đã biết của bản offline.
- **Báo lỗi:** ghi **số phiên bản** hiển thị ở cuối menu chính (ví dụ `v0.9.0-playtest`), kèm tên máy, phiên bản Android, các bước tái hiện, và ảnh hoặc video màn hình nếu có.

## 4. Checklist playtest cơ bản

Đánh dấu ✅ / ❌ và ghi chú cho từng mục.

**Cài đặt & khởi động**

- [ ] Cài được APK, icon hiển thị đúng ở màn hình chính.
- [ ] Mở game: màn hình ngang, không bị cắt hay đè bởi tai thỏ hoặc thanh điều hướng.
- [ ] Menu chính hiện số phiên bản; có nhạc nền.

**Điều khiển cảm ứng**

- [ ] **Kéo-thả** tháp từ cột bên phải ra bản đồ: hình xem trước nằm phía trên ngón tay, xanh = hợp lệ, đỏ + X = không hợp lệ.
- [ ] **Chạm để đặt:** chạm tháp → chạm bản đồ → chạm lại chỗ khác để đổi vị trí → **Build** / **Cancel**.
- [ ] Không thể đặt lên đường đi hoặc chồng lên tháp khác; tiền chỉ bị trừ khi xây thành công.
- [ ] Chạm tháp đã xây → panel hiện ra: nâng cấp nhánh, evolution, bán (bấm 2 lần để xác nhận). Panel không che mất tháp đang chọn.
- [ ] Các nút đủ lớn, dễ bấm; không có lần bấm nhầm khó chịu.

**Giao diện mới (0.8.0 — Reforged)**

- [ ] Menu chính: logo IRON REDOUBT, nền chiến trường động (tháp bắn drone) mượt, không giật; nút **CHƠI** vào đúng màn đang dở.
- [ ] Màn Chiến dịch: 4 tab vùng (Khe Nứt hiện lưới 10 màn), thẻ màn có ảnh bản đồ, màn trùm có viền đỏ + biểu tượng trùm; màn khoá/mở đúng; chữ tiếng Việt không bị cắt.
- [ ] Chuyển màn hình có hiệu ứng mờ dần, không nháy trắng.
- [ ] Trên chiến trường: phân biệt rõ **đường đi** và **ô xây được**; ô cấm là khối máy móc.
- [ ] Tháp: nòng xoay theo quái, giật khi bắn; nâng cấp nhánh khác nhau thì hình khác nhau; tiến hoá có hiệu ứng.
- [ ] Quái: nhận ra từng loại; Aegis có vòm khiên; Phantom mờ khi ẩn; quái bay lơ lửng; quái chết có mảnh vỡ.
- [ ] Boss Monolith: thanh máu ở đáy màn hình; thấy rõ vòng EMP sắp phát; 3 pha nhìn khác nhau.
- [ ] HUD: HP / tiền / wave / đếm ngược dễ đọc; thiếu tiền thì ô tiền rung đỏ; panel tháp có xem trước chỉ số khi nâng cấp.
- [ ] Màn Thắng / Thua có hiệu ứng, phần thưởng hiện lần lượt.
- [ ] Âm thanh mới: không quá to/chói khi nhiều tháp bắn cùng lúc.
- [ ] **Cài đặt → Giảm hiệu ứng**: bật lên thì không còn rung màn hình / chớp đỏ.
- [ ] Ghi lại: chỗ nào **khó đọc**, hiệu ứng nào **che mất quái/tháp**, máy nào bị **giật hoặc nóng**.

**Tính năng 0.7.0**

- [ ] Nút **x1/x2** trên thanh trên cùng đổi tốc độ; x2 nhanh gấp đôi, tạm dừng vẫn hoạt động.
- [ ] Mỗi tháp nâng được **2 nhánh**: 1 nhánh chính lên bậc 3 (+ tiến hoá) và 1 nhánh phụ tối đa bậc 2; nhánh thứ 3 bị khoá.
- [ ] **Cài đặt → Ngôn ngữ**: chuyển Tiếng Việt / English; mọi chữ (menu, tháp, nâng cấp, màn chơi, thành tựu) đổi theo, không bị cắt chữ.

**Gameplay**

- [ ] **40 màn, 40 bản đồ riêng**: 4 khu vực × 10 màn; trong một khu vực, các bản đồ giữ cơ chế của khu vực đó.
- [ ] **Mở khoá tháp khi vào màn có quái nó khắc chế** (có banner "Tháp mới"): bắt đầu chỉ có Xung Kích → Pháo Nổ (màn 2) → Thương Quang (màn 3) → Hải Đăng (màn 11) → Phun Độc (màn 13) → Bẫy Điện (màn 23) → Lá Chắn Điện Từ (màn 24) → Thiện Xạ (màn 31).
- [ ] 4 tháp mới hoạt động đúng: bẫy vàng trên đường làm chậm/giật; độc cộng dồn; Thiện Xạ bắn rất xa; tháp trong trường Lá Chắn không bị EMP/gây nhiễu.
- [ ] 7 quái mới nhận ra được và có kỹ năng rõ: Hộ Vệ, Bùn Lỏng, Bóng Đêm, Kẻ Tăng Tốc, Kẻ Gây Nhiễu, Lăng Trụ Nhỏ, Kẻ Lặn.
- [ ] Mạch Điện (1–10): **Màn 5: Cai Ngục** (cứng vỏ → lao nhanh). **Màn 10: Máy Phát** (tháp gần nó giảm tầm → đòn mạnh bị chặn ở 50 → quá tải chạy nhanh).
- [ ] Châu Thổ (11–20): đêm, 2 lối vào. **Màn 15: Mẫu Hạm** (phóng tiêm kích → tàng hình). **Màn 20: Thủy Quái** (lặn: không bắn trúng được → hồi sinh quái vừa chết → lặn nhiều hơn).
- [ ] Lăng Kính (21–30): cổng đổi đường. **Màn 25: Khúc Xạ** (phân thân mồi nhử → khiên kháng 1 loại sát thương, màu khiên cho biết loại). **Màn 30: Cự Thạch** (triệu hồi → EMP → vỡ mảnh).
- [ ] Khe Nứt (31–40): mọi cơ chế. **Màn 35: Biến Thể**. **Màn 40: Cự Thần** (khổng lồ).
- [ ] Trùm màn 10 của mỗi khu vực rõ ràng to và khó hơn trùm màn 5.
- [ ] Ai có save cũ: các màn đã qua vẫn chơi lại được; các màn mới chen vào giữa phải qua mới đi tiếp.
- [ ] Mỗi kỹ năng trùm đều có **báo trước** (vòng/vạch + chữ nhấp nháy trên thanh máu trùm) đủ lâu để phản ứng.
- [ ] "Start early" cộng thưởng; wave tự bắt đầu khi hết giờ đếm ngược.
- [ ] Ghi lại: level nào quá dễ / quá khó / không công bằng, và vì sao.

**Tiến trình & lưu**

- [ ] Thắng một level → mở level kế tiếp, nhận Cores; achievement và challenge cập nhật.
- [ ] Mua research → hiệu lực ở trận sau (ví dụ +tiền khởi đầu).
- [ ] **Vuốt tắt hẳn ứng dụng rồi mở lại** → tiến trình, research, achievement và cài đặt âm thanh còn nguyên.
- [ ] Bật **chế độ máy bay** → game vẫn chơi bình thường.

**Vòng đời ứng dụng**

- [ ] Đang chơi → bấm Home → mở lại: trận đang tạm dừng, bấm Resume chơi tiếp được.
- [ ] Có cuộc gọi đến hoặc tắt màn hình giữa trận → quay lại không bị crash.
- [ ] Nút Back hoạt động như mô tả ở mục 3.

**Âm thanh & cài đặt**

- [ ] Settings: tắt/bật nhạc và SFX, kéo âm lượng; mở lại game vẫn giữ.
- [ ] Nhiều tháp bắn cùng lúc không bị ồn chói.

**Hiệu năng**

- [ ] Wave đông (L8–L9, L15–L19, các trùm) vẫn mượt; ghi lại tên máy nếu bị giật.
- [ ] Máy có nóng hoặc hao pin bất thường không (chơi ~15 phút).

## 5. Thông tin cho dev

- **Build lại APK:**

  ```bash
  powershell -ExecutionPolicy Bypass -File tools\build_android.ps1
  ```

- **Khoá ký playtest:** `C:\code\android-keystores\`.
  - **Không** commit thư mục này, và **không** chia sẻ file credentials.
  - Mất khoá này nghĩa là tester phải gỡ app (mất tiến trình) để cài bản ký bằng khoá mới.
- **File lưu trên máy:** `user://profile.json` và `user://settings.cfg` (thư mục dữ liệu riêng của app).
