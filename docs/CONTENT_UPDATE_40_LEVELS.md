# Iron Redoubt — 40 màn: mỗi khu vực 10 màn, trùm ở màn 5 và màn 10

Ngày: 2026-11-13. Đây là phần tiếp theo của [CONTENT_UPDATE_RIFT.md](CONTENT_UPDATE_RIFT.md).

## Chiến dịch mới

4 khu vực × 10 màn = **40 màn, 40 bản đồ khác nhau**. Màn 5 và màn 10 của mỗi khu vực có trùm. Trùm màn 10 luôn to hơn, trâu hơn và có nhiều pha hơn (hoặc bằng) trùm màn 5 cùng khu vực.

| Khu vực | Màn | Trùm màn 5 | Trùm màn 10 |
|---|---|---|---|
| Mạch Điện | 1–10 | Cai Ngục (2.400 HP, 2 pha) | **Máy Phát** (4.200 HP, 3 pha) — mới |
| Châu Thổ | 11–20 | Mẫu Hạm (4.400 HP, 2 pha) | **Thủy Quái** (4.800 HP, giáp 4, 3 pha) — mới |
| Lăng Kính | 21–30 | **Khúc Xạ** (3.600 HP, 2 pha) — mới | Cự Thạch (3 pha, vỡ mảnh) |
| Khe Nứt | 31–40 | Biến Thể (8.500 HP, 3 pha) | Cự Thần (17.000 HP, khổng lồ, 3 pha) |

**8 trùm, 8 bộ kỹ năng khác nhau.** Ba trùm mới:
- **Máy Phát:**
  - I: *Trường tĩnh điện* — tháp trong 200px mất 35% tầm bắn trong 5 giây.
  - II: thêm *Tụ điện* — mỗi đòn trúng nó tối đa 50 sát thương trong 4 giây. Phạt các đòn Lance cực mạnh; tháp bắn nhanh vẫn hiệu quả.
  - III: *Quá tải* — chạy nhanh hơn 35% đến hết trận.
- **Thủy Quái:**
  - I: *Lặn* — 2,5 giây không thể bị nhắm và **miễn mọi sát thương**, kể cả sát thương lan; vẫn tiếp tục di chuyển.
  - II: thêm *Hồi sinh* — 3 quái vừa chết gần nó (trong 12 giây gần nhất) sống lại, không cho tiền thưởng.
  - III: lặn thường gấp đôi.
- **Khúc Xạ:**
  - I: *Phân thân* — 2 bản sao mồi nhử chạy lên trước. Chúng yếu (5% máu), chỉ trừ 1 máu căn cứ, không cho tiền.
  - II: thêm *Khiên lăng kính* — kháng 90% một loại sát thương trong 4 giây, xoay vòng vật lý → nổ → năng lượng; màu khiên cho biết loại đang bị kháng.

Kỹ năng nào cũng có báo trước: vòng tĩnh điện, vòng nạp tụ, gợn nước khi lặn, vòng hồi sinh, tia tách sáng. Chữ cảnh báo hiện trên thanh máu trùm, kèm thông báo khi đổi pha.

**21 bản đồ mới** (7 mỗi khu vực cũ):
- Mạch Điện: 1 đường + nút quá tải. Có đường zíc-zắc chéo, đường tự cắt qua chính nó, cầu thang, vòng quanh lò...
- Châu Thổ: 2 lối vào nhập làm một + đêm. Có lối vào chéo, lối từ trên/dưới/hai bên, cầu chéo, đường cắt ngang lối vào...
- Lăng Kính: cổng. Đảo lục giác, chuỗi kim cương, vòng có lối tắt, xoắn ốc...

## Thứ tự màn và save cũ

Id màn cũ được giữ nguyên, chỉ đổi vị trí:
- Mạch Điện: màn 1, 2 = cũ; màn 5 = màn 3 cũ (Cai Ngục).
- Châu Thổ: màn 11, 12 = cũ; màn 15 = màn 6 cũ (Mẫu Hạm).
- Lăng Kính: màn 21, 22 = cũ; màn 30 = màn 9 cũ (Cự Thạch).
- Khe Nứt: màn 31–40 = màn 10–19 cũ.

Lance mở sau màn 2, Beacon mở sau màn 5.

**Luật mở khoá mới:** màn đã qua thì luôn chơi lại được. Người chơi bản cũ giữ mọi màn đã qua. Để đi tiếp, họ cần qua các màn mới chen vào giữa, ví dụ ai đã qua màn 1–9 cũ sẽ chơi tiếp từ Mạch Điện 3.

Các mô tả có số màn (thử thách, thành tựu) được tự đổi theo vị trí mới, ví dụ "Qua màn 9" thành "Qua màn 30".

## Cân bằng (mô phỏng bằng bot)

- Mạch Điện và Châu Thổ (1–20): bot **không có nghiên cứu**, như các màn gốc.
- Lăng Kính và Khe Nứt (21–40): bot có đủ nghiên cứu. Lý do: đến hết màn 20, Lõi từ lần qua đầu tiên đã khoảng 380, nhiều hơn 285 Lõi cần để mua toàn bộ nghiên cứu.
- Mỗi màn đều có ít nhất một chiến thuật bot thắng.
- Wave của 21 màn mới sinh theo chủ đề từng màn. Quá trình chỉnh:
  - Mạch Điện chỉ có quái cơ bản (bỏ Phantom/Y Sĩ khỏi khu này).
  - Mật độ quái được dò cho từng màn bằng công cụ thử hệ số.
  - Ba bản đồ Lăng Kính có nhánh tắt quá ngắn (thua ngay lúc đổi cổng) được vẽ lại: hai nhánh dài tương đương quanh một đảo giữa.
- Một số màn khá căng với bot (còn 4–6 máu): Mạch Điện 9 và 10, Châu Thổ 13, 14 và 20. Màn 35 thì dễ.

## Chưa làm / giới hạn

- Độ khó mới chỉ dựa vào bot; chưa có người thật chơi thử 21 màn mới và 3 trùm mới.
- Trên điện thoại chưa thử.
- Chưa có nhạc riêng cho trùm mới.
