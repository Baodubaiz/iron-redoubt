# Iron Redoubt — Thêm nội dung chỉ bằng dữ liệu

Mục tiêu: muốn thêm thông số, hiệu ứng, trùm hay loại sát thương thì **chỉ thêm dữ liệu**, không sửa code.

Có thể làm theo 2 cách:
- sửa bảng trong `tools/author_data.gd` rồi chạy lệnh dưới (khuyên dùng, vì file `.tres` được sinh lại đúng định dạng);
- mở thẳng file `.tres` trong Godot editor.

```bash
godot --headless --path . -s res://tools/author_data.gd
```

Sau khi đổi chữ hiển thị: chạy `python tools/i18n/extract_keys.py`, thêm bản dịch vào `i18n/translations.csv`, rồi chạy `godot --headless --path . --import`.

## 1. Thông số — `data/stats/catalog.tres` (StatDef)

Mọi khoá thông số của tháp và quái đều có một dòng trong danh mục: `id`, nhãn hiển thị, đơn vị, có phải % không, có hiện trong UI không, cách gộp khi 2 nhánh cùng đặt (lấy lớn nhất / hoặc / cộng / nhân / ghi đè).

- Panel nâng cấp tháp **tự hiện** thông số mới có `shown = true`, kèm nhãn lấy từ danh mục.
- Test `test_every_tower_stat_key_is_in_the_catalog` báo lỗi nếu nâng cấp dùng một khoá chưa đăng ký. Nhờ vậy gõ sai tên thông số sẽ bị phát hiện ngay.

## 2. Hiệu ứng — `data/effects/<id>.tres` (EffectDef)

Một hiệu ứng là các **mảnh** ghép lại trong `components`:

| Mảnh (lên quái) | Ý nghĩa |
|---|---|
| `speed_mult` | nhân tốc độ (0.7 = chậm 30%) |
| `damage_taken` | nhân sát thương phải nhận (1.2 = +20%) |
| `armor_add` | cộng giáp (âm = bào giáp) |
| `dot_dps` + `dot_type` | sát thương mỗi giây theo loại (kinetic / explosive / energy / true) |
| `regen_frac` | hồi % máu mỗi giây |
| `heal_mult` | nhân lượng máu được hồi |
| `untargetable` | tháp không nhắm được (sát thương lan vẫn trúng) |
| `immune` | miễn mọi sát thương |
| `resist_type` + `resist_amount` | kháng một loại sát thương |
| `stop` | đứng yên (trùm bỏ qua) |

| Mảnh (lên tháp) | Ý nghĩa |
|---|---|
| `fire_rate_mult` | nhân tốc nạp đạn |
| `range_mult` | nhân tầm bắn |
| `damage_mult` | nhân sát thương |
| `disabled` | không bắn được |

Các trường còn lại:
- `target`: quái hoặc tháp.
- `duration`: thời lượng.
- `stacking`: làm mới / giữ mạnh nhất / cộng tầng, kèm `max_stacks`.
- `affects_bosses`: có tác dụng lên trùm không.
- `color`, `icon`, `display_name`, `description`: phục vụ giao diện.

**Ví dụ có sẵn:** `poison.tres` (Độc) gồm `dot_dps 4`, loại `true`, 4 giây, cộng tầng tối đa 5. File này không cần một dòng code nào; test `test_data_only_effect_poison_on_a_tower` chứng minh điều đó.

**Gắn hiệu ứng vào tháp:** trong `stats` của một bậc nâng cấp, thêm `"on_hit_effects": ["poison"]`.

**Thưởng sát thương theo nhãn:** thêm `"tag_mult": {"armored": 1.5}`. Các nhãn có sẵn là `flying`, `boss`, `stealth`, `shielded`, `armored`; ngoài ra quái có thể tự khai báo thêm trong `EnemyDef.tags`, ví dụ `["mechanical"]`.

Các hiệu ứng `builtin = true` (Làm chậm, Cháy, Đóng băng, EMP...) đã được liệt kê trong dữ liệu để giao diện và Bách Khoa dùng, nhưng luật của chúng vẫn nằm trong code vì có các quy tắc riêng như combo.

## 3. Trùm — `EnemyDef.boss_skills` (BossSkillDef) + `boss_passives`

Mỗi kỹ năng gồm:
- `action`: hành động.
- `min_phase` / `max_phase`: pha mà kỹ năng được dùng.
- `interval`: chu kỳ.
- `telegraph`: thời gian báo trước.
- `phase_interval_mult`: hệ số chu kỳ theo pha, ví dụ `{3: 0.5}` = nhanh gấp đôi ở pha 3.
- `label`: chữ cảnh báo trên thanh máu trùm.
- `params`: tham số riêng của hành động.

Luật luân phiên: trong mỗi pha, các kỹ năng hợp lệ thay phiên nhau dùng; khi vào pha mới, trùm mở màn bằng kỹ năng mới nhất của pha đó.

**Hành động chung**, dùng cho trùm mới mà không cần code:
- `effect_area`: `{effect, radius, on: allies|self|towers, duration}` — gắn một EffectDef lên đồng minh, lên chính nó hoặc lên tháp trong bán kính.
- `summon`: `{enemy: đường dẫn .tres, count, spacing}`.
- `heal_area`: `{radius, frac, self}`.

**Hành động riêng đã có:** shell, sprint, hangar, cloak, adapt, jam, bulwark, blink, static, capacitor, submerge, revive, decoy, prism.

**Nội tại** (`boss_passives`):
- `overload`: tăng tốc vĩnh viễn.
- `overdrive`: hộ tống chạy nhanh hơn, trùm tự hồi máu.
- `aura_effect`: liên tục gắn một EffectDef lên đồng minh xung quanh.

Test `test_data_only_boss` dựng một trùm hoàn toàn bằng dữ liệu (làm yếu tháp → triệu hồi) và chạy được.

Cự Thạch vẫn dùng code cũ vì có nhịp thời gian riêng (EMP nửa chu kỳ, vỡ mảnh khi chết). Các tham số của nó vẫn nằm trong dữ liệu.

## 4. Loại sát thương — `data/damage/catalog.tres` (DamageTypeDef)

Mỗi loại gồm: hệ số với khiên (Năng lượng = 2), có bỏ qua giáp không (Chuẩn), phần sát thương luôn xuyên qua giáp (25%), màu.

Thêm một loại mới = thêm một dòng vào bảng; tháp và hiệu ứng tham chiếu nó bằng `id`.

## Khi nào vẫn phải sửa code

Chỉ khi cần một **kiểu hành vi hoàn toàn mới** mà chưa mảnh, hành động hay nội tại nào làm được, ví dụ quái đi xuyên tường hay tháp di chuyển được. Khi đó thêm **một** loại mảnh hoặc hành động mới, rồi mọi nội dung sau lại dùng nó bằng dữ liệu.

## 5. Độ khó theo công thức (không cần bot) — `core/difficulty_model.gd`

- **Điểm độ khó** của mỗi màn: 1,0 = thắng sát nút. Công thức đã được hiệu chỉnh trên 40 màn đã kiểm bằng bot.
- **Cách tính:**
  - Sức ép của quái = máu × giáp × khiên × tốc độ × `threat_mult`.
  - Sức đánh tối đa của người chơi = tiền có được × hiệu suất trần của tháp đã sở hữu × độ phủ của bản đồ.
  - Có thêm hệ số cho từng cơ chế bản đồ (2 lối vào, đêm, cổng, nút quá tải) và cho việc đã có Nghiên cứu.
- **Không phụ thuộc từng tháp:** thêm tháp mới chỉ cần qua test trần hạng.
- **Thêm quái mới:** khai báo `threat_mult` cho nó trong bảng `THREAT` của `tools/author_data.gd`. Ví dụ: bay 1,2, tàng hình 1,3, bay + tàng hình 1,5, trùm 1,3–1,4.
- **Xem nhanh:** chạy lệnh dưới. Dưới 0,7 là có thể quá dễ, trên 1,5 là có thể quá khó.

```bash
godot --headless --path . -s res://tools/difficulty_report.gd
```

- **Hàng rào:** `tests/unit/test_difficulty_model.gd` báo lỗi nếu màn nào ra ngoài khoảng 0,4–1,9.
- **Giới hạn:** công thức chỉ gần đúng (sai khoảng ±25%). Màn trùm thường bị chấm dễ hơn thực tế, vì độ khó nằm ở kỹ năng trùm. Thỉnh thoảng vẫn nên kiểm mẫu bằng bot và bằng người chơi thật.

## 6. Nút độ khó mỗi màn — chỉ tăng số lượng quái

- `LevelDef.difficulty` (bảng `DIFFICULTY` trong `tools/author_data.gd`): nhân **số lượng** quái thường khi trận bắt đầu, khoảng cách ra quái chia √d. Chỉ số quái (máu, giáp, tốc độ) **không bao giờ đổi**; trùm không bị nhân.
- **Giới hạn đông quái:** tối đa 100 quái ra trong mỗi 25 giây (đo trên PC: 138 quái ≈ 16,5 ms/khung, 313 quái ≈ 27 ms/khung). Đợt nào vượt sẽ được giãn ra (cùng số quái, đợt dài hơn).
- **Mục tiêu:** chỉ dùng tháp C/B/A thì thắng sát nút, còn lại **5–10% máu căn cứ**, để có lý do cày tháp S/SS.
- **Chỉnh nhanh (vài phút):**

```bash
godot --headless --path . -s res://tools/sim/auto_tune.gd -- --levels=1,2,3
godot --headless --path . -s res://tools/sim/quick_check.gd -- --levels=1,2,3
```

`auto_tune` tự thử tối đa 5 lần mỗi màn rồi in `FINAL <màn> <d>`; chép `d` vào bảng `DIFFICULTY`. `quick_check` chạy 1 trận mỗi màn để xác nhận thắng/thua.

## 7. Kho Tháp (tháp S / SS) — mảnh thiết kế + Lõi

- **Giá theo hạng** (`data/stats/rarity.tres`, bảng `SHOP_RANKS` trong `tools/author_data.gd`): `shard_cost` (số mảnh) và `core_price` (giá Lõi). Hiện tại S = 100 mảnh + 150 Lõi; SS = 250 mảnh + 400 Lõi (để dành).
- **Thêm tháp S / SS mới:** chỉ cần tạo `data/towers/<id>.tres` với `rarity = S` hoặc `SS`. `author_data` tự đưa nó vào `CampaignDef.shop_towers`, vào danh sách tháp của mọi màn, và vào bể rơi mảnh. Không phải sửa code.
- **Rơi mảnh khi đánh trùm** (`LevelDef.shard_drop`, bảng `SHARD_DROPS`):
  - Màn 5 mỗi khu vực: 30% rơi 1–2 mảnh; 3% "nổ to" 5–8 mảnh.
  - Màn 10 mỗi khu vực: 45% rơi 1–3 mảnh; 5% "nổ to" 8–12 mảnh.
  - Tháp nhận mảnh là ngẫu nhiên trong các tháp S/SS chưa đủ mảnh, người chơi không chọn được. Lần thắng đầu cũng không chắc rơi.
  - **Bảo hiểm:** `CampaignDef.shard_pity` = 8 lần thắng liên tiếp không rơi thì lần sau chắc chắn rơi.
- **Quảng cáo:** mỗi lượt = `ad_shards` (1) mảnh cho tháp người chơi chọn, tối đa `ad_daily_cap` (25) lượt/ngày.
  - Chưa tích hợp AdMob: `core/ad_service.gd` đang ở chế độ thử (xem là nhận thưởng ngay). Khi tích hợp, chỉ sửa `show_rewarded()`.
- **Mua:** đủ mảnh + đủ Lõi → mảnh bị dùng hết, trả Lõi, sở hữu tháp vĩnh viễn.
- **Lưu dữ liệu:** mảnh là sổ sự kiện giống Lõi (`profile.data["shards"]`), nên gửi trùng kết quả trận không nhận mảnh 2 lần và gộp 2 bản lưu không mất mảnh.

## 8. Vật phẩm tiêu hao (Kho Tháp) — mua bằng Lõi, dùng trong trận

- **Dữ liệu:** `ConsumableDef` (`data/defs/consumable_def.gd`), tác giả trong `tools/author_data.gd` hàm `_consumables()`, gắn vào `CampaignDef.consumables`.
- **Mua:** tốn Lõi, không giới hạn số lần mua, mỗi lần +1 vào kho (`ProgressionModel.buy_item`).
- **Dùng:** tối đa 1 lần mỗi loại mỗi trận, không hồi chiêu — hết thì phải mua lại (`ProgressionModel.use_item_block_reason` / `use_item`). Lưu bằng sổ sự kiện giống mảnh thiết kế nên không bị dùng/mua trùng khi gộp lưu.
- **Hiệu ứng:** `MatchController.apply_consumable()` — 4 loại (`ConsumableDef.Kind`): AIRSTRIKE (nổ quanh quái trâu máu nhất), HEAL (hồi máu căn cứ), FREEZE (đứng im quái thường, trùm chỉ khựng), HASTE (mọi tháp bắn nhanh hơn một khoảng thời gian).
- **Thêm vật phẩm mới:** chỉ thêm 1 dòng dữ liệu vào `_consumables()`; nếu là hiệu ứng mới hoàn toàn mới (không phải 4 loại trên) thì thêm 1 nhánh `match item.kind` trong `apply_consumable()`.
- **Giao diện:** mua trong Kho Tháp (mục "Vật phẩm"), dùng qua hàng nút góc dưới trái màn chơi (HUD).
