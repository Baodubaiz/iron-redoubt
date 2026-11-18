# Iron Redoubt Reforged — Stage C: Chiến trường & Tháp

Ngày: 2026-11-12 · Trạng thái: **xong, chờ duyệt trước Stage D**.
Ảnh chụp: `docs/reforged_stage_c/`.

## Bằng chứng gameplay không đổi

- **Golden test** mới (`tests/integration/test_golden.gd` + `tools/sim/golden_run.gd`):
  - chạy cả 9 màn × 2 cấu hình bot, tổng 18 trận tất định:
    - không nghiên cứu;
    - full nghiên cứu + nhánh chính/phụ + tiến hoá;
  - mỗi trận so 9 chỉ số: kết quả, HP, máu mất, wave, thời gian chính xác đến 1/10000 giây, tiền, số quái giết, số tháp, hash vị trí/bậc của mọi tháp.
- Baseline được ghi **trước khi sửa bất kỳ code hình ảnh nào** của Stage C (`tests/golden/gameplay_golden.json`).
- Sau Stage C test vẫn khớp 100% (kết quả ở cuối báo cáo).
- Dữ liệu `.tres`, file save và luật chơi không đổi.

**Thay đổi trong script gameplay** (chỉ phần trình bày, có ghi chú trong code):
- `tower.gd`:
  - bỏ hàm `_draw()`, phần vẽ chuyển sang `TowerVisual`;
  - thêm getter chỉ-đọc `beam_target()`.
- `placement_controller.gd`: bóng xem trước khi đặt tháp vẽ bằng art mới. Luật hợp lệ giữ nguyên, ô không hợp lệ vẫn có dấu X và vòng nét đứt, nên không chỉ dựa vào màu.
- `map_view.gd`: viết lại toàn bộ nhưng giữ nguyên tên lớp và API (`map`, `set_state`), nên `MatchController` không phải sửa dòng nào.

## Chiến trường (`gameplay/visuals/map_view.gd`)

**Lớp tĩnh** (chỉ vẽ lại khi đổi ngày/đêm hoặc đổi cổng):
- **Sàn kim loại** lát tấm 80px, có viền vát sáng/tối và các tấm bảo trì bắt vít.
- **Chi tiết riêng theo bản đồ:**
  - **Mạch Điện:** mạch điện cyan; ô cấm là **trạm biến áp** có cuộn dây và sọc cảnh báo; nút quá tải là bệ lục giác cam có vòng xoay.
  - **Châu Thổ:** kênh năng lượng lượn sóng xanh/tím; ô cấm là **máy làm mát** có lá tản nhiệt và quạt. **Ban đêm** sàn tối hẳn, tháp bị giảm tầm thì tối màu đi, Beacon có quầng sáng tầm chiếu.
  - **Lăng Kính:** sàn tím có mảnh tinh thể; ô cấm là **lõi tinh thể** tím/cam; **cổng đổi đường** (xem dưới).
- **Đường ray phát sáng:** viền sáng theo màu bản đồ, lòng đường tối, vạch ngang, rãnh giữa. Làn bị đóng mờ đi và có chấm đỏ. Đường vẫn dễ phân biệt với ô xây được.

**Lớp động:**
- Mũi tên chỉ hướng chạy dọc đường; đường bay có mũi tên xanh lá nhỏ hơn.
- Cổng xuất quân màu đỏ xoay.
- **Cổng Prism:**
  - giàn cổng có 2 trụ;
  - khi đóng: tấm chắn sọc cảnh báo, đèn đỏ, dấu X;
  - khi đổi đường: tấm chắn trượt vào trụ, đèn nhấp nháy;
  - khi mở: đèn xanh.
- **Lõi Iron Redoubt** ở căn cứ: vòng xoay; màu theo HP (xanh → cam → đỏ); rung và loé đỏ khi quái lọt vào.

## Tháp (`gameplay/visuals/tower_art.gd`, `tower_visual.gd`, SVG trong `assets/art/towers/`)

**Cấu trúc:**
- Đế lục giác kim loại (SVG), nòng xoay (SVG), bộ phận nhánh vẽ bằng code.
- Đứng yên: lõi thở sáng, nòng quét nhẹ khi không có mục tiêu (chỉ hình ảnh).
- **Khi bắn:** nòng giật lùi, chớp đầu nòng.
  - Pulse bắn luân phiên 2 nòng.
  - Nova có lò phản ứng nạp sáng dần giữa các phát.
  - **Lance có tia laser 3 lớp, độ dày theo `beam_ramp()` thật.** Nhánh xuyên có thêm tia kéo dài.

**Nâng cấp đổi hình khối**, không chỉ đổi màu (xem `tower_sheet.png`: 4 tháp × 9 dạng):

| Tháp | Nhánh A | Nhánh B | Nhánh C | Tiến hoá |
|---|---|---|---|---|
| Pulse | Rapid: vòng tản nhiệt quanh nòng | Penetrator: nòng dài + cánh ổn định | Sensor: chảo radar quay | Storm Array: trống 4 nòng xoay · Railspike: ray đôi dài có kênh năng lượng · Hunter Net: radar lớn |
| Nova | Cluster: lỗ phóng trên lò | Incendiary: bình nhiên liệu 2 bên | Siege: nòng dài + chân chống | Cascade: 3 ống phóng · Inferno: lửa ở đầu nòng · Quake: búa hãm nòng |
| Lance | Overcharge: tụ điện 2 bên | Arc: quả cầu Tesla tia lửa | Focus: thêm vòng hội tụ | Annihilator: ống bọc nòng · Tesla Web: 3 cuộn · Phase Beam: nòng phát dài |
| Beacon | Amplifier: thêm vòng năng lượng | Cryo: tinh thể băng | Relay: đĩa phát | Overclock Core: lõi to, vòng quay nhanh · Absolute Zero: vòng băng · Mint: chip tiền quay quanh |

**Các dấu hiệu khác:**
- Mỗi bậc nhánh chính thêm 1 **ngàm giáp** trên đế. Nhánh phụ là **module phụ** gắn ở đế, có đèn theo bậc.
- Pip bậc: nhánh chính là hình thoi, nhánh phụ là hình vuông.
- **Tiến hoá:** tháp to hơn 10%, có viền lục giác hào quang xoay, ngôi sao cam, và hiệu ứng **cột sáng + vòng lục giác nở** lúc tiến hoá.

**Phản hồi:**
- Xây: tháp "rơi" xuống + vòng bụi.
- Nâng cấp: tháp nảy lên + vòng sáng.
- Chọn tháp: vòng lục giác trắng xoay, tầm bắn tô màu tháp có vạch chia xoay chậm.
- Bị EMP: tháp tối đi, có tia điện đỏ.
- Buff synergy: vẫn mã hoá bằng hình (tam giác / cung / vòng), như trước.

## Kiểm chứng (kết quả thật)

- **Test suite:** `128 passed, 0 failed (200.8s)`, có cả **golden test 18 trận khớp 100%**. Không có `SCRIPT ERROR`. Đã chạy 2 lần, cả 2 lần đều pass.
- `extract_keys.py`: 387 key, 0 thiếu bản dịch. Stage C không thêm chuỗi mới.
- **Đo khung hình trên desktop** (`tools/perf_probe.gd`, x2, AMD Radeon tích hợp, đo lúc test suite chạy song song):

  | Màn | Lúc đo | Thời gian khung hình |
  |---|---|---|
  | L8 | 27 quái, 6 tháp | trung bình 6.4 ms, p95 10.7 ms, max 45 ms |
  | L9 | 5 quái | trung bình 6.6 ms |

  **Đây là số desktop, không đại diện cho điện thoại.**

## Giới hạn / chưa làm

- **Quái và đạn vẫn là hình cũ.** Đó là Stage D, cùng với hiệu ứng trúng/chết và boss.
- **HUD vẫn là bản cũ** (Stage E).
- Ở chỗ 2 làn Delta chập nhau, mũi tên chỉ hướng bị nhân đôi (">>"). Đây là lỗi nhỏ về thẩm mỹ.
- Bot giả lập bị thua ở L9 khi chụp ảnh với seed ngẫu nhiên, nên chưa có ảnh trận boss. Ảnh boss sẽ có ở Stage D.
- Chưa thử trên điện thoại thật.
