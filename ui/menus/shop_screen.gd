extends Control
## Armory: S / SS towers. Collect blueprint shards (random boss drops, or 1 per rewarded ad for the tower
## you pick), then buy the tower with Cores. Everything shown comes from CampaignDef.shop_towers + RarityDef.


func _ready() -> void:
	_build()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var v := UiKit.screen(self)
	UiKit.header(v, I18n.t("Armory"), func() -> void: SceneRouter.to_menu())
	var model: ProgressionModel = Progression.model
	v.add_child(UiKit.label(I18n.t("Bosses (levels 5 and 10 of every region) can drop blueprint shards for a random tower. Each ad gives 1 shard for the tower you pick."), 16, UiKit.MUTED))
	v.add_child(UiKit.label(I18n.f("Ads left today: %d / %d", [model.ads_left_today(_now()), model.campaign.ad_daily_cap])
		+ ("   " + I18n.t("(test ads)") if AdService.is_test_mode() else ""), 15, VisualPalette.CYAN))
	var list := UiKit.scroll(v)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	for t in model.campaign.shop_towers:
		grid.add_child(_card(model, t))
	if not model.campaign.consumables.is_empty():
		var head := UiKit.label(I18n.t("Items — buy with Cores, use in a match (no cooldown; one of each per match).").to_upper(), 16, VisualPalette.CYAN)
		list.add_child(head)
		var igrid := GridContainer.new()
		igrid.columns = 2
		igrid.add_theme_constant_override("h_separation", 12)
		igrid.add_theme_constant_override("v_separation", 12)
		igrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(igrid)
		for it in model.campaign.consumables:
			igrid.add_child(_item_card(model, it))


func _card(model: ProgressionModel, t: TowerDef) -> Control:
	var owned := model.profile.owns_tower(t.id)
	var need := model.campaign.shard_cost(t)
	var have := mini(model.profile.shards(t.id), need)
	var buy_reason := model.shop_block_reason(t)
	var card := PanelContainer.new()
	card.name = "Card_%s" % t.id
	card.theme_type_variation = "CardGood" if owned else ("CardAccent" if buy_reason == "" else "")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(520, 230)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	cv.add_child(top)
	top.add_child(UiKit.tex(UiKit.tower_icon(t.id), 56))
	var name_l := UiKit.label(I18n.t(t.display_name).to_upper(), 20, VisualPalette.GREEN if owned else UiKit.TEXT)
	name_l.add_theme_font_override("font", UiKit.font("head", 1))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_l)
	var badge := UiKit.rank_badge(t.rarity, 16)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)
	var desc := UiKit.label(I18n.t(t.role), 14, UiKit.MUTED)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(desc)
	if not owned:
		var bar := ProgressBar.new()
		bar.max_value = need
		bar.value = have
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		var fill := StyleBoxFlat.new()
		fill.bg_color = VisualPalette.VIOLET
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.tex(UiKit.icon("shard"), 22, VisualPalette.VIOLET))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var count := UiKit.label("%d / %d" % [have, need], 16, VisualPalette.VIOLET)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(count)
		cv.add_child(row)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	cv.add_child(btns)
	if owned:
		var ob := UiKit.button(I18n.t("Owned"), func() -> void: pass, Vector2(0, 48), "", "check")
		ob.disabled = true
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(ob)
		return card
	var ad_reason := model.ad_block_reason(t, _now())
	var ad := UiKit.button(I18n.f("Watch ad  +%d", model.campaign.ad_shards) if ad_reason == "" else ad_reason,
		func() -> void: _watch_ad(t), Vector2(0, 48), "", "play")
	ad.name = "Ad"
	ad.disabled = ad_reason != ""
	ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ad.add_theme_font_size_override("font_size", 15)
	btns.add_child(ad)
	var price := model.campaign.core_price(t)
	var buy := UiKit.button(I18n.f("Buy  %d Cores", price) if buy_reason == "" else buy_reason,
		func() -> void:
			if Progression.model.buy_tower(t):
				_build.call_deferred(), Vector2(0, 48), "", "cores" if buy_reason == "" else "lock")
	buy.name = "Buy"
	buy.disabled = buy_reason != ""
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_font_size_override("font_size", 15)
	if buy_reason == "":
		buy.add_theme_color_override("font_color", VisualPalette.ORANGE)
		buy.add_theme_color_override("icon_normal_color", VisualPalette.ORANGE)
	btns.add_child(buy)
	return card


func _item_card(model: ProgressionModel, it: ConsumableDef) -> Control:
	var card := PanelContainer.new()
	card.name = "Item_%s" % it.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(520, 150)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	cv.add_child(top)
	top.add_child(UiKit.tex(UiKit.icon(it.icon), 40, VisualPalette.VIOLET))
	var name_l := UiKit.label(I18n.t(it.display_name).to_upper(), 18, UiKit.TEXT)
	name_l.add_theme_font_override("font", UiKit.font("head", 1))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_l)
	var owned := UiKit.label(I18n.f("Owned: %d", model.profile.item_count(it.id)), 15, VisualPalette.VIOLET)
	owned.autowrap_mode = TextServer.AUTOWRAP_OFF
	owned.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(owned)
	var desc := UiKit.label(I18n.t(it.description), 14, UiKit.MUTED)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(desc)
	var buy := UiKit.button(I18n.f("Buy  +1  (%d Cores)", it.cost), func() -> void:
		if Progression.model.buy_item(it):
			_build.call_deferred(), Vector2(0, 48), "", "cores")
	buy.disabled = model.profile.cores() < it.cost
	buy.add_theme_font_size_override("font_size", 15)
	if not buy.disabled:
		buy.add_theme_color_override("font_color", VisualPalette.ORANGE)
		buy.add_theme_color_override("icon_normal_color", VisualPalette.ORANGE)
	cv.add_child(buy)
	return card


func _watch_ad(t: TowerDef) -> void:
	AdService.show_rewarded(func(ok: bool) -> void:
		if ok and Progression.model.grant_ad_reward(t, _now()):
			_build.call_deferred())


func on_back() -> void:
	SceneRouter.to_menu()
