# Iron Redoubt — 8 tháp, 16 quái, mở khoá theo quái khắc chế

Ngày: 2026-11-13.

## Tháp: 4 → 8 (chỉ hạng C, B, A cho bản phát hành đầu)

| Tháp | Hạng | Loại | Chức năng | Mở khoá |
|---|---|---|---|---|
| Xung Kích | C | Sát thương | bắn nhanh, bắn được trên không | có sẵn |
| **Bẫy Điện** *(mới)* | C | Khống chế | ném bẫy xuống đường: quái đứng trên bẫy bị chậm 45% và bị giật điện; chỉ trúng quái mặt đất | màn 23 |
| Pháo Nổ | B | Sát thương | sát thương lan | màn 2 |
| Hải Đăng | B | Hỗ trợ | làm chậm, làm lộ quái tàng hình, buff, kinh tế | màn 11 |
| **Phun Độc** *(mới)* | B | Sát thương | độc cộng dồn 4 tầng, bỏ qua giáp | màn 13 |
| Thương Quang | A | Sát thương | xuyên giáp, ×2 vào khiên | màn 3 |
| **Thiện Xạ** *(mới)* | A | Sát thương | tầm 330, bắn chậm nhưng mạnh, ×1,2 lên trùm | màn 31 |
| **Lá Chắn Điện Từ** *(mới)* | A | Phòng thủ | không bắn; tháp trong trường miễn nhiễm EMP, gây nhiễu, tĩnh điện và hiệu ứng làm yếu | màn 24 |

Mỗi tháp mới có 3 nhánh × 3 bậc + tiến hoá. Ví dụ Bẫy Điện có các nhánh Bẫy Chân, Dây Điện và Bãi Mìn; tiến hoá của Bẫy Chân là Lưới Đóng Băng, giữ quái đứng yên (trùm chỉ bị chậm).

**Luật sức mạnh theo hạng** được kiểm bằng test tự động: tháp mới không bao giờ có sát thương/giây trên mỗi đồng cao hơn tháp mạnh nhất cùng hạng, ở mọi bậc.
- C ≤ Xung Kích, B ≤ Pháo Nổ/Hải Đăng, A ≤ Thương Quang.
- Test đã bắt được Phun Độc vượt trần hạng B ngay lần đầu; đã hạ chỉ số.
- Trần sức mạnh phía trên được để dành cho hạng S/SS sau này.

## Quái thường: 9 → 16 (trùm giữ 8)

| Quái mới | Kỹ năng | Xuất hiện từ màn | Khắc chế |
|---|---|---|---|
| Hộ Vệ | bọc khiên tạm cho quái xung quanh | 6 | hạ nó trước |
| Bùn Lỏng | tự hồi 3,5% máu mỗi giây | 13 | Phun Độc, dồn sát thương |
| Bóng Đêm | bay + tàng hình | 17 | Hải Đăng + tháp bắn trên không |
| Kẻ Tăng Tốc | cứ 5 giây lao nhanh ×2 | 23 | Bẫy Điện, làm chậm |
| Kẻ Gây Nhiễu | làm tháp gần nó nạp đạn chậm | 24 | Lá Chắn Điện Từ, bắn từ xa |
| Lăng Trụ Nhỏ | kháng lần lượt từng loại sát thương | 27 | trộn nhiều loại tháp |
| Kẻ Lặn | lặn xuống, miễn sát thương 1,5 giây | 31 | Thiện Xạ, dồn sát thương khi nó nổi |

Kỹ năng của quái mới dùng lại engine kỹ năng trùm, ở mức nhẹ hơn; không thêm loại hiệu ứng nào. Sau màn xuất hiện lần đầu, quái mới có mặt ở các màn sau trong cùng khu vực và trong Khe Nứt.

## Mở khoá tháp

- Tháp được nhận **khi vào lần đầu màn có quái mà nó khắc chế**. Màn hình hiện banner "Tháp mới: X" kèm mô tả.
- Mỗi khu vực mở tối đa 2 tháp: Mạch Điện 2, Châu Thổ 2, Lăng Kính 2, Khe Nứt 1.
- Người chơi mới chỉ có Xung Kích.
- Save cũ: tháp đã có thì vẫn giữ.

## Thay đổi gameplay (nói rõ)

- **Màn 1** chỉ còn Xung Kích; trước đây có cả Pháo Nổ. Bot vẫn thắng không mất máu.
- **Màn 6–10** không còn Hải Đăng, vì giờ nó mở ở màn 11; các màn này không có Phantom.
- Wave của các màn sinh tự động được bổ sung quái mới.
- Đã chỉnh vài màn sau mô phỏng:
  - **Màn 13:** ít Phantom hơn, mật độ quái thấp hơn.
  - **Màn 26:** đường bay của quái bay đi qua giữa bản đồ, không còn sát đáy.
- Golden (80 trận) đã được ghi lại vì gameplay thay đổi có chủ đích.

## Bot và giới hạn

- Bot mô phỏng **chưa biết dùng 4 tháp mới**; nó chỉ xây 4 tháp cũ. Vì vậy cân bằng hiện tại là "thắng được ngay cả khi không dùng tháp mới". Người chơi có tháp mới sẽ thấy dễ hơn bot.
- Vài màn khá dễ với bot, ví dụ màn 10 Máy Phát thắng không mất máu. Nên chỉnh tiếp sau khi có người thật chơi thử.
- Hình vẽ tháp mới gồm thân tháp, icon, các khối giáp theo bậc và hiệu ứng tiến hoá dùng chung. Chưa có chi tiết hình riêng cho từng nhánh như 4 tháp cũ.

## Đợt độ khó: thắng sát nút

Mục tiêu: chiến thuật tốt nhất của bot (chỉ dùng 4 tháp cũ, hạng C/B/A) **thắng nhưng chỉ còn 10–30% máu căn cứ**; màn trùm còn 8–25%.

**Công cụ:** `tools/sim/difficulty_tuner.gd`.
- Mỗi màn có một hệ số độ khó **d**, tăng đồng thời 3 thứ:
  - số quái ×d^0,6;
  - máu quái ×d^0,4;
  - máu trùm ×d^0,5.
- Công cụ tăng dần rồi chia đôi khoảng để tìm d.
- Bảng hệ số nằm ở `DIFFICULTY` trong `tools/author_data.gd`. Muốn chỉnh tay chỉ cần sửa số ở đó.

**Kết quả** (bot chơi trọn 40 màn, máu còn lại):
- Phần lớn các màn còn khoảng **10–30% máu**, nhiều màn chỉ còn 2–4 máu.
  - Ví dụ: màn 10 Máy Phát còn 2/25, màn 30 Cự Thạch còn 3/33.
- **Ngoại lệ:**
  - **Màn 1** là màn hướng dẫn chỉ có Xung Kích, giữ ở mức dễ (hệ số ×3, bot vẫn không mất máu).
  - **Màn 34** còn 14/28.
  - **Màn 40 (Cự Thần)** còn 23/33. Tăng thêm thì bot thua hẳn, vì độ khó phụ thuộc vào chính trùm, nên giữ nguyên.
- Người chơi có đủ 8 tháp (bot không dùng 4 tháp mới) sẽ có thêm một chút khoảng thở.
- Tháp hạng S (sau này) sẽ khiến các màn này dễ thở hơn hẳn.

**Lưu ý thật:**
- Độ khó được dò với **một hạt giống ngẫu nhiên** và với **bot**, nên có thể nhạy: người chơi đặt tháp khác sẽ có kết quả khác.
- Cần người thật chơi thử để chỉnh tiếp.
