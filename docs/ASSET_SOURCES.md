# Nguồn & giấy phép asset (Iron Redoubt)

| Asset | Đường dẫn | Nguồn | Giấy phép |
|---|---|---|---|
| Chakra Petch (Bold, SemiBold) | `assets/fonts/ChakraPetch-*.ttf` | Google Fonts (github.com/google/fonts, `ofl/chakrapetch`), tải ngày 2026-11-12 | SIL Open Font License 1.1, xem `assets/fonts/ChakraPetch-OFL.txt` |
| Be Vietnam Pro (Regular, SemiBold) | `assets/fonts/BeVietnamPro-*.ttf` | Google Fonts (github.com/google/fonts, `ofl/bevietnampro`), tải ngày 2026-11-12 | SIL Open Font License 1.1, xem `assets/fonts/BeVietnamPro-OFL.txt` |
| Icon UI (play, back, gear, lock, cores…) | `assets/ui/icons/*.svg` | Tự vẽ cho dự án (SVG viết tay) | Thuộc dự án |
| Sprite tháp / quái (vector) | `assets/art/**/*.svg` | Tự vẽ cho dự án, theo concept Stage A | Thuộc dự án |
| Concept sheet | `docs/reforged_concepts/` | Tự vẽ (SVG → Godot render) | Thuộc dự án |
| SFX / nhạc | `audio/**` | Kenney (kenney.nl) + vitalezzz (opengameart.org), qua `tools/audio_import.py`; chi tiết ở `audio/LICENSES.md` | CC0 |

**Ghi chú về font:**

- Cả 2 font hỗ trợ đầy đủ các ký tự tiếng Việt game đang dùng. Đã kiểm tra bằng script: mọi ký tự ngoài ASCII trong `i18n/translations.csv` đều có glyph; chỉ thiếu "✓", và UI đã thay ký tự này bằng icon vẽ.
- Giấy phép OFL cho phép đóng gói font vào game, kể cả game thương mại. Không được bán riêng file font.
- File TTF có kèm thông tin bản quyền/giấy phép trong metadata. Bản `.txt` giấy phép nằm cạnh font trong repo.
