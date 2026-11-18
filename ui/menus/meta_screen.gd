extends Control
## Daily / weekly challenges and achievements.


func _ready() -> void:
	var v := UiKit.screen(self)
	UiKit.header(v, I18n.t("Challenges & Achievements"), func() -> void: SceneRouter.to_menu())
	var model: ProgressionModel = Progression.model
	var now: int = Progression.now_unix()
	var cur := model.current_challenges(now)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(_challenge_card(I18n.t("Daily"), cur["daily"], cur["daily_key"], cur["daily_done"],
		ChallengeSchedule.seconds_left(now, false)))
	row.add_child(_challenge_card(I18n.t("Weekly"), cur["weekly"], cur["weekly_key"], cur["weekly_done"],
		ChallengeSchedule.seconds_left(now, true)))
	v.add_child(UiKit.label(I18n.t("Schedule uses the device clock (UTC) and can be changed by editing the phone time."), 13, UiKit.MUTED))
	var ah := HBoxContainer.new()
	v.add_child(ah)
	ah.add_child(UiKit.tex(UiKit.icon("trophy"), 26, VisualPalette.ORANGE))
	ah.add_child(UiKit.title(I18n.f("Achievements  %d/%d", [model.profile.data["achievements"].size(), model.campaign.achievements.size()]).to_upper(), 22, UiKit.TEXT, 2))
	var list := UiKit.scroll(v)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	for a in model.campaign.achievements:
		var done: bool = model.profile.data["achievements"].has(String(a.id))
		var card := PanelContainer.new()
		card.theme_type_variation = "CardGood" if done else ""
		card.custom_minimum_size = Vector2(580, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 12)
		card.add_child(ch)
		ch.add_child(UiKit.tex(UiKit.icon("check" if done else "star"), 28, UiKit.GOOD if done else VisualPalette.TEXT_FAINT))
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_theme_constant_override("separation", 0)
		ch.add_child(cv)
		var nl := UiKit.label(I18n.t(a.display_name), 18, UiKit.GOOD if done else UiKit.TEXT)
		nl.add_theme_font_override("font", UiKit.font("head", 1))
		cv.add_child(nl)
		cv.add_child(UiKit.label(I18n.t(a.description), 14, UiKit.MUTED))
		ch.add_child(UiKit.chip("cores", "+%d" % a.cores, UiKit.GOLD, 16))


func _challenge_card(kind: String, c: ChallengeDef, key: String, done: bool, left: int) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardAccent"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)
	if c == null:
		cv.add_child(UiKit.label(I18n.f("%s: none available", kind), 18))
		return card
	var th := HBoxContainer.new()
	cv.add_child(th)
	th.add_child(UiKit.tex(UiKit.icon("trophy"), 26, UiKit.GOLD))
	var tl := UiKit.title("%s — %s" % [kind.to_upper(), I18n.t(c.display_name)], 20, UiKit.TEXT, 1)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	th.add_child(tl)
	th.add_child(UiKit.chip("cores", "+%d" % c.cores, UiKit.GOLD, 16))
	cv.add_child(UiKit.label(I18n.t(c.description), 15, UiKit.MUTED))
	cv.add_child(UiKit.label(I18n.f("Resets in %dh %02dm", [left / 3600, (left % 3600) / 60]), 14, UiKit.MUTED))
	var unlocked := Progression.model.challenge_level_unlocked(c)
	var b := UiKit.button(I18n.t("Completed") if done else (I18n.t("Play").to_upper() if unlocked else I18n.f("Clear %s first", I18n.t(c.level.display_name))),
		func() -> void: SceneRouter.play_challenge(c, key), Vector2(0, 52),
		"PrimaryButton" if (unlocked and not done) else "", "check" if done else ("play" if unlocked else "lock"))
	b.disabled = done or not unlocked
	cv.add_child(b)
	return card


func on_back() -> void:
	SceneRouter.to_menu()
