# Iron Redoubt Reforged — Stage B: Menu chính & Chiến dịch

Ngày: 2026-11-12 · Trạng thái: **xong, chờ duyệt trước Stage C**.
Gameplay, dữ liệu `.tres` và định dạng save **không đổi**. HUD trong trận chưa đổi; đó là Stage E.

Ảnh chụp: `docs/reforged_stage_b/`. Có 4 tỉ lệ màn hình (16:9, 19.5:9, 20:9 có tai thỏ giả lập, 4:3) và cả 2 ngôn ngữ.

## Đã làm

**Design system**
- `ui/style/visual_palette.gd`:
  - 8 màu theo yêu cầu;
  - màu theo tháp và theo vùng bản đồ;
  - mô tả ngắn cho từng vùng.
- `ui/ui_kit.gd` được viết lại, API cũ vẫn giữ nên các màn cũ vẫn chạy:
  - theme mới: nút/panel vát góc, nút chính cyan có viền phát sáng, thẻ chọn (CardButton), chip icon + số, slider/scroll/popup cùng phong cách;
  - hiệu ứng nhấn nút (co lại rồi bật về) và xuất hiện lần lượt (fade + phóng nhẹ).
- Font OFL: Chakra Petch cho tiêu đề và nút, Be Vietnam Pro cho chữ thường. Đã kiểm tra đủ dấu tiếng Việt.
- 20 icon SVG tự vẽ, cùng 4 emblem tháp màu (`assets/art/towers/icon_*.svg`).
- Ghi nguồn asset: `docs/ASSET_SOURCES.md`.

**Menu chính** (`ui/menus/main_menu.gd`, `ui/widgets/menu_backdrop.gd`, `ui/widgets/hex_logo.gd`, `ui/style/shine.gdshader`)
- Logo IRON REDOUBT:
  - emblem lục giác có vòng quay và lõi thở sáng;
  - vệt sáng quét qua chữ mỗi ~6 giây (shader nhỏ).
- **Nền chiến trường động**:
  - đường ray phát sáng có xung năng lượng chạy dọc;
  - drone đi trên đường;
  - tháp Pulse xoay nòng, bắn luân phiên 2 nòng có giật lùi và chớp đầu nòng;
  - drone trúng đạn thì nháy, chết thì nổ ra tia lửa;
  - hạt bụi trôi, mạch điện có xung chạy.

  Đây chỉ là trình bày, không dùng `MatchController`. Lớp tĩnh vẽ 1 lần, lớp động rất nhẹ.
- Nút **CHƠI** to và nổi bật, ghi màn sẽ chơi ("Màn 7 · Cổng Dịch Chuyển"). Nút mở thẳng màn chưa phá đầu tiên.
- Nút Chiến dịch / Nghiên cứu / Thử thách có icon. Góc trên có chip Lõi, nút đổi nhanh ngôn ngữ EN/VI và nút Cài đặt.
- **Combat Lab đã bỏ khỏi menu.** Chỉ bản debug mở được, bằng cách nhấn giữ số phiên bản 2 giây.
- Phiên bản hiện mờ ở góc dưới.

**Chiến dịch** (`ui/menus/campaign_select.gd`, `ui/widgets/map_thumbnail.gd`)
- **3 tab vùng** Mạch Điện / Châu Thổ / Lăng Kính:
  - màu riêng từng vùng, hình nền là bản đồ thật;
  - mô tả ngắn, tiến độ x/3 kèm thanh;
  - ổ khoá nếu vùng chưa mở.
- **Thẻ màn**:
  - **ảnh thu nhỏ vẽ từ chính `MapDef`** (đường đi, ô cấm, nút quá tải, đường bay, lối vào, căn cứ);
  - huy hiệu lấy từ dữ liệu màn: boss / đêm / quái bay / cổng;
  - số màn lớn, tên màn;
  - trạng thái: MỚI / ✓ đã phá + ★ không mất máu + thanh HP tốt nhất / khoá kèm điều kiện "Qua màn N để mở khoá".
- Thẻ được chọn nổi lên và viền sáng. Mặc định chọn sẵn màn nên chơi.
- **Thanh chi tiết**: mục tiêu, chip số wave / tiền đầu / HP căn cứ, emblem các tháp dùng được (tháp chưa mở thì mờ), thưởng lần đầu, tháp được mở khoá.
- Nút **CHƠI** cyan nhịp sáng khi đã chọn màn.
- Logic mở khoá **không đổi**: màn hình chỉ đọc `is_level_unlocked()` / `level_record()`.

**Các màn khác** (cùng style, không đổi chức năng)
- Nghiên cứu: thẻ có emblem tháp tương ứng; viền xanh lá khi đã sở hữu, viền cyan khi mua được; nút mua có icon Lõi.
- Thử thách & Thành tựu: thẻ có icon cúp, ✓, ★ và chip thưởng.
- Cài đặt: panel nền đặc, nên khi mở trong trận không còn lộ menu tạm dừng bên dưới.

**Chuyển cảnh** (`core/scene_router.gd`)
- Đổi màn hình vẫn diễn ra ngay lúc gọi như cũ.
- Một lớp phủ tối che lúc chuyển, rồi mờ dần kèm vạch quét cyan.
- Lớp phủ đợi scene mới dựng xong mới bắt đầu, nên không bị "mất" hiệu ứng khi tải lần đầu bị khựng.

## Kiểm chứng (kết quả thật)

- **Test suite:** `127 passed, 0 failed (79.4s)`. Trước đây là 121; 6 test mới. Không có `SCRIPT ERROR`. Game chạy trên desktop không lỗi.
- **Test mới `tests/unit/test_menus.gd`** (6 test):
  - font, icon và emblem tháp tải được;
  - cắt số khỏi tên màn;
  - CHƠI chọn đúng màn (hồ sơ mới → màn 1; phá 4 màn → màn 5; phá hết → màn 9);
  - menu đủ nút, **không có nút Lab**;
  - thẻ màn khoá/mở khớp model, màn gợi ý được chọn sẵn, CHƠI bật; vùng Lăng Kính khoá hết;
  - màn Nghiên cứu và Thử thách dựng được.
- `extract_keys.py`: 387 key, **0 thiếu bản dịch**. Đã thêm 13 key mới.
- Ảnh chụp 4 tỉ lệ × EN/VI: không tràn chữ, không đè safe area.

## Giới hạn / chưa kiểm chứng

- **Chưa chạy trên điện thoại thật.** Độ mượt của nền động và cảm giác chạm chưa được đo trên Android.
- Hiệu ứng hover chỉ có ý nghĩa trên desktop. Trên điện thoại chỉ có phản hồi khi nhấn.
- Phiên bản vẫn là 0.7.0. Lên 0.8.0 sẽ làm ở Stage F, khi build APK.
- Đồ hoạ là vector tự vẽ, không phải tranh của hoạ sĩ (đúng như Stage A đã nói).
