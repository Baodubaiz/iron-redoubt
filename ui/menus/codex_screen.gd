extends Control
## Codex: everything in the game at a glance — towers, enemies, bosses, effects, damage types &
## combos, regions. Every number is read from the game data (TowerDef / EnemyDef / BossSkillDef /
## EffectDef / DamageCatalog / CampaignDef), so balance changes and new content show up here by
## themselves. Enemies and bosses stay hidden ("???") until the player has met them in a match.

const P = preload("res://ui/style/visual_palette.gd")
const TOWERS := [&"pulse", &"trap", &"spotter", &"nova", &"beacon", &"venom", &"lance", &"sniper", &"bastion", &"storm", &"chronos"]
## ⚠ DEV: set false to restore production lock behaviour (enemies hidden until met in battle).
const CODEX_DEV_UNLOCK_ALL := false

const ENEMIES := [&"drone", &"dart", &"swarmling", &"brute", &"plated", &"glider", &"escort", &"phantom", &"aegis", &"sludge",
	&"mender", &"shade", &"sprinter", &"jammer", &"prismling", &"diver",
	&"disruptor", &"static_crawler", &"wraith", &"vanguard", &"rallier", &"cloaker", &"mender_elite"]
const TABS := [["towers", "Towers", "upgrade"], ["enemies", "Enemies", "enemy"], ["bosses", "Bosses", "boss"],
	["effects", "Effects", "bolt"], ["damage", "Combat", "star"], ["regions", "Regions", "campaign"]]
const ENEMY_TIP := {
	&"drone": "Basic walker. Anything kills it -- except Venom, which it resists specifically (it's a machine).",
	&"dart": "Very fast and fragile. Pulse and slows catch it.",
	&"swarmling": "Tiny and comes in floods. Nova splash shreds them.",
	&"brute": "Reactive armor: hits under 30 damage deal only 40%. Use big single shots (Marksman, Lance Overcharge) or poison/burn. Resists Plasma (Marker).",
	&"plated": "Heavy armor. Lance, Venom (poison ignores armor entirely) or Siege shred.",
	&"aegis": "Regenerating shield. Energy (Lance, Arc) breaks it twice as fast. Periodically jams nearby towers' fire rate.",
	&"glider": "Flies over the lane. Pulse, Lance or Flak Nova; Sensor can ground it. Periodically shortens nearby towers' range.",
	&"phantom": "Stealthed until revealed. Beacon light or Sensor; splash still hits. -30% from plain Kinetic hits (Pulse, Sniper) -- a tower's own %-damage bonus (e.g. Beacon's buff) counters this, armor pierce does not.",
	&"mender": "Heals nearby allies. Kill it first; Burn halves its healing.",
	&"escort": "Shields allies around it. Kill it first.",
	&"sludge": "Regenerates quickly. Poison and burst damage beat it. Resists Energy (Lance, Storm) specifically.",
	&"shade": "Flying and stealthed. Needs a Beacon and an anti-air tower.",
	&"sprinter": "Bursts of speed. Traps and slows hold it.",
	&"jammer": "Jams towers near it. Outrange it or protect towers with a Bastion.",
	&"prismling": "Resists one damage type at a time. Mix your towers.",
	&"diver": "Dives out of reach. Hit hard while it surfaces.",
	# ---- new special-skill enemies (2026-11-17) ----
	&"disruptor": "Jams towers in 180 px — they attack at 40% speed for 4 s. Kill it fast or spread towers wide.",
	&"static_crawler": "Heavy tank that fires a static field shrinking nearby tower range by 45% for 4.5 s. Long-range towers (Sniper) suffer least.",
	&"wraith": "Stealthy sprinter that bursts an EMP disabling all towers in 150 px for 2 s. Beacon reveals it; splash still hits.",
	&"vanguard": "Armored frontliner. Shields every ally in 200 px with 130 HP overshield for 6 s. Burst-AOE (Nova, Pulse) shreds shields fast.",
	&"rallier": "Grants nearby allies +35% speed for 4 s every 7 s. Kill it first — freeze/slow counters its haste burst.",
	&"cloaker": "Cloaks itself and all allies in 160 px for 5 s. Beacon or Sensor reveals the pack; splash still hits.",
	&"mender_elite": "Pulses a heal burst restoring 15% max HP to allies in 180 px, plus a passive trickle. Burn halves all healing received.",
}
const SKILL := { ## action -> [name, description]
	&"shell": ["Carapace", "Hardens its shell: a temporary shield worth part of its HP."],
	&"sprint": ["Overclock", "Sprints at high speed for a few seconds."],
	&"hangar": ["Hangar", "Launches flying fighters from its deck."],
	&"cloak": ["Cloak field", "Cloaks itself and nearby escorts. Beacons and Sensors reveal them."],
	&"adapt": ["Adaptive plating", "Swaps between thick armor and a regenerating energy shield."],
	&"jam": ["Jammer", "Towers nearby recharge at half speed."],
	&"bulwark": ["Bulwark", "Shields every ally around it."],
	&"blink": ["Rift blink", "Jumps forward along the lane (never right into the core)."],
	&"static": ["Static field", "Towers nearby lose range."],
	&"capacitor": ["Capacitor", "Every hit on it is capped."],
	&"submerge": ["Submerge", "Dives: cannot be targeted or damaged for a moment."],
	&"revive": ["Revive", "Raises recently killed enemies near it."],
	&"decoy": ["Mirror decoys", "Sends fragile copies ahead of it."],
	&"prism": ["Prismatic shield", "Resists one damage type at a time, cycling."],
	&"effect_area": ["Effect field", "Spreads an effect around it."],
	&"summon": ["Summon", "Calls in minions."],
	&"heal_area": ["Mending wave", "Heals allies around it."],
}
const PASSIVE := {
	"overload": ["Overload", "Permanently faster."],
	"overdrive": ["Overdrive", "Escorts around it run faster and it regenerates."],
	"aura_effect": ["Aura", "Allies around it are empowered."],
}
const MONOLITH := [[1, "Summon", "Calls in Swarmlings."], [2, "EMP", "Towers near it stop attacking."],
	[3, "Fracture", "Faster; splits into shards when it dies."]]
## Each combo keeps its own icon (2026-11-16, user: "mỗi hiệu ứng và thông số có icon riêng") --
## this list used to render all 6 with the same "star", told apart only by name.
const COMBOS := [["Grounded", "air", "Sensor marks hit a flier: it is grounded and ground towers can hit it."],
	["Conductive", "node", "Arc chains jump extra times between chilled (slowed or frozen) enemies."],
	["Shatter", "frost", "Explosive hits on a frozen enemy deal bonus damage."],
	["Meltdown", "sun", "Burn deals +50% to enemies whose armor is heavily shredded."],
	["Inferno", "flame", "Burning enemies explode when they die."],
	["Cascade", "restart", "Nova shells detonate a second time."]]
const TOWER_TYPE := {&"pulse": Damage.Type.KINETIC, &"nova": Damage.Type.EXPLOSIVE, &"lance": Damage.Type.ENERGY,
	&"trap": Damage.Type.EXPLOSIVE, &"venom": Damage.Type.POISON, &"spotter": Damage.Type.PLASMA, &"sniper": Damage.Type.KINETIC,
	&"storm": Damage.Type.ENERGY}
## Every damage type gets its own icon (2026-11-16, user: "mỗi hiệu ứng và thông số có icon riêng")
## -- this list used to show every type with the same "bolt" icon, told apart only by colour.
const DAMAGE_ICON := {&"kinetic": "fast", &"explosive": "blast", &"energy": "bolt", &"poison": "poison",
	&"plasma": "plasma", &"true": "true_dmg"}

var _tab := "towers"
var _tabs := {}
var _list: VBoxContainer
var _detail: VBoxContainer
var _seen := {}
var _group := ButtonGroup.new()
var _filters: HBoxContainer
const RANKS := [&"C", &"B", &"A", &"S", &"SS"]
var _tower_rank := &"" ## "" = every rank
const TRAITS := [["flying", "Flying"], ["stealth", "Stealth"], ["armored", "Armored"]]
var _enemy_trait := "" ## "" = every trait
var _enemy_unseen_only := false
var reveal_all := false ## dev / screenshots


func _ready() -> void:
	reveal_all = CODEX_DEV_UNLOCK_ALL
	var v := UiKit.screen(self)
	UiKit.header(v, I18n.t("Codex"), func() -> void: SceneRouter.to_menu())
	_load_seen()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var tg := ButtonGroup.new()
	for t in TABS:
		var b := UiKit.button(I18n.t(t[1]).to_upper(), func() -> void: _show_tab(t[0]), Vector2(0, 52), "CardButton", t[2])
		b.name = "Tab_%s" % t[0]
		b.toggle_mode = true
		b.button_group = tg
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.clip_text = true
		tabs.add_child(b)
		_tabs[t[0]] = b
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 8)
	v.add_child(_filters)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var left := DragScroll.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	left.add_child(_list)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CardAccent"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var rs := DragScroll.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(rs)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	rs.add_child(_detail)
	_show_tab("towers")


func on_back() -> void:
	SceneRouter.to_menu()


func _load_seen() -> void:
	var pf: Profile = Progression.model.profile
	for id in pf.lifetime_set("seen_enemies"):
		_seen[StringName(id)] = true
	for k in pf.data["lifetime"]["counters"]: # older saves: anything already killed counts as seen
		if String(k).begins_with("kills_") and int(pf.data["lifetime"]["counters"][k]) > 0:
			_seen[StringName(String(k).substr(6))] = true


func is_seen(id: StringName) -> bool:
	return reveal_all or _seen.has(id)


# ================================================================= tabs

func _show_tab(tab: String) -> void:
	_tab = tab
	(_tabs[tab] as Button).button_pressed = true # through the ButtonGroup: releases the other tabs
	_build_filters()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_group = ButtonGroup.new()
	var first: Button = null
	for entry in _entries(tab):
		var b := _entry_button(entry)
		_list.add_child(b)
		if first == null:
			first = b
	UiKit.slide_in(_list.get_children(), Vector2(-30, 0), 0.03)
	if first != null:
		first.button_pressed = true
		first.pressed.emit()


## Rank chips for Towers, trait chips + an "unseen only" toggle for Enemies; hidden elsewhere.
func _build_filters() -> void:
	for c in _filters.get_children():
		_filters.remove_child(c)
		c.queue_free()
	if _tab == "towers":
		var tg := ButtonGroup.new()
		var ranks: Array[StringName] = [&""]
		ranks.append_array(RANKS)
		for rk in ranks:
			var b := UiKit.button(I18n.t("All") if rk == &"" else String(rk), func() -> void:
				_tower_rank = rk
				_show_tab(_tab), Vector2(0, 40), "CardButton")
			b.name = "Filter_%s" % ("all" if rk == &"" else String(rk))
			b.toggle_mode = true
			b.button_group = tg
			b.button_pressed = _tower_rank == rk
			b.add_theme_font_size_override("font_size", 13)
			_filters.add_child(b)
	elif _tab == "enemies":
		var tg := ButtonGroup.new()
		var traits_: Array = [["", "All"]]
		traits_.append_array(TRAITS)
		for tr in traits_:
			var b := UiKit.button(I18n.t(tr[1]), func() -> void:
				_enemy_trait = tr[0]
				_show_tab(_tab), Vector2(0, 40), "CardButton")
			b.name = "Filter_%s" % ("all" if tr[0] == "" else String(tr[0]))
			b.toggle_mode = true
			b.button_group = tg
			b.button_pressed = _enemy_trait == tr[0]
			b.add_theme_font_size_override("font_size", 13)
			_filters.add_child(b)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_filters.add_child(spacer)
		var unseen := UiKit.button(I18n.t("Unseen only"), func() -> void:
			_enemy_unseen_only = not _enemy_unseen_only
			_show_tab(_tab), Vector2(0, 40), "CardButton")
		unseen.name = "Filter_unseen"
		unseen.toggle_mode = true
		unseen.button_pressed = _enemy_unseen_only
		unseen.add_theme_font_size_override("font_size", 13)
		_filters.add_child(unseen)


## [key, title, icon texture, color, locked, show callable]
func _entries(tab: String) -> Array:
	var out: Array = []
	match tab:
		"towers":
			for id in TOWERS:
				var d: TowerDef = load("res://data/towers/%s.tres" % id)
				if _tower_rank != &"" and d.rarity != _tower_rank:
					continue
				out.append([String(id), I18n.t(d.display_name), UiKit.tower_icon(id), P.tower_color(id), false,
					func() -> void: _tower(d)])
		"enemies":
			for id in ENEMIES:
				var d: EnemyDef = load("res://data/enemies/%s.tres" % id)
				var locked := not is_seen(id)
				if _enemy_unseen_only and not locked:
					continue
				if _enemy_trait == "flying" and not d.flying:
					continue
				if _enemy_trait == "stealth" and not d.stealth:
					continue
				if _enemy_trait == "armored" and d.armor <= 0.0:
					continue
				out.append([String(id), "???" if locked else I18n.t(d.display_name), EnemyVisual.body_tex(id), d.color,
					locked, func() -> void: _enemy(d, locked)])
		"bosses":
			for b in _bosses():
				var d: EnemyDef = b[0]
				var locked := not is_seen(d.id)
				out.append([String(d.id), "???" if locked else I18n.t(d.display_name), EnemyVisual.body_tex(d.id),
					P.RED, locked, func() -> void: _boss(d, b[1], locked)])
		"effects":
			for e in _effects():
				out.append([String(e.id), I18n.t(e.display_name), UiKit.icon(_icon_name(e.icon)), e.color, false,
					func() -> void: _effect(e)])
		"damage":
			var defs := Damage.defs()
			for i in range(defs.size()):
				var d: DamageTypeDef = defs[i]
				out.append(["dmg_%s" % d.id, I18n.t(d.display_name), UiKit.icon(DAMAGE_ICON.get(d.id, "bolt")), d.color, false,
					func() -> void: _damage(i, d)])
			for c in COMBOS:
				out.append(["combo_%s" % c[0], I18n.t(c[0]), UiKit.icon(c[1]), P.ORANGE, false, func() -> void: _combo(c)])
		"regions":
			for rg in [&"circuit", &"delta", &"prism", &"rift"]:
				var look := P.map_look(rg)
				out.append([String(rg), I18n.t(look["name"]), UiKit.icon("campaign"), look["accent"], false,
					func() -> void: _region(rg)])
	return out


func _entry_button(entry: Array) -> Button:
	var b := Button.new()
	b.name = "Entry_%s" % entry[0]
	b.theme_type_variation = "CardButton"
	b.toggle_mode = true
	b.button_group = _group
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(UiKit.click)
	b.pressed.connect(entry[5])
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	if _tab == "towers":
		var rk := UiKit.rank_badge((load("res://data/towers/%s.tres" % entry[0]) as TowerDef).rarity, 13)
		rk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(rk)
	var ic := UiKit.tex(entry[2], 40, Color(0, 0, 0, 0.85) if entry[4] else Color.WHITE)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if entry[2] == UiKit.icon("star") or entry[2] == UiKit.icon("campaign") or _tab in ["effects", "damage"]:
		ic.modulate = entry[3]
	h.add_child(ic)
	var l := UiKit.label(entry[1].to_upper(), 16, P.TEXT_FAINT if entry[4] else P.TEXT)
	l.add_theme_font_override("font", UiKit.font("head", 1))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_FILL
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return b


# ================================================================= detail pages

func _clear_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()


func _head(title: String, color: Color, sub: String, preview: Control = null) -> void:
	_clear_detail()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_detail.add_child(h)
	if preview != null:
		h.add_child(preview)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UiKit.title(title.to_upper(), 28, color, 3))
	if sub != "":
		var s := UiKit.label(sub, 15, P.TEXT_DIM)
		s.custom_minimum_size = Vector2(240, 0)
		v.add_child(s)


func _section(text: String) -> void:
	var l := UiKit.title(text.to_upper(), 16, P.CYAN, 2)
	_detail.add_child(l)


func _chips(items: Array) -> void: ## [[icon, text, color], ...]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_detail.add_child(flow)
	for it in items:
		flow.add_child(UiKit.chip(it[0], it[1], it[2], 15))


func _para(text: String, color: Color = P.TEXT) -> void:
	var l := UiKit.label(text, 15, color)
	l.custom_minimum_size = Vector2(240, 0)
	_detail.add_child(l)


func _row(name_text: String, desc: String, color: Color = P.TEXT) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_detail.add_child(v)
	v.add_child(UiKit.title(name_text, 16, color, 1))
	var d := UiKit.label(desc, 14, P.TEXT_DIM)
	d.custom_minimum_size = Vector2(240, 0)
	v.add_child(d)


static func _num(v: float) -> String:
	return str(int(v)) if absf(v - roundf(v)) < 0.001 else "%.1f" % v


func _tower(d: TowerDef) -> void:
	var pv := CodexPreview.new()
	pv.tower = d
	_head(I18n.t(d.display_name), P.tower_color(d.id), I18n.t(d.role), pv)
	var rk := RarityCatalog.get_default().find(d.rarity)
	if rk != null:
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 8)
		_detail.add_child(rr)
		rr.add_child(UiKit.rank_badge(d.rarity, 16))
		var rl := UiKit.label("%s — %s" % [I18n.t(rk.display_name), I18n.t(rk.description)], 14, rk.color)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(rl)
	var items: Array = [["credits", str(d.cost), P.ORANGE]]
	if Progression.model.campaign.find_shop_tower(d.id) != null:
		items.insert(0, ["shard", I18n.f("Armory: %d shards + %d Cores", [Progression.model.campaign.shard_cost(d),
			Progression.model.campaign.core_price(d)]), P.VIOLET])
	elif not _obtainable(d.id):
		items.insert(0, ["lock", I18n.t("Coming in a future update"), P.VIOLET])
	if d.damage > 0.0:
		items.append(["bolt", "%s %s" % [I18n.t("Damage"), _num(d.damage)], P.TEXT])
		items.append(["clock", "%s %s/s" % [I18n.t("Fire rate"), _num(d.fire_rate)], P.TEXT])
	items.append(["range", "%s %s" % [I18n.t("Range"), _num(d.attack_range)], P.TEXT])
	if d.splash_radius > 0.0:
		items.append(["star", "%s %s" % [I18n.t("Splash"), _num(d.splash_radius)], P.TEXT])
	if d.armor_pen > 0.0:
		items.append(["upgrade", "%s %s" % [I18n.t("Armor pen"), _num(d.armor_pen)], P.TEXT])
	if TOWER_TYPE.has(d.id):
		var td := Damage.type_def(TOWER_TYPE[d.id])
		items.append(["bolt", I18n.t(td.display_name), td.color])
	if d.attack_mode != TowerDef.AttackMode.AURA:
		items.append(["air", I18n.t("Hits air") if d.can_target_air else I18n.t("Ground only"), P.GREEN if d.can_target_air else P.TEXT_FAINT])
	_chips(items)
	_section(I18n.t("Branches"))
	_para(I18n.t("Each tower takes one main branch (tier 3 + evolution) and one secondary branch (up to tier 2)."), P.TEXT_DIM)
	for b in d.branches:
		var title := I18n.t(b.display_name)
		if b.requires_research:
			title += "  · " + I18n.t("Research")
		_row(title, I18n.t(b.description), P.tower_color(d.id))
		for i in range(b.tiers.size()):
			var t: TierDef = b.tiers[i]
			_row("   %s  (%d)" % [I18n.t(t.display_name), t.cost], "   " + I18n.t(t.description), P.TEXT)
		if b.evolution != null:
			_row("   ★ %s  (%d)" % [I18n.t(b.evolution.display_name), b.evolution.cost], "   " + I18n.t(b.evolution.description), P.ORANGE)


func _enemy(d: EnemyDef, locked: bool) -> void:
	var pv := CodexPreview.new()
	pv.enemy = d
	pv.silhouette = locked
	if locked:
		_head("???", P.TEXT_FAINT, I18n.t("Not met yet. Meet it in a battle to unlock this entry."), pv)
		return
	_head(I18n.t(d.display_name), d.color, I18n.t(ENEMY_TIP.get(d.id, "")), pv)
	_chips(_enemy_chips(d))


func _enemy_chips(d: EnemyDef) -> Array:
	var items: Array = [["heart", "%s %s" % [I18n.t("HP"), _num(d.max_hp)], P.GREEN],
		["fast", "%s %s" % [I18n.t("Speed"), _num(d.speed)], P.TEXT]]
	if d.armor > 0.0:
		items.append(["upgrade", "%s %s" % [I18n.t("Armor"), _num(d.armor)], P.TEXT])
	if d.shield > 0.0:
		items.append(["heart", "%s %s" % [I18n.t("Shield"), _num(d.shield)], P.BLUE])
	if d.flying:
		items.append(["air", I18n.t("Flying"), P.GREEN])
	if d.stealth:
		items.append(["night", I18n.t("Stealth"), P.VIOLET])
	if d.heal_amount > 0.0:
		items.append(["heart", I18n.t("Heals allies"), P.GREEN])
	var display_bounty := maxi(1, int(round(d.bounty * 0.90))) if d.bounty > 0 else 0
	items.append(["credits", "%s %d" % [I18n.t("Bounty"), display_bounty], P.ORANGE])
	items.append(["heart", "%s %d" % [I18n.t("Base damage"), d.base_damage], P.RED])
	return items


func _boss(d: EnemyDef, where: String, locked: bool) -> void:
	var pv := CodexPreview.new()
	pv.enemy = d
	pv.silhouette = locked
	if locked:
		_head("???", P.TEXT_FAINT, "%s\n%s" % [where, I18n.t("Not met yet. Meet it in a battle to unlock this entry.")], pv)
		return
	_head(I18n.t(d.display_name), P.RED, where, pv)
	var items := _enemy_chips(d)
	items.insert(0, ["boss", "%d %s" % [d.boss_phase_count, I18n.t("phases")], P.RED])
	_chips(items)
	_section(I18n.t("Skills"))
	if d.boss_skills.is_empty(): # Monolith (legacy kit)
		for m in MONOLITH:
			_row("%s %s — %s" % [I18n.t("Phase"), ["", "I", "II", "III"][m[0]], I18n.t(m[1])], I18n.t(m[2]), P.ORANGE)
	for s in d.boss_skills:
		var info: Array = SKILL.get(s.action, [String(s.action), ""])
		var phases := "I" if s.min_phase == 1 else ("II" if s.min_phase == 2 else "III")
		if s.max_phase > s.min_phase and s.max_phase <= d.boss_phase_count:
			phases += "–" + ["", "I", "II", "III"][mini(s.max_phase, d.boss_phase_count)]
		var desc := I18n.t(info[1]) + "  " + I18n.f("Every %s s, warning %s s.", [_num(s.interval), _num(s.telegraph)])
		_row("%s %s — %s" % [I18n.t("Phase"), phases, I18n.t(s.label if s.label != "" else info[0])], desc, P.ORANGE)
	for pv2 in d.boss_passives:
		var info2: Array = PASSIVE.get(String(pv2.get("kind", "")), [String(pv2.get("kind", "")), ""])
		_row("%s %s — %s" % [I18n.t("Phase"), ["", "I", "II", "III"][clampi(int(pv2.get("min_phase", 1)), 1, 3)], I18n.t(info2[0])],
			I18n.t(info2[1]), P.ORANGE)


func _effect(e: EffectDef) -> void:
	var icon := UiKit.tex(UiKit.icon(_icon_name(e.icon)), 72, e.color)
	_head(I18n.t(e.display_name), e.color, I18n.t(e.description), icon)
	_chips([["enemy" if e.target == EffectDef.Target.ENEMY else "upgrade",
		I18n.t("On enemies") if e.target == EffectDef.Target.ENEMY else I18n.t("On towers"), P.TEXT]])


func _damage(i: int, d: DamageTypeDef) -> void:
	_head(I18n.t(d.display_name), d.color, "", UiKit.tex(UiKit.icon(DAMAGE_ICON.get(d.id, "bolt")), 72, d.color))
	var items: Array = []
	if i == Damage.Type.TRUE:
		items.append(["upgrade", I18n.t("Always ignores armor"), P.GREEN])
	elif d.ignores_armor:
		items.append(["upgrade", I18n.t("Ignores armor, unless the enemy specifically resists it"), P.GREEN])
	else:
		items.append(["upgrade", I18n.f("At least %d%% passes armor", int(round(d.min_through * 100.0))), P.TEXT])
	if d.ignores_shield:
		items.append(["heart", I18n.t("Skips shields entirely"), P.BLUE])
	else:
		items.append(["heart", I18n.f("x%s vs shields", _num(d.vs_shield)), P.BLUE if d.vs_shield > 1.0 else P.TEXT])
	if d.flat_pierce > 0.0:
		items.append(["upgrade", I18n.f("+%d innate armor pierce", int(d.flat_pierce)), P.ORANGE])
	_chips(items)
	var users: Array[String] = []
	for id in TOWER_TYPE:
		if TOWER_TYPE[id] == i:
			users.append(I18n.t((load("res://data/towers/%s.tres" % id) as TowerDef).display_name))
	if i == Damage.Type.TRUE:
		users.append(I18n.t("Burn"))
	_para(I18n.t("Dealt by:") + " " + ", ".join(users), P.TEXT_DIM)
	_para(I18n.t("Armor subtracts from every hit; armor-piercing lowers it. Shields absorb damage before HP."), P.TEXT_DIM)
	if i == Damage.Type.POISON:
		_para(I18n.t("A few enemies are built to resist poison specifically (e.g. machines) -- it does less to them even with 0 regular armor."), P.TEXT_DIM)
	elif i == Damage.Type.PLASMA:
		_para(I18n.t("Some heavily-built enemies resist Plasma specifically, even without regular armor."), P.TEXT_DIM)
	elif i == Damage.Type.ENERGY:
		_para(I18n.t("A few enemies (e.g. goo) resist Energy specifically, even without regular armor."), P.TEXT_DIM)


func _combo(c: Array) -> void:
	_head(I18n.t(c[0]), P.ORANGE, I18n.t(c[2]), UiKit.tex(UiKit.icon(c[1]), 72, P.ORANGE))


func _region(rg: StringName) -> void:
	var look := P.map_look(rg)
	var levels: Array[LevelDef] = []
	for l in Progression.model.campaign.levels:
		if l.map.region_id() == rg:
			levels.append(l)
	var thumb := MapThumbnail.new()
	thumb.map = levels[0].map
	thumb.custom_minimum_size = Vector2(240, 135)
	_head(I18n.t(look["name"]), look["accent"], I18n.t(look["desc"]), thumb)
	var nodes := false
	var night := false
	var gates := false
	var two := false
	for l in levels:
		nodes = nodes or l.map.range_bonus_zones.size() > 0
		night = night or l.map.day_night
		gates = gates or l.map.dynamic_routes
		two = two or (l.map.routes.size() > 1 and not l.map.dynamic_routes)
	_chips([["campaign", I18n.f("Levels %d–%d", [levels[0].level_number, levels[levels.size() - 1].level_number]), look["accent"]]])
	_section(I18n.t("Map mechanics"))
	if nodes:
		_row(I18n.t("Overload nodes"), I18n.t("Towers built on a node get extra range."), P.ORANGE)
	if night:
		_row(I18n.t("Day/Night"), I18n.t("Night waves shorten tower range unless a Beacon lights the tower."), P.BLUE)
	if gates:
		_row(I18n.t("Shifting gates"), I18n.t("Gates switch which lane is open; the switch is announced a wave ahead."), P.VIOLET)
	if two:
		_row(I18n.t("2 entrances"), I18n.t("Enemies come from more than one side."), P.GREEN)
	_section(I18n.t("Bosses"))
	for b in _bosses():
		if String(b[1]).begins_with(I18n.t(look["name"])):
			var d: EnemyDef = b[0]
			_row("???" if not is_seen(d.id) else I18n.t(d.display_name), b[1], P.RED)


# ================================================================= data helpers

## Starting tower or granted by a campaign level (S towers have no unlock yet).
func _obtainable(id: StringName) -> bool:
	var c: CampaignDef = Progression.model.campaign
	if c.starting_towers.has(id):
		return true
	for l in c.levels:
		if l.unlock_tower_on_start != null and l.unlock_tower_on_start.id == id:
			return true
		if l.unlock_tower_on_clear != null and l.unlock_tower_on_clear.id == id:
			return true
	return false


## [[EnemyDef, "Region · level N"], ...] in campaign order.
func _bosses() -> Array:
	var out: Array = []
	var seen := {}
	for l in Progression.model.campaign.levels:
		for w in l.waves:
			if not w.is_boss:
				continue
			for g in w.groups:
				if g.enemy != null and g.enemy.is_boss and not seen.has(g.enemy.id):
					seen[g.enemy.id] = true
					var look := P.map_look(l.map.region_id())
					out.append([g.enemy, "%s · %s" % [I18n.t(look["name"]), I18n.f("Level %d", l.level_number)]])
	return out


func _effects() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://data/effects")
	if dir == null:
		return out
	var names: Array = []
	for f in dir.get_files():
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres"):
			names.append(n.trim_suffix(".tres"))
	names.sort()
	for n in names:
		var e := EffectDef.by_id(n)
		if e != null and e.builtin: # data-only effects show up once content uses them
			out.append(e)
	return out


static func _icon_name(n: String) -> String:
	return n if ResourceLoader.exists("res://assets/ui/icons/%s.svg" % n) else "bolt"


# ================================================================= animated preview

class CodexPreview extends Control:
	var tower: TowerDef
	var enemy: EnemyDef
	var silhouette := false
	var _host: Node2D
	var _look: TowerArt.Look
	var _e: Enemy
	var _t := 0.0
	var _stage := -1
	var _skill := 0

	func _init() -> void:
		custom_minimum_size = Vector2(200, 200)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_host = Node2D.new()
		add_child(_host)
		if tower != null:
			_look = TowerArt.Look.new()
			_look.def = tower
			_host.scale = Vector2(2.4, 2.4)
			_host.draw.connect(func() -> void: TowerArt.draw(_host, Vector2.ZERO, _look))
		elif enemy != null:
			_e = Enemy.new()
			_e.setup(enemy, RoutePath.new(PackedVector2Array([Vector2(-1000, 0), Vector2(1000, 0)])), 1)
			_e.place_at_progress(1000.0)
			_host.add_child(_e)
			_e.add_child(EnemyVisual.new(_e))
			var reach := enemy.radius * 2.6
			if enemy.is_boss:
				reach = maxf(reach, 120.0)
			_host.scale = Vector2.ONE * clampf(90.0 / reach, 0.35, 3.0)
			if silhouette:
				_host.modulate = Color(0, 0, 0, 0.9)
		resized.connect(func() -> void: _host.position = size * 0.5)
		_host.position = size * 0.5

	func _process(delta: float) -> void:
		_t += delta
		if _look != null: # cycle: base -> each branch at tier 3 -> evolved main branch
			_look.t = _t
			_look.aim = -PI * 0.5 + sin(_t * 0.7) * 1.2
			var stage := int(_t / 2.2) % (tower.branches.size() + 2)
			if stage != _stage:
				_stage = stage
				_look.main_id = &""
				_look.main_tier = 0
				_look.evolved = false
				if stage >= 1 and stage <= tower.branches.size():
					_look.main_id = tower.branches[stage - 1].id
					_look.main_tier = 3
				elif stage == tower.branches.size() + 1:
					_look.main_id = tower.branches[0].id
					_look.main_tier = 3
					_look.evolved = true
			_host.queue_redraw()
		elif _e != null and enemy.is_boss and not silhouette: # loop through its skills' telegraphs
			var skills: Array = []
			if enemy.boss_skills.is_empty():
				skills = [[EnemyAbilities.SUMMON_KIND, {}, 1], [EnemyAbilities.EMP_KIND, {}, 2]]
			else:
				for s in enemy.boss_skills:
					skills.append([int(EnemyAbilities.ACTION_KIND.get(s.action, EnemyAbilities.EFFECT_KIND)), s.params, s.min_phase])
			if _e.telegraph_timer <= 0.0:
				var s: Array = skills[_skill % skills.size()]
				_skill += 1
				_e.boss_phase = mini(int(s[2]), _e.max_boss_phases)
				_e.telegraph_kind = int(s[0])
				_e.telegraph_params = s[1]
				_e.telegraph_total = 1.6
				_e.telegraph_timer = 1.6
			_e.telegraph_timer = maxf(0.0, _e.telegraph_timer - delta * 0.8)
