# Iron Redoubt Reforged — Stage D: Quái, đạn & boss

Ngày: 2026-11-12 · Trạng thái: **xong, chờ duyệt trước Stage E**.
Ảnh chụp: `docs/reforged_stage_d/`.

## Gameplay không đổi

- **Golden test 18 trận khớp 100%** sau Stage D (nằm trong lần chạy test suite bên dưới).
- Thay đổi trong script gameplay (chỉ phục vụ trình bày, có ghi chú trong code):
  - `enemy.gd`: bỏ `_draw()`, thêm getter chỉ-đọc `hit_flash()`.
  - `projectile_system.gd`:
    - viết lại phần **vẽ**;
    - thêm 3 trường chỉ để hiển thị cho mỗi viên đạn (`origin`, `tower_id`, `branch_id`);
    - thời lượng hiệu ứng nổ/vỡ dài hơn (chỉ ảnh hưởng hình);
    - giới hạn pool hiệu ứng 220 phần tử: đầy thì tái dùng hiệu ứng cũ nhất.

    Logic bay/trúng (`spawn`, `step`, `impact_callback`) **không đổi**.
  - `hud.gd`: ẩn thanh máu boss cũ, vì bị trùng với thanh mới (1 dòng).
- Không có quái mới, không có kỹ năng mới.

## Quái (`gameplay/visuals/enemy_visual.gd`, SVG trong `assets/art/enemies/`)

**Chung cho mọi loại:**
- Thân máy kim loại tối, lõi/mắt đỏ, **quay theo hướng đi**.
- Kích thước hiển thị ~1.3× bán kính va chạm. **Va chạm không đổi.**
- Bóng đổ dưới thân.

| Quái | Hình & hoạt ảnh (theo cơ chế thật) |
|---|---|
| Swarmling | Nhện máy nhỏ, 6 chân chạy lệch pha |
| Drone | Robot 4 chân bước theo tốc độ di chuyển |
| Dart | Xe trinh sát mũi tên, có lửa đẩy phía sau |
| Brute | Thân to vai giáp, 2 bàn chân dậm luân phiên |
| Plated | Xe xích, **3 tấm giáp chồng**, xích chạy. Trúng đòn thì toé **tia lửa trắng (giáp đỡ)** |
| Aegis | **Vòm khiên lục giác**: độ đậm theo % khiên, gợn sáng khi trúng, **vỡ thành mảnh** khi hết khiên, có thanh khiên |
| Mender | Chữ thập xanh quay. Khi hồi máu: **vòng lan đúng bán kính hồi** + dấu "+" bay lên |
| Phantom | Khi ẩn: mờ 28%, có 2 bóng ma rung, không có thanh máu. Khi bị lộ: hiệu ứng **nhiễu tín hiệu** + icon con mắt |
| Glider | Phi cơ cánh tam giác **lơ lửng nhấp nhô**, bóng đổ lệch xa, quầng đẩy xanh. Vẽ trên quái mặt đất |
| Mảnh Monolith | Khối tinh thể đỏ sắc cạnh |

**Phản hồi:**
- Nháy trắng khi trúng đòn; tia lửa cam, hoặc trắng nếu giáp dày.
- **Thanh HP** 4px có viền, đổi màu xanh → cam → đỏ, có vệt trắng "máu vừa mất" tụt chậm.
- **Icon trạng thái** (mã hoá bằng hình): chậm ◆ băng, cháy 🔥, đánh dấu ⊕, phá giáp ⚡, ghim đất ↓, bị lộ 👁.
- Choáng: 3 sao quay. Đóng băng: khối băng lục giác bao quanh.
- Nhuộm màu: băng thì xanh, cháy thì cam nhấp nháy, chậm thì xanh nhạt.

## Boss Monolith

- Pháo đài lục giác **to ~1.75×**, lõi đỏ phát sáng, **3 khối giáp quay quanh**.
- **Pha I:** khi triệu hồi, khoang mở và có tia cam toả ra + vòng đếm ngược.
- **Pha II:** dựng **3 ăng-ten EMP**. Lúc nạp có **vòng đỏ răng cưa lan tới đúng `emp_radius`** (170) + vùng đỏ mờ. Lúc phát, sóng xung kích đỏ lan ra.
- **Pha III:** **giáp bị xé rời** (bay xa, rung, toé tia lửa), lõi lộ to và đập nhanh hơn.
- Đổi pha thì có một nhịp loé đỏ.
- **Thanh máu boss mới** ở giữa đáy màn hình:
  - tên boss, 3 pip pha, vạch ngưỡng 66% / 33%;
  - vệt máu mất tụt chậm;
  - chữ nhấp nháy "EMP sắp phát!" khi đang nạp.

  Vị trí này là để tránh che làn đường ở 2 màn có boss.
- **Boss chết:** nổ lớn + 14 mảnh + vòng đỏ lan. Mảnh boss sinh ra là quái riêng như cũ.

## Đạn & VFX (`gameplay/combat/projectile_system.gd`, xem `vfx_sheet.png`)

| Nguồn | Hình |
|---|---|
| Pulse | Tia năng lượng cyan, lõi trắng, vệt đuôi. Penetrator có vệt dài hơn |
| Đòn chí mạng (Annihilator) | Tia tím dày |
| Nova | **Quả cầu plasma cam** có đuôi. Đạn bắn cầu **bay vòng cung** kèm bóng dưới đất (điểm/thời điểm chạm không đổi). Đạn Quake to hơn, có vòng xoay |
| Trúng đòn | Loé + 4 tia lửa |
| Nổ AoE | Quầng + **sóng xung kích đúng bán kính nổ thật** + tia lửa |
| Arc | **Tia sét zigzag** chập chờn giữa các mục tiêu |
| Xuyên | Vệt sáng thẳng |
| Cryo | Vòng băng + tinh thể |
| EMP | Sóng đỏ răng cưa |
| Vùng cháy | Quầng cam + lưỡi lửa nhảy, nằm dưới tháp/quái |
| Quái chết | Loé + mảnh kim loại xoay văng ra + tàn lửa (0.55 giây). Quái to/boss nổ to hơn |

**Thứ tự lớp vẽ:** đạn và hiệu ứng nằm **trên** thân quái, để không bị che. Đây là lỗi tôi gặp khi chụp ảnh và đã sửa.

**Đã sửa thêm:** các đa giác lục giác bị "triangulation failed", do điểm cuối trùng điểm đầu. Lỗi này có từ Stage B/C (logo, ảnh thu nhỏ, lõi căn cứ) nhưng không hiện lên vì log bị lọc.

## Kiểm chứng (kết quả thật)

- **Test suite:** `128 passed, 0 failed (215.6s)`, gồm golden 18 trận khớp 100%. Không có `SCRIPT ERROR`.
- Log chụp ảnh: 0 dòng `ERROR`.
- `extract_keys.py`: 388 key, 0 thiếu (thêm "EMP incoming!" → "EMP sắp phát!").
- **Đo trên desktop** (`tools/perf_probe.gd`, x2, AMD Radeon tích hợp; **không đại diện điện thoại**):

  | Cảnh | Trung bình | p95 | Max |
  |---|---|---|---|
  | L8 stress, **75 quái** cùng lúc | 8.7 ms | 13.6 ms | 103 ms (khung đầu lúc nạp) |
  | L9, 6 quái | 6.6 ms | 9.1 ms | — |

## Giới hạn / chưa làm

- **Ảnh trận boss là cảnh dàn dựng** (`staged_boss_battle.png`):
  - tự đặt tháp, gọi boss bằng tool, rồi cho chạy thật vài giây;
  - lý do: bot giả lập không tự đến được pha boss khi chụp.

  Các pha boss được thể hiện đầy đủ trong `enemy_sheet.png`.
- Đạn bay rất nhanh nên ảnh chụp trận thật ít thấy đạn. `vfx_sheet.png` cho thấy từng hiệu ứng ở giữa chừng.
- Vẫn chưa có rung màn hình / tuỳ chọn "Giảm hiệu ứng". Hai việc này nằm trong Stage E như kế hoạch.
- HUD vẫn là bản cũ (Stage E). Âm thanh chưa đổi (Stage E).
- Chưa thử trên điện thoại thật.
