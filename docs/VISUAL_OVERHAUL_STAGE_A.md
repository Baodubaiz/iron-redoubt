# Iron Redoubt Reforged — Stage A: Khảo sát hình ảnh & Thiết kế

Ngày: 2026-11-12 · Bản hiện tại: 0.7.0 · Godot 4.7.2 (GL Compatibility)
Trạng thái: **chỉ là kế hoạch, chưa sửa code.** Chờ duyệt trước khi bắt đầu Stage B.

> Prompt gốc ghi "PRISMHOLD". Game hiện tên **Iron Redoubt**, nên logo, menu và tài liệu dùng Iron Redoubt. Bản đồ thứ 3 vẫn tên "Prism".
> Ảnh concept: `docs/reforged_concepts/concept_sheet.png` (vẽ bằng chính kỹ thuật đề xuất ở §11).

---

## 1. Hiện trạng: code hình ảnh nằm ở đâu

| Thành phần | File | Cách vẽ hiện tại |
|---|---|---|
| Tháp | `gameplay/combat/tower.gd` `_draw()` → `gameplay/visuals/shape_art.gd` | Hình học phẳng: tam giác, vuông, thoi, tròn + viền; tầm bắn là vòng tròn trắng; pip bậc nâng cấp là chấm nhỏ |
| Quái (10 loại) | `gameplay/combat/enemy.gd` `_draw()` → `ShapeArt.draw_enemy` | Mỗi loại 1 hình: tròn, mũi tên, chấm, lục giác…; flash trắng khi trúng đạn; thanh HP 3px |
| Đạn & VFX | `gameplay/combat/projectile_system.gd` | Chấm/vạch 2–5px, vòng nổ, tia lửa bằng `draw_line`; có pool (tốt cho hiệu năng) |
| Bản đồ | `gameplay/visuals/map_view.gd` | Nền đặc + lưới 40px, đường là polyline xám, ô cấm là hình chữ nhật có dấu X |
| Menu | `ui/menus/*.gd`, `ui/ui_kit.gd` | Godot `Button` + `StyleBoxFlat` mặc định, chữ font mặc định |
| HUD | `ui/hud/hud.gd`, `ui/hud/tower_panel.gd` | Thanh trên chỉ có chữ (`HP 20/20  $ 130  Wave 5/12`), cột tháp bên phải là nút chữ, panel tháp nằm dưới (tự lên trên nếu tháp ở nửa dưới) |
| Âm thanh | `tools/audio_gen/gen_audio.gd` → `audio/sfx/*.wav` | 15 SFX tổng hợp + 1 nhạc nền, tự tạo (bản quyền của dự án) |
| Asset ảnh | — | **Không có sprite nào.** Chỉ có `icon.svg` và icon launcher |

**Điểm có lợi:** gameplay đã tách khỏi phần trình bày. Controller chạy fixed-step và đã phát các signal chỉ dành cho trình bày: `shot_fired`, `explosion`, `towers_disrupted`, `boss_phase_changed`, `enemy_killed`, `tower_upgraded`, …

Toàn bộ phần vẽ chỉ nằm trong `_draw()` và hai file `ShapeArt`/`MapView`, nên có thể thay hình ảnh mà không đụng logic. Không test nào gọi `ShapeArt`/`MapView`.

### Vấn đề hình ảnh hiện tại

1. **Trông như công cụ debug:**
   - nền đen + lưới;
   - đường đi màu xám phẳng;
   - ô cấm có dấu X;
   - tháp và quái chỉ là viền hình học 2px, không có khối, bóng hay chiều sâu.
2. **Không có chuyển động "sống":**
   - tháp không có hoạt ảnh idle, giật lùi hay nạp năng lượng;
   - quái trượt đi như con trỏ;
   - chết là biến mất ngay.
3. **Quái nhỏ (r = 5–16px) và gần cùng màu pastel**, nên khó phân biệt trên điện thoại. Thanh HP 3px quá mỏng.
4. **Đạn gần như không thấy được** (chấm 5px), và các tháp không có bản sắc đòn đánh riêng.
5. **Menu là danh sách nút chữ**:
   - không có logo hay hình nền;
   - Campaign là bảng chữ;
   - nút Play ít nổi bật.
6. **HUD toàn chữ**:
   - không có icon tiền, HP hay wave;
   - thẻ tháp bên phải không có hình tháp;
   - panel tháp dày chữ.
7. **Font mặc định của Godot** không có cá tính. Màu sắc chưa thống nhất: hồng `#ff6bd6` cho Lance, vàng `#ffd36b` cho tiền, xanh lá `#6be08a` cho HP.
8. **Thiếu phản hồi**:
   - không thông báo khi thiếu tiền, xây hay bán xong;
   - thông báo "Wave N" chỉ là chữ mờ.

---

## 2. Hệ thống thiết kế (Design System)

### 2.1 Ý tưởng chủ đạo: "Hex Vanguard"

Một tiền đồn phòng thủ công nghệ cao. Mọi thứ xoay quanh **hình lục giác**:

- logo;
- căn cứ (Core) cần bảo vệ;
- góc vát của nút và panel;
- đế tháp;
- hoa văn sàn.

Lục giác dùng làm motif chung, không dùng để phân biệt loại. Tháp và quái phân biệt bằng **silhouette**, không chỉ bằng màu.

### 2.2 Bảng màu (đúng theo yêu cầu) và ý nghĩa cố định

| Token | Hex | Dùng cho |
|---|---|---|
| `bg` | `#0B1020` | nền chính, sàn tối |
| `surface` | `#172238` | panel, thẻ, kim loại |
| `surface_hi` | `#22314F` | viền sáng, mép kim loại (phụ, suy ra từ surface) |
| `cyan` | `#38D9F5` | màu thương hiệu, UI tương tác, **Pulse** |
| `blue` | `#4D8CFF` | thông tin, wave, **Delta** |
| `violet` | `#A66BFF` | **Lance**, **Prism**, tàng hình |
| `orange` | `#FFAA45` | **Nova**, **tiền (Credits)**, Lõi (Cores), cảnh báo nhẹ |
| `red` | `#FF5368` | quái, nguy hiểm, mất HP, boss, không hợp lệ |
| `green` | `#4DE6A1` | **Beacon**, HP căn cứ, hợp lệ, hồi máu, thành công |

Quy tắc:

- **Phe ta** (tháp, UI) dùng màu lạnh và màu của tháp, phát sáng.
- **Phe địch** dùng **thân kim loại xám-đen**, kèm **lõi/mắt đỏ-cam phát sáng**. Màu nhận diện của từng loại quái chỉ nằm ở chi tiết.

Nhờ vậy, nhìn qua là phân biệt được ta và địch.

**Glow** dùng sprite phát sáng (`CanvasItemMaterial` additive) quy mô nhỏ, không dùng bloom toàn màn hình (§12).

> Thay đổi nhỏ cần duyệt:
> - Lance đổi từ hồng `#ff6bd6` sang tím `#A66BFF`, Beacon đổi từ `#6be08a` sang `#4DE6A1`, theo bảng màu mới.
> - Tiền trong trận (Credits) đổi từ vàng sang **cam** `#FFAA45`. Lõi (Cores) cũng dùng cam nhưng **khác icon** (đồng xu lục giác ↔ tinh thể).

### 2.3 Typography

- **Tiêu đề / số:** font sci-fi dạng vuông có hỗ trợ **tiếng Việt**. Đề cử **Chakra Petch** (Google Fonts, giấy phép OFL; cần kiểm tra lại dấu tiếng Việt khi tải).
- **Chữ thường:** **Be Vietnam Pro** (OFL, hỗ trợ tiếng Việt đầy đủ).
- Phải **tải 2 font từ fonts.google.com**: tổng ~1 MB, giấy phép OFL cho phép đóng gói vào game. **Cần bạn đồng ý tải** (xem §15).
- Nếu không đồng ý, tôi giữ font mặc định của Godot và làm phần còn lại bằng kiểu chữ và hiệu ứng.

### 2.4 Thành phần UI (thay `UiKit`)

| Thành phần | Mô tả |
|---|---|
| `HexButton` | Nút vát 2 góc chéo. Nền `surface`, viền phát sáng màu nhấn, có 1 "vệt quét" sáng khi hover/focus, co 0.96 khi nhấn (Tween 80ms). Biến thể: `primary` (cyan đặc, chữ tối, to), `secondary`, `danger`, `disabled` (có ổ khoá) |
| `HexPanel` | Panel vát góc, viền 1px `surface_hi` + vạch nhấn ở góc, nền mờ 92% |
| `StatChip` | icon + số (HP, tiền, wave, Cores), có Tween "đếm số" khi giá trị đổi và nháy đỏ khi giảm |
| `Toast` | thông báo ngắn trượt vào từ trên (Thiếu tiền, Đã xây, Đã bán, Thành tựu…) |
| `ScreenTransition` | lớp phủ lục giác/quét ngang 0.25s giữa các màn, đặt trong `SceneRouter` |
| Bộ icon | vẽ bằng SVG: tiền, lõi, HP, wave, tạm dừng, x1/x2, khoá, sao, ngôn ngữ, âm thanh… |

---

## 3. Menu chính mới

```
┌─────────────────────────────────────────────────────────────────────┐
│ [◆ 170 Lõi]                                         [⚙] [🌐 VI]      │  ← chip tiền tệ + nút nhỏ
│                                                                     │
│        ⬡ IRON REDOUBT                       ╱ tháp Pulse ╲          │
│        ───────────── DEFENSE PROTOCOL       (cảnh nền sống:         │
│                                              tháp bắn drone bay     │
│        ┏━━━━━━━━━━━━━━━━━━━━━┓               qua đường phát sáng,   │
│        ┃   ▶  CHƠI            ┃  ← primary    hạt bụi năng lượng)    │
│        ┃   Màn 7 · Shifting Gates ┃  (tiếp tục màn đang mở)          │
│        ┗━━━━━━━━━━━━━━━━━━━━━┛                                       │
│        [⬡ Chiến dịch] [⚗ Nghiên cứu] [🏆 Thử thách]                   │
│                                                                     │
│ v0.8.0-playtest · offline                                           │
└─────────────────────────────────────────────────────────────────────┘
```

**Hình nền động:**

- dùng lại renderer bản đồ mới để vẽ một đoạn bản đồ Circuit;
- 2 tháp trang trí xoay nòng và bắn quái giả chạy vòng lặp;
- đây là `MenuBackdrop` chỉ để trình bày, không dùng `MatchController`;
- vài chục hạt bụi, có tầng parallax chậm;
- logo có hiệu ứng quét sáng mỗi 6s.

**Nút và chuyển cảnh:**

- **CHƠI** mở thẳng **màn chưa phá cao nhất**. Đây là phím tắt, logic mở khoá giữ nguyên.
- Các nút khác điều hướng như cũ.
- Khi mở menu, các nút trượt vào lần lượt cách nhau 60ms.

**Combat Lab:**

- Bỏ khỏi menu chính.
- Trong **bản debug**, mở bằng cách **nhấn giữ 2 giây vào số phiên bản**.
- Bản release (APK playtest) hoàn toàn không có lối vào.

**Bố cục theo tỉ lệ màn hình:**

- Logo + nút bên trái, cảnh động bên phải.
- Với 4:3, cảnh thu hẹp và nút vẫn đủ ≥ 56px.
- Bố cục bám safe area như hiện tại.

---

## 4. Màn Chiến dịch mới

```
┌─────────────────────────────────────────────────────────────────────┐
│ [◀]  CHIẾN DỊCH                                         [◆ 170 Lõi]  │
│ ┌─[CIRCUIT ✓3/3]──┐ ┌─[DELTA  ✓3/3]───┐ ┌─[PRISM  1/3]────┐          │ ← 3 tab vùng (ảnh minh hoạ nhỏ,
│ └─────────────────┘ └─────────────────┘ └─────────────────┘          │   tiến độ, màu riêng)
│  Prism — Tổ hợp năng lượng · Cổng đổi đường                          │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                   │
│ │ [ảnh thu nhỏ │ │ [ảnh thu nhỏ │ │   🔒          │  ← thẻ màn,        │
│ │  bản đồ thật]│ │  bản đồ thật]│ │  (tối, mờ)   │    cuộn ngang      │
│ │ 07 SHIFTING  │ │ 08 PRISM     │ │ 09 MONOLITH  │                   │
│ │    GATES     │ │    STORM     │ │   AWAKENED   │                   │
│ │ ✓ ★  ▮▮▮▮▯ HP│ │  MỚI         │ │ Phá màn 8    │                   │
│ └──────────────┘ └──────────────┘ └──────────────┘                   │
│ ┌ Mục tiêu · 12 wave · 250$ · HP 20 · Tháp: ▲■◆● · Thưởng 60 ◆ ┐ [▶ CHƠI]│
└─────────────────────────────────────────────────────────────────────┘
```

**Tab vùng (Circuit / Delta / Prism):**

- có tranh minh hoạ nhỏ và màu môi trường riêng;
- thanh tiến độ x/3, ổ khoá nếu chưa mở.

Mặc định chọn vùng có màn đang chơi dở.

**Thẻ màn:**

- **Ảnh thu nhỏ vẽ từ chính `MapDef`**: đường đi, ô cấm, lối vào, căn cứ. Ảnh đúng với màn chơi, không phải hình bịa.
- Số màn lớn, tên màn.
- Trạng thái:
  - **Khoá**: tối, có ổ khoá + điều kiện mở;
  - **Mới**: viền sáng nhấp nháy nhẹ;
  - **Đã phá**: dấu ✓.
- **Biểu tượng thành tích**, dùng **dữ liệu sẵn có** thay cho "sao" vì game không có hệ thống sao:
  - ✓ Đã phá;
  - ★ Không mất HP (flawless);
  - thanh **HP tốt nhất**.
- Khi chọn: thẻ nổi lên 6px, viền phát sáng, và nút **CHƠI** đổi từ xám sang cyan đặc + nhịp sáng.

**Thanh chi tiết dưới cùng:** mục tiêu, số wave, tiền đầu, HP căn cứ, icon các tháp được dùng, thưởng lần đầu, tháp mở khoá.

Logic mở khoá màn **không đổi**: chỉ đọc `model.is_level_unlocked()` và `profile.level_record()` như hiện tại.

Research / Challenges / Settings dùng cùng bộ `HexPanel`/`HexButton` để thống nhất, không đổi bố cục chức năng.

---

## 5. Chiến trường

### 5.1 Kỹ thuật

`MapView` được viết lại thành nhiều lớp:

| Lớp | Mô tả |
|---|---|
| **Terrain** | Sàn kim loại lát tấm lục giác/vuông (texture lặp 128px). Vẽ **một lần** vào `SubViewport` tĩnh khi vào trận, không vẽ lại mỗi frame |
| **Decor** | Cấu trúc trang trí ở viền bản đồ và trên **ô cấm**: máy biến áp, tháp làm mát, ống dẫn. Ô cấm trở thành "khối máy" rõ ràng thay cho hộp có dấu X |
| **Path** | Đường ray kim loại: viền 2 bên sáng màu theo map, mặt đường tối hơn sàn. Chevron chỉ hướng **chạy chậm** dọc đường (shader UV-scroll đơn giản, hoặc dịch offset bằng `_process`) |
| **Ambient** | Mạch năng lượng chạy chậm trên sàn, vài đèn nhấp nháy. Chỉ là sprite, ít điểm |
| **Overlay** | Ban đêm (Delta), cảnh báo cổng (Prism) |

Va chạm, đường đi và luật đặt tháp **không đổi**: renderer chỉ đọc `MapDef` (`routes`, `path_half_width`, `blocked_rects`, `range_bonus_zones`, `air_routes`).

Đường mới phải phủ **đúng** dải mà `PlacementRules` coi là đường. Viền được vẽ trùng mép `path_half_width` để người chơi không đặt nhầm.

### 5.2 Bản sắc từng bản đồ

| Map | Không khí | Màu | Chi tiết riêng |
|---|---|---|---|
| **Circuit** | Nhà máy điện | Sàn thép xanh xám, mạch **cyan** | Ô cấm là trạm biến áp có cuộn dây. **Overload node** là trụ năng lượng vàng-cam xoay. Đường ray có rãnh cyan |
| **Delta** | Khu thử nghiệm | Sàn xanh **blue/violet**, có kênh nước năng lượng | 2 lối vào có cổng spawn đánh số. **Ngày**: sáng nhẹ. **Đêm**: lớp tối + đèn đường tắt dần; vùng sáng quanh Beacon là quầng xanh lá (mask, không dùng light 2D). Đồng hồ ngày/đêm hiển thị trên HUD |
| **Prism** | Tổ hợp năng lượng | Sàn tím đậm, điểm nhấn **tím + cam** | **Cổng đổi đường** là cửa cơ khí 2 cánh: đóng thì cánh khép + vạch đỏ, mở thì cánh trượt ra + vạch xanh. Khi báo trước, cổng sắp mở nhấp nháy cam. Đường bay là luồng hạt mờ |

**Căn cứ (Core):** lõi lục giác lớn có vòng xoay, màu theo HP (xanh → cam → đỏ), rung nhẹ và nháy đỏ khi bị trúng.

---

## 6. Tháp (4 loại × 3 nhánh × tiến hoá)

### 6.1 Cấu trúc chung

Mỗi tháp gồm các lớp `Sprite2D` (SVG) trong một node con `TowerVisual`:

```
Shadow → Base (đế lục giác, không xoay) → Turret (xoay theo aim_angle) → Barrel/Emitter (giật lùi)
       → Core glow (additive, nhịp thở) → Upgrade parts (giáp, nòng phụ…) → Pip bậc/nhánh
```

**Hoạt ảnh:**

| Trạng thái | Biểu hiện |
|---|---|
| **Idle** | lõi thở sáng 2s; tháp không có mục tiêu thì quét chậm ±20° |
| **Bắn** | nòng giật lùi 3–6px trong 80ms, chớp lửa đầu nòng 60ms |

**Nâng cấp thay đổi hình khối**, không chỉ đổi màu:

- nhánh chính bậc 1 → 2 → 3 thêm bộ phận theo nhánh;
- nhánh phụ thêm 1 module nhỏ ở đế;
- **tiến hoá** đổi hẳn turret + thêm vòng hào quang và hiệu ứng "biến hình" 0.6s.

**Chọn tháp:** viền lục giác sáng quay chậm. Tầm bắn là vòng tròn có vạch chia và lớp phủ nhạt màu của tháp, thay cho vòng trắng.

**Tốc độ hoạt ảnh:**

- Hoạt ảnh trang trí (thở, quét) chạy theo thời gian thực của `_process`.
- Hoạt ảnh gắn với sự kiện gameplay (bắn, giật lùi) **kích hoạt bởi signal**, nên tự khớp với tốc độ x2 và tạm dừng.

### 6.2 Thiết kế từng tháp

Theo cơ chế thật trong `data/towers/*.tres`:

| Tháp | Thân & vũ khí | Đòn đánh | Nhánh (thay đổi hình) | Tiến hoá |
|---|---|---|---|---|
| **Pulse** (cyan, bắn nhanh, bắn được quái bay) | Tháp pháo nhỏ gọn, đầu xoay **2 nòng song song**, lõi cyan | Tia năng lượng ngắn bắn **luân phiên 2 nòng**; chớp đầu nòng nhỏ; tia điện nhỏ khi trúng | **Rapid**: thêm ống tản nhiệt, nòng ngắn dày. **Penetrator**: nòng dài + vây ổn định. **Sensor**: đĩa radar quay trên lưng | Storm Array: 4 nòng xoay kiểu gatling · Railspike: nòng ray đôi dài, đạn thành vệt thẳng · Hunter Net: chảo radar lớn + vòng quét |
| **Nova** (cam, pháo nổ AoE) | Pháo cối hạng nặng, **nòng to ngắn**, lò phản ứng cam tròn ở sau | Nạp lò (sáng dần) → bắn quả cầu plasma bay vòng cung → nổ cam + **sóng xung kích lan ra đúng bán kính nổ thật** | **Siege**: nòng dài hơn + chân chống. **Incendiary**: bình nhiên liệu hai bên, đạn để lại vệt lửa (khớp vùng cháy đã có). **Cluster**: ổ đạn tròn nhiều lỗ | Quake / Inferno / Cascade: thân to hơn, tương ứng nòng búa, lò lửa, ổ chùm |
| **Lance** (tím, tia chính xác) | Thân thon dài, **nòng ray dài** có các vòng hội tụ, lõi tím | **Tia laser liên tục**: tia sáng mảnh + lõi trắng + tia lấp lánh ở điểm chạm. **Độ dày tia tăng theo `beam_ramp()`** (dữ liệu thật). Các vòng hội tụ sáng dần khi nạp | **Focus**: thêm vòng hội tụ. **Arc**: cuộn Tesla ở đầu nòng, tia nhảy zigzag (khớp chain). **Overcharge**: tụ điện lồi, tia dày hơn | Phase Beam / Tesla Web / Annihilator |
| **Beacon** (xanh lá, hỗ trợ / chiếu sáng / làm chậm) | Cột ăng-ten trên đế, **2 vòng năng lượng quay quanh lõi xanh** | Không bắn. Các xung trường nhẹ lan định kỳ trong tầm. **Đường nối sáng** tới tháp được buff (đã có liên kết synergy, vẽ đẹp lại). Tháp được buff có icon ▲ nhỏ | **Relay**: thêm đĩa phát. **Cryo**: tinh thể băng, trường xanh băng (làm chậm). **Amplifier**: vòng thứ 3 to | Mint / Absolute Zero / Overclock Core |

**Bị EMP vô hiệu hoá:** tháp tối đi, tia điện đỏ chạy quanh, và turret ngừng xoay.

---

## 7. Quái (10 loại; không thêm khả năng nào)

Ngôn ngữ chung:

- thân **kim loại tối**, kèm "mắt"/lõi **đỏ-cam** phát sáng ở hướng di chuyển;
- **xoay theo hướng đi**;
- **lắc lư/chân bước** bằng xoay/dịch sprite theo sóng sin (nhịp chạy theo tốc độ thật).

Kích thước hiển thị phóng to ~1.3×, có giới hạn để quái không lấn đường. **Bán kính va chạm không đổi.**

| Quái | Cơ chế thật | Silhouette & hoạt ảnh |
|---|---|---|
| **Drone** | cơ bản | Robot bọ 4 chân nhỏ, mắt đỏ đơn, chân bước nhanh |
| **Dart** | nhanh, máu thấp | Xe trinh sát hình mũi tên thấp, có vệt khói/đuôi sáng phía sau |
| **Brute** | trâu, chậm | Cỗ máy 2 chân to, vai bọc thép, bước nặng (lắc mạnh, chậm) |
| **Swarmling** | rất nhỏ, đông | Nhện máy li ti 1 mắt; bầy di chuyển lệch pha, đọc được thành "đàn" |
| **Plated** | giáp 8 | Xe tăng nhỏ có **các tấm giáp chồng lớp**. Trúng đòn yếu hơn giáp thì **tóe tia lửa xám** (phản hồi "giáp đỡ") |
| **Aegis** | khiên 150, hồi khiên | Robot mang **máy phát khiên**: vòm lục giác trong suốt bao quanh. Trúng khiên thì gợn sóng tại điểm chạm. Vòm mờ dần theo % khiên, vỡ thì có mảnh lục giác. Khi hồi lại, vòm "đóng" từ dưới lên |
| **Glider** (bay) | bay theo đường không | Phi cơ cánh tam giác, **bóng đổ lệch 10px + nhấp nhô** (lơ lửng), có quầng đẩy ở đuôi |
| **Phantom** (tàng hình) | chỉ lộ gần Beacon / Sensor | Khi ẩn: **méo không khí, viền chập chờn, 25% opacity**, không có thanh HP. Khi lộ: hiện rõ thân hình kim cương + hiệu ứng "nhiễu tín hiệu" 0.2s |
| **Mender** (hồi máu) | hồi máu quanh nó | Drone y tế có chữ thập xanh lá **quay**. Khi hồi: vòng xanh lan ra + **dấu + nhỏ bay lên** từ quái được hồi |
| **Monolith** (boss) | 3 pha: triệu hồi → EMP → nứt vỡ thành mảnh | Pháo đài di động lục giác lớn (~2× hiện tại) với **lõi đỏ khổng lồ**, 3 khối giáp xoay quanh, chân xích. **P1**: khoang mở + tia đỏ khi triệu hồi. **P2**: ăng-ten dựng lên, vòng EMP nạp đỏ (đã có telegraph, vẽ đẹp lại). **P3**: giáp bong, lõi lộ, tia lửa, nhanh hơn. **Chết**: nổ lớn + mảnh (Shard) bắn ra |
| *Shard* (mảnh boss) | sinh ra khi boss vỡ | Khối tinh thể đỏ sắc cạnh, lõi đỏ |

**Phản hồi chung khi trúng đòn và khi chết:**

- **Trúng đòn:** nháy trắng 60ms (đã có), tia lửa nhỏ theo màu đạn, và số sát thương cho đòn chí mạng. Số sát thương có công tắc trong Settings, mặc định tắt cho gọn.
- **Thanh HP:** dày 4px, có viền. Chỉ hiện khi đã mất máu. Có lớp "vệt sát thương" trắng tụt chậm.
- **Chết:**
  - 4–6 mảnh kim loại văng + tan năng lượng 0.35s;
  - boss/Brute có vụ nổ nhỏ;
  - VFX nằm trong pool riêng, nên **không phụ thuộc node quái đã bị xoá**.

**Icon trạng thái** (thay chấm 4px):

- **Chậm/băng**: tinh thể băng + quái nhuộm xanh.
- **Choáng**: 3 sao quay.
- **Cháy**: lửa nhỏ trên thân.
- **Đánh dấu (mark)**: tâm ngắm đỏ.
- **Bị phá giáp (shred)**: vết nứt.
- **Bị ghim xuống đất (grounded)**: mũi tên xuống.

---

## 8. Đạn & VFX chiến đấu

Vẫn **một hệ pool** (`projectile_system.gd`), nhưng mỗi tháp/nhánh có kiểu vẽ riêng bằng texture nhỏ (atlas):

| Nguồn | Đạn | Trúng | Ghi chú |
|---|---|---|---|
| Pulse | Tia ngắn 14px, lõi trắng + viền cyan, vệt đuôi 3 điểm | Chớp nhỏ + 3 tia lửa cyan | Railspike: đạn kéo vệt thẳng xuyên |
| Nova | Quả cầu plasma 10px, nhân sáng, bay **vòng cung** (chỉ hình ảnh, điểm chạm & thời gian bay giữ nguyên) | Vòng nổ cam theo **đúng bán kính AoE thật** + 6 tia lửa + vết cháy sàn mờ 1s | Cluster: các bom con nhỏ |
| Lance | Tia liên tục (như trên). Arc: tia zigzag nối các mục tiêu chain | Điểm chạm sáng | Tia tắt ngay khi tháp mất mục tiêu |
| Beacon | Xung trường, đường nối buff | — | Cryo: bông tuyết nhỏ rơi trong vùng |
| EMP boss | Vòng đỏ nạp → sóng đỏ lan | Tháp bị trúng có tia điện đỏ | Nháy màn hình đỏ **rất nhẹ 1 lần** (có thể tắt bằng "Giảm hiệu ứng") |
| Tiến hoá | Cột sáng + vòng lục giác nở | — | 0.6s |

**Giới hạn:**

- tối đa ~250 mảnh VFX cùng lúc (pool cố định);
- vượt thì bỏ hiệu ứng **cũ nhất** (không bao giờ ảnh hưởng gameplay);
- rung màn hình chỉ khi boss nổ / EMP, biên độ ≤ 4px;
- tuỳ chọn **"Giảm hiệu ứng"** trong Settings (tắt rung, giảm hạt 50%).

---

## 9. HUD trong trận

```
┌──────────────────────────────────────────────────────────────────────┐
│ [♥ ▮▮▮▮▮▮▯ 18/20] [◈ 130] [≋ WAVE 5/12 · 0:07 ▶▶Sớm]  [☾ Đêm 0:20]  [x2][❚❚]│
│                                                         ┌──────────┐ │
│                                                         │[hình Pulse]│ │ ← thẻ tháp: hình tháp
│              (chiến trường)                             │ PULSE  ◈100│ │   thật, tên, giá;
│                                                         ├──────────┤ │   thiếu tiền: giá đỏ +
│                                                         │[hình Nova] │ │   tối; khoá: ổ khoá
│                                                         └──────────┘ │
│ ┌─[chân dung]─ PULSE · T2/T1 ─────────────────────────────────────┐ │
│ │ ⚔12 ⏱2.0/s ◎150 ✈   │ [Rapid ●●○ 70◈] [Penetr ●○○ 70◈] [Sensor 🔒] │ [Bán +70] │
│ │ Đã đầu tư 240        │  xem trước: "Tốc bắn 2.6/s (+0.6)"  Tiến hoá: … │           │
│ └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**Thanh trên:**

- **HP** có icon + thanh;
- **tiền** có icon;
- **wave** có số + đếm ngược + nút "Bắt đầu sớm (+thưởng)";
- **trạng thái map**: ngày/đêm (Delta), cổng sắp đổi (Prism);
- **x1/x2** và **tạm dừng** là nút icon.

**Thẻ tháp:** hình tháp thật (render từ cùng sprite), tên, giá. Có 4 trạng thái: đủ tiền / thiếu tiền / đang chọn / khoá.

**Panel tháp** giữ cơ chế dock dưới, tự lên trên khi cần:

- chân dung tháp;
- chỉ số hiện tại bằng icon;
- **3 nhánh** dạng thẻ: pip bậc, giá, lý do khoá;
- **xem trước khi chạm 1 lần**: hiện chỉ số sẽ thay đổi; chạm lần 2 hoặc nút Mua thì mua (giống nút Bán hiện có);
- thông tin tiến hoá;
- **Bán + số tiền hoàn**.

Luật main + secondary **giữ nguyên**: chỉ đọc `UpgradeRules`.

**Phản hồi:**

| Sự kiện | Phản hồi |
|---|---|
| Thiếu tiền | chip tiền lắc + đỏ, toast |
| Đặt sai chỗ | bóng tháp đỏ + X (đã có, vẽ đẹp lại) |
| Xây xong | tháp "rơi" xuống + bụi |
| Nâng cấp | vòng sáng + bộ phận mới bật ra |
| Bán | tháp tan thành mảnh + số tiền bay lên |
| Hết wave | băng "WAVE HOÀN THÀNH" |
| Thành tựu | toast có huy hiệu |
| Thắng / Thua | màn kết quả có hoạt ảnh tiêu đề + số liệu đếm lên |

---

## 10. Âm thanh

- Viết lại `tools/audio_gen/gen_audio.gd` để tổng hợp bộ SFX mới, hợp không khí sci-fi. Mọi âm thanh đều **tự tạo, không dùng asset ngoài**:

  | Nhóm | Âm thanh |
  |---|---|
  | Pulse | "pew" kép ngắn |
  | Nova | nạp + "thump" trầm |
  | Lance | tiếng ù laser (loop khi bắn) |
  | Beacon | xung hum nhẹ |
  | Trúng đòn | trúng kim loại, trúng khiên (âm thuỷ tinh) |
  | Chết | nổ nhỏ |
  | Boss | còi báo boss, EMP nạp + phóng |
  | UI | click / hover / lỗi (thiếu tiền) |
  | Xây, nâng cấp, tiến hoá | âm riêng cho từng loại |

- Giữ `SfxLimiter` (giới hạn số âm cùng loại) và cài đặt Music/SFX hiện có.
- Thêm biến thiên cao độ ±5% để bớt lặp.
- Nhạc nền: có thể làm thêm 1 vòng lặp "combat" và chuyển mềm khi vào trận. Đây là **phần tuỳ chọn**, chất lượng nhạc tổng hợp bằng code có giới hạn.

---

## 11. Chiến lược tạo asset (nói thẳng về giới hạn)

**Tôi không có công cụ tạo ảnh (image generation) trong môi trường này.** Chiến lược khả thi nhất:

1. **Sprite vector tự vẽ dạng SVG** (`assets/art/**/*.svg`):
   - mỗi bộ phận tháp/quái là 1 file, tô gradient, có mép sáng và bóng đổ;
   - Godot import SVG thành texture (kích thước gốc ~128–256px cho tháp, 64–128px cho quái, sau đó scale);
   - tất cả do tôi tự vẽ cho dự án nên **bản quyền thuộc dự án**.

   Ảnh `docs/reforged_concepts/concept_sheet.png` là bằng chứng chất lượng có thể đạt: nó được vẽ đúng bằng cách này.
2. **Texture glow/hạt** (chấm mềm, vệt, tia lửa) tạo bằng script Godot `tools/gen_vfx_textures.gd` thành PNG nhỏ (≤ 64px).
3. **Hoạt ảnh** làm bằng biến đổi các lớp sprite (xoay, dịch, scale, alpha) + `Tween`. Không dùng sprite sheet nhiều frame, nên nhẹ và sắc nét ở mọi độ phân giải.
4. **Shader**: tối đa 2 shader canvas đơn giản, đều có phương án dự phòng không dùng shader:
   - cuộn chevron đường đi;
   - méo/nhiễu cho Phantom.
5. **Font**: 2 font OFL từ Google Fonts (cần bạn đồng ý tải).
6. Ghi nguồn và giấy phép trong `docs/ASSET_SOURCES.md`.

**Kỳ vọng thực tế:** kết quả sẽ là đồ hoạ vector 2D phong cách sci-fi gọn, có khối, ánh sáng và hoạt ảnh, đẹp hơn hẳn bản hiện tại. Nhưng đây **không phải tranh vẽ tay của hoạ sĩ chuyên nghiệp**.

Khi báo cáo, tôi sẽ không gọi đây là "artwork hoàn thiện cấp thương mại". Nếu sau này bạn có hoạ sĩ hoặc sprite riêng, kiến trúc lớp `TowerVisual`/`EnemyVisual` cho phép thay từng file SVG/PNG mà không sửa code.

---

## 12. Hiệu năng mobile

- **Terrain** vẽ 1 lần (static `SubViewport` → texture), không vẽ lại mỗi frame.
- **Sprite** dùng chung texture: tháp và quái là các `Sprite2D` với texture dùng chung (batching tốt trên GL Compatibility).
- **Glow:** additive sprite nhỏ, **không** dùng `WorldEnvironment` glow hay bloom toàn màn.
- **VFX:** pool cố định ~250 phần tử, có ngân sách theo frame; không có `GPUParticles2D` (dễ lỗi trên GL Compatibility mobile). Nếu cần thì dùng `CPUParticles2D` ít hạt.
- **Quái** vẫn giữ cơ chế giảm tần suất vẽ lại (`_redraw_accum`). Phần chuyển động bằng sprite transform rẻ hơn `_draw`.
- **Đo đạc:** thêm kịch bản **stress test headless** (L9 boss + wave đông, x2) đo thời gian frame trung bình/tối đa và số node/VFX trên desktop.

  **Lưu ý:** số đo desktop **không đại diện cho điện thoại**. Tôi sẽ không khẳng định "mượt trên Android" khi chưa test trên máy thật.
- **Dung lượng:** SVG/PNG nhỏ, font ~1 MB, nên APK tăng ước tính < 3 MB.

---

## 13. Bảo toàn gameplay (cam kết)

**Không sửa:**

- `data/**/*.tres` (chỉ số, giá, wave);
- `MatchController` logic, `UpgradeRules`, `PlacementRules`, `WaveManager`, `MatchEconomy`;
- tiến trình, định dạng file lưu.

**Chỉ thêm, có ghi chép:**

- 1–3 **signal chỉ dành cho trình bày**, ví dụ:
  - `enemy_hit(enemy, amount, kind)` (để phân biệt trúng khiên/giáp);
  - `enemy_healed`;
  - `tower_disabled_changed`.
- `tower.gd`/`enemy.gd` bỏ phần `_draw()` vẽ hình, chuyển sang node con hình ảnh. Biến trạng thái gameplay không đổi.
- Màu `def.color` trong `.tres` **không sửa**. Màu hiển thị mới lấy từ bảng `VisualPalette` (theo id tháp/quái).

**Kiểm chứng sau mỗi stage:**

- toàn bộ test hiện có (113+) phải pass;
- thêm **test "golden"**: chạy mô phỏng cố định cho cả 9 màn bằng SimBot, so sánh kết quả (HP còn lại, tiền, số quái giết) **trước/sau overhaul phải giống hệt**. Đây là bằng chứng gameplay không đổi;
- test mở file save cũ (0.7.0) vẫn đọc được.

---

## 14. Kế hoạch triển khai (mỗi stage dừng chờ duyệt)

| Stage | Nội dung | Kiểm chứng | Ước lượng |
|---|---|---|---|
| **B** | Design system: `VisualPalette`, `HexButton`/`HexPanel`/`StatChip`/`Toast`, font, bộ icon, `ScreenTransition`. **Menu chính** (logo, nền động, CHƠI). **Chiến dịch** (tab vùng, thẻ màn, ảnh thu nhỏ từ MapDef). Áp style mới cho Research/Thử thách/Settings | Test điều hướng + back; ảnh chụp 4 tỉ lệ màn hình (16:9, 19.5:9, 20:9 tai thỏ, 4:3); song ngữ EN/VI không tràn chữ | lớn |
| **C** | Terrain/đường/decor cho 3 map, ngày-đêm, cổng Prism, căn cứ. 4 tháp × bậc/nhánh/tiến hoá, idle/bắn/giật, tầm bắn, chọn | Golden test; ảnh chụp từng map; ảnh mọi biến thể tháp (sheet) | lớn |
| **D** | 10 quái + Shard + boss 3 pha; đạn từng tháp/nhánh; trúng/chết/trạng thái; EMP; tiến hoá | Golden test; stress test headless; sheet quái; ảnh chụp boss từng pha | lớn |
| **E** | HUD mới, thẻ tháp, panel tháp (xem trước nâng cấp), toast/phản hồi, màn kết quả, âm thanh mới, "Giảm hiệu ứng" | Test HUD/panel (cập nhật test UI nếu tên node đổi, logic test giữ nguyên); ảnh 4 tỉ lệ; EN/VI | trung bình–lớn |
| **F** | Hồi quy toàn bộ: test suite, golden 9 màn, save cũ, chạm, stress test, build APK **0.8.0** + apksigner, cài lên máy thật nếu bạn cắm máy | Báo cáo thật, ghi rõ phần chưa kiểm chứng | trung bình |

Phiên bản: **0.8.0** (versionCode 8), cùng khoá ký, nên **cài đè được và giữ tiến trình** của bản 0.7.0.

---

## 15. Cần bạn quyết định khi duyệt

1. **Duyệt hướng nghệ thuật** (bảng màu, ý tưởng lục giác, concept sheet).
2. **Cho phép tải 2 font OFL** (Chakra Petch + Be Vietnam Pro, ~1 MB, từ Google Fonts).
3. Đồng ý đổi **màu hiển thị**: Lance hồng → tím, tiền vàng → cam. Chỉ là màu hiển thị, dữ liệu gameplay không đổi.
4. Đồng ý **không thêm hệ thống sao** mà dùng ✓ / ★ flawless / thanh HP tốt nhất. Hệ thống sao là cơ chế tiến trình mới, ngoài phạm vi "không đổi gameplay".
5. Đồng ý Combat Lab chỉ mở bằng **nhấn giữ số phiên bản trong bản debug**.
