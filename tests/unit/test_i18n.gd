extends TestCase
## Vietnamese / English language support: every translatable string has a Vietnamese entry,
## format placeholders survive translation, and the language setting switches the locale.

const FMT := "%(?:\\d*\\.?\\d*[dsf]|%)"


func _csv() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://i18n/translations.csv", FileAccess.READ)
	f.get_csv_line() # header
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			out[row[0]] = row[1]
	return out


func _code_keys() -> Array[String]:
	var keys: Array[String] = []
	var rx := RegEx.new()
	rx.compile("I18n\\.[tf]\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	for dir in ["res://core", "res://gameplay", "res://campaign", "res://ui"]:
		_scan(dir, rx, keys)
	return keys


func _scan(dir: String, rx: RegEx, keys: Array[String]) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			for m in rx.search_all(FileAccess.get_file_as_string(dir + "/" + f)):
				var k := m.get_string(1).replace("\\n", "\n")
				if not keys.has(k):
					keys.append(k)
	for sub in d.get_directories():
		_scan(dir + "/" + sub, rx, keys)


func test_every_code_string_has_vietnamese() -> void:
	var table := _csv()
	var missing: Array[String] = []
	for k in _code_keys():
		if not table.has(k):
			missing.append(k)
	eq(missing.size(), 0, "missing translations: %s" % str(missing))


func test_every_data_string_has_vietnamese() -> void:
	var table := _csv()
	var missing: Array[String] = []
	for t in all_real_towers():
		for s in [t.display_name, t.role]:
			if not table.has(s): missing.append(s)
		for b in t.branches:
			for s in [b.display_name, b.description, b.evolution.display_name, b.evolution.description]:
				if not table.has(s): missing.append(s)
			for tier in b.tiers:
				for s in [tier.display_name, tier.description]:
					if not table.has(s): missing.append(s)
	var c: CampaignDef = load("res://data/campaign.tres")
	for l in c.levels:
		for s in [l.display_name, l.objective, l.map.display_name]:
			if not table.has(s): missing.append(s)
		for w in l.waves:
			for g in w.groups:
				if not table.has(g.enemy.display_name): missing.append(g.enemy.display_name)
	for r in c.research:
		for s in [r.display_name, r.description]:
			if not table.has(s): missing.append(s)
	for a in c.achievements:
		for s in [a.display_name, a.description]:
			if not table.has(s): missing.append(s)
	for ch in c.daily_pool + c.weekly_pool:
		for s in [ch.display_name, ch.description]:
			if not table.has(s): missing.append(s)
	eq(missing.size(), 0, "missing data translations: %s" % str(missing))


func test_placeholders_preserved() -> void:
	var rx := RegEx.new()
	rx.compile(FMT)
	var table := _csv()
	var bad: Array[String] = []
	for k in table:
		var a: Array = rx.search_all(k).map(func(m: RegExMatch) -> String: return m.get_string())
		var b: Array = rx.search_all(table[k]).map(func(m: RegExMatch) -> String: return m.get_string())
		a.sort()
		b.sort()
		if a != b:
			bad.append(k)
	eq(bad.size(), 0, "placeholder mismatch: %s" % str(bad))


func test_locale_switch_translates() -> void:
	I18n.apply("vi")
	eq(I18n.t("Settings"), "Cài đặt")
	eq(I18n.f("Wave %d cleared  +%d", [3, 40]), "Hoàn thành wave 3  +40")
	eq(I18n.t("Pulse"), "Xung Kích")
	I18n.apply("en")
	eq(I18n.t("Settings"), "Settings")
	eq(I18n.resolve("vi"), "vi")
	eq(I18n.resolve("en"), "en")
	check(I18n.resolve("auto") in ["en", "vi"], "auto resolves to a supported language")
	var s := GameSettings.new()
	s.language = "fr"
	s.clamp_values()
	eq(s.language, "auto", "unknown language falls back to auto")
	TranslationServer.set_locale("en")


func test_translation_csv_rows_have_exactly_two_columns() -> void:
	# An unquoted comma inside a text splits the row: its key no longer matches and the text stays English.
	var f := FileAccess.open("res://i18n/translations.csv", FileAccess.READ)
	var line_no := 0
	var bad: Array = []
	while not f.eof_reached():
		var row := f.get_csv_line()
		line_no += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != 2:
			bad.append("%d: %s" % [line_no, row[0].substr(0, 50)])
	eq(bad.size(), 0, "malformed rows (quote texts that contain commas): %s" % str(bad))


## 2026-11-19: English is the default whatever the device language; Vietnamese only when picked.
func test_default_language_is_english() -> void:
	eq(I18n.resolve("auto"), "en")
	eq(I18n.resolve(""), "en")
	eq(I18n.resolve("vi"), "vi")
	eq(GameSettings.new().language, "auto", "a fresh settings file starts on the default")


## 2026-11-19: the web "sharp graphics" choice persists (default off = lighter rendering).
func test_sharp_graphics_setting_round_trip() -> void:
	var s := GameSettings.new()
	eq(s.sharp_graphics, false, "off by default")
	s.sharp_graphics = true
	var path := "user://test_settings_sharp.cfg"
	s.save(path)
	var t := GameSettings.new()
	t.load_from(path)
	eq(t.sharp_graphics, true, "saved and loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## CrazyGames: an untouched language setting follows the player's locale (vi -> Vietnamese, else English).
func test_platform_locale_only_drives_auto() -> void:
	eq(I18n.from_locale("vi-VN"), "vi")
	eq(I18n.from_locale("en-US"), "en")
	eq(I18n.from_locale("fr-FR"), "en", "unsupported -> English")
	I18n.platform_locale = "vi"
	eq(I18n.resolve("auto"), "vi", "CrazyGames + Vietnamese locale")
	eq(I18n.resolve("en"), "en", "a player's own pick always wins")
	I18n.platform_locale = ""
	eq(I18n.resolve("auto"), "en", "everywhere else: English")
