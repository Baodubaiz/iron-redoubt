# Iron Redoubt — Cập nhật nội dung: bản đồ riêng từng màn, khu vực Khe Nứt, 5 trùm

Ngày: 2026-11-13 · Trạng thái: **xong trên desktop**, APK `build/Iron Redoubt-0.9.0-playtest.apk` đã build + ký + kiểm tra (versionCode 9, cài đè lên 0.8.0). Chưa cài lên điện thoại thật.

## Đã làm

### 1. Mỗi màn một bản đồ riêng (19 bản đồ)

Trước đây 3 màn của một khu vực dùng chung 1 bản đồ. Giờ mỗi màn có bản đồ riêng, nhưng vẫn giữ cơ chế của khu vực:

| Khu vực | Màn | Bản đồ | Cơ chế |
|---|---|---|---|
| Mạch Điện | 1 / 2 / 3 | gốc / Sảnh Tua-bin / Xoắn Lõi | 1 đường + nút quá tải |
| Châu Thổ | 4 / 5 / 6 | gốc / Cửa Xả / Cảng Đêm | 2 lối vào nhập làm một + ngày/đêm |
| Lăng Kính | 7 / 8 / 9 | gốc / Sảnh Đôi / Lõi Gương | cổng đổi đường |
| **Khe Nứt (mới)** | 10–19 | 10 bản đồ mới | trộn mọi cơ chế (xem dưới) |

L1, L4, L7 giữ bản đồ cũ. Hình nền và khối máy móc theo màu khu vực; mỗi bản đồ có chi tiết sàn riêng.

### 2. Khu vực mới: Khe Nứt (10 màn)

Màu cam/đỏ, nền sàn nứt phát sáng, khối cấm là "lò tinh thể nứt".

| Màn | Tên | Cơ chế bản đồ | Trùm |
|---|---|---|---|
| 10 | Khe Nứt Mở Ra | 1 đường, nút quá tải | |
| 11 | Đứt Gãy Kép | 2 lối vào, đêm | |
| 12 | Đường Đứt Gãy | cổng (đường dài/ngắn), nút quá tải | |
| 13 | Xoắn Ốc Tối | xoắn dài, đêm, nút quá tải | |
| **14** | **Biến Thể** | 2 lối vào, nút quá tải | **Biến Thể** |
| 15 | Ba Cổng | **3 cổng**, đêm | |
| 16 | Gọng Kìm | 2 lối vào bắc/nam, nút quá tải | |
| 17 | Lối Tắt | cổng mở lối tắt, nút quá tải | |
| 18 | Nhật Thực | 2 lối vào, đêm, nút quá tải | |
| **19** | **Cự Thần** | đường rất dài, đêm, nút quá tải | **Cự Thần (khổng lồ)** |

Wave của Khe Nứt được sinh lúc soạn dữ liệu, dữ liệu xuất ra là cố định:
- mỗi màn có "chủ đề" quái riêng (L11 nhiều Phantom, L12 nhiều quái bay, L16 nhiều Brute...);
- 3 wave đầu chỉ có quái cơ bản, sau đó số lượng và máu tăng dần;
- cứ 6 wave có 1 wave đặc biệt; đêm và đổi cổng theo cơ chế của bản đồ.

### 3. Năm trùm, không con nào giống con nào

| Trùm | Màn | Pha | Kỹ năng |
|---|---|---|---|
| **Cai Ngục** | 3 | 2 | I: *Cứng vỏ* — khiên tạm = 15% máu trong 5 giây. II: thêm *Ép xung* — chạy ×1,8 trong 2,5 giây |
| **Mẫu Hạm** | 6 | 2 | I: *Phóng tiêm kích* — 3 quái bay từ boong (không có tiền thưởng). II: thêm *Trường tàng hình* — nó và hộ tống trong 120px tàng hình 4 giây; Hải Đăng / Sensor làm lộ, sát thương lan vẫn trúng |
| Cự Thạch | 9 | 3 | giữ nguyên: triệu hồi → EMP → vỡ mảnh |
| **Biến Thể** | 14 | 3 | I: *Đổi giáp* — luân phiên +8 giáp ↔ khiên hồi phục (12% máu, sát thương năng lượng ×2). II: thêm *Gây nhiễu* — tháp trong 190px nạp đạn chậm một nửa trong 4 giây. III: đổi giáp nhanh gấp đôi |
| **Cự Thần** | 19 | 3 | Khổng lồ (bán kính 44, 32.000 HP, giáp 8, lọt vào là thua). I: *Tường khiên* — bọc khiên 150 cho mọi đồng minh trong 220px. II: thêm *Nhảy khe nứt* — dịch chuyển 160px về phía trước (không bao giờ vào gần căn cứ hơn 260px). III: *Quá tải* — hộ tống trong 180px chạy nhanh +30%, nó tự hồi 0,3% máu/giây |

Mọi kỹ năng đều có báo trước:
- hình báo trên chiến trường dùng đúng bán kính và khoảng cách thật: vòng gây nhiễu, vòng tàng hình, vạch chỉ điểm đáp khi nhảy...;
- chữ nhấp nháy trên thanh máu trùm ("Đang gây nhiễu tháp!"...);
- mỗi lần đổi pha có thông báo riêng cho từng trùm.

Mỗi trùm có hình SVG riêng. Hình trùm được import ở độ phân giải ×3 cho nét khi phóng to.

### 4. Giao diện chiến dịch

- 4 tab khu vực.
- Khu vực có hơn 3 màn (Khe Nứt) hiện **lưới 5×2** thẻ gọn.
- Màn có trùm: **viền đỏ + icon trùm**. Thanh chi tiết có chip tên trùm.

## Đổi so với trước (nói rõ)

- **Gameplay của L2, L3, L5, L6, L8, L9 đã đổi** vì có bản đồ mới. Đây là thay đổi có chủ đích, khác với đợt Reforged (đợt đó không được đổi gameplay).
- **L3 có thêm trùm** Cai Ngục ở wave 12, thay cho wave đặc biệt cuối.
- **L6 đổi trùm**: Mẫu Hạm thay cho Cự Thạch bản yếu, nên chỉ còn L9 có Cự Thạch.
- Số quái mỗi wave của L5, L6, L9 được giảm nhẹ: hệ số 0,7 → 0,55, 0,65 → 0,58, 0,55 → 0,5. Máu Cự Thạch ở L9 giảm từ 50% xuống 42%. Mục đích là giữ độ khó gần với trước, vì bản đồ mới khó phòng thủ hơn.
- Chỉ số cuối của trùm: Cai Ngục 2.400 HP, Mẫu Hạm 4.400 HP, Biến Thể 8.500 HP, Cự Thần 17.000 HP / tốc độ 20 (lớn nhất và trâu nhất game; Cự Thạch gốc 12.000 HP, ở L9 xuất hiện với 42%).
- Thành tựu "Kẻ Phá Cự Thạch" giờ tính cho **mọi trùm** hạ trong 90 giây; mô tả đã sửa theo.
- Thêm thành tựu "Phong Ấn Khe Nứt" (qua màn 19, +30 Lõi).
- **Save cũ vẫn dùng được**: id màn không đổi. Ai đã qua L9 sẽ mở được L10 ngay.
- **L1, L4, L7 không đổi một chút nào**: đã chạy lại bản ghi golden của 3 màn này (6 trận) sau khi thêm code trùm, khớp 100%.

## Kiểm chứng (kết quả thật)

| Hạng mục | Kết quả |
|---|---|
| Toàn bộ test | 139 qua + 1 test trùm cần nới thời gian chờ (đã sửa, chạy lại 7/7 qua), tức **140/140** |
| Test mới `test_bosses.gd` (7) | trùm không trùng bộ kỹ năng; Cai Ngục cứng vỏ / lao nhanh; Mẫu Hạm phóng tiêm kích / tàng hình (Hải Đăng làm lộ, sát thương lan vẫn trúng); Biến Thể đổi giáp / gây nhiễu (tháp bị nhiễu bắn đúng nửa tốc độ); Cự Thần bọc khiên / nhảy (không nhảy sát căn cứ) / quá tải; trùm mới không vỡ mảnh |
| Test hình học bản đồ (mới) | 19 bản đồ: mọi đường kết thúc ở căn cứ; nút quá tải và khối cấm không đè lên đường; đủ chỗ xây (≥120 ô) |
| Dữ liệu chiến dịch | 19 màn, mỗi màn 1 bản đồ riêng; khu vực 3/3/3/10; trùm ở L3, 6, 9, 14, 19, luôn là wave cuối; 5 bộ kỹ năng khác nhau |
| Chơi trọn bằng bot | **19/19 màn thắng.** L1–9 không có nghiên cứu; L10–19 có đủ nghiên cứu |
| Golden | ghi lại cho 19 màn (38 trận). **L1/L4/L7 khớp 100%** với bản ghi 0.8.0, chứng tỏ code trùm, khiên tạm và gây nhiễu không làm đổi gameplay cũ |
| Bản dịch | 449 key, 0 thiếu (thêm 63 chuỗi tiếng Việt) |
| Bố cục | màn Chiến dịch tab Khe Nứt chụp ở 16:9, 4:3, 20:9: lưới 5×2 vừa khít, chữ Việt không bị cắt |
| Hiệu năng (desktop, tắt vsync, 50 quái thêm) | L19 ≈ 12,0 ms/khung, ngang L1 (≈ 12,2 ms) đo cùng lúc. Con số tuyệt đối cao hơn lần đo trước (7 ms) vì máy đang ở trạng thái khác; so tương đối mới có ý nghĩa. **Không đại diện cho điện thoại** |

**Độ khó theo mô phỏng** (bot, 3 chiến thuật; "thắng x/3" kèm máu còn lại của chiến thuật trong test):

| Màn | Kết quả | Màn | Kết quả |
|---|---|---|---|
| 1–3 | 3/3 thắng, đủ máu | 10 | 3/3, đủ máu |
| 4 | 2/3 (giữ nguyên) | 11 | 3/3 |
| 5 | 1/3 (heavy 14/20) | 12 | 2/3 |
| 6 (Mẫu Hạm) | 3/3 nhưng sát nút (2–4 máu) | 13 | 3/3, gần như không mất máu (màn "thở" trước trùm) |
| 7 | 3/3 (giữ nguyên) | 14 (Biến Thể) | 3/3, còn 16–18/28 |
| 8 | 3/3 | 15 | 3/3 sát nút (6–12/28) |
| 9 (Cự Thạch) | 1/3 (heavy 8/30) | 16–18 | 3/3, áp lực vừa |
| | | **19 (Cự Thần)** | **1/3** (balanced 25/33; 2 chiến thuật còn lại để Cự Thần lọt khi nó còn ~20% máu) |

Bot là bằng chứng màn có thể thắng được, **không phải đánh giá độ vui**. Người chơi thật xếp tháp theo cổng/lối vào tốt hơn bot nên có thể thấy dễ hơn. Ngược lại, người chưa mua nghiên cứu khi vào Khe Nứt sẽ thấy khó hơn: đến hết L9 kiếm được khoảng 205 Lõi + thành tựu, trong khi toàn bộ nghiên cứu cần 285.

## Chưa làm / giới hạn

- Chưa thử trên điện thoại (không có máy nào kết nối khi build).
- Chưa có người thật chơi thử khu Khe Nứt và các trùm mới. Độ khó mới chỉ dựa trên mô phỏng.
- Wave của Khe Nứt do bộ sinh tạo theo chủ đề, chưa được tinh chỉnh tay từng wave như L1–9.
- Chưa có nhạc riêng cho trùm; trùm mới dùng âm thanh trùm và âm đổi pha sẵn có.
- Ảnh trùm trong `docs/content_update/boss_*.png` được dàn dựng: trùm được đặt sẵn giữa lúc báo kỹ năng để chụp.

Ảnh: `docs/content_update/` gồm 19 bản đồ, bảng tổng hợp `vi_maps_sheet.png`, màn chiến dịch và 5 trùm.
