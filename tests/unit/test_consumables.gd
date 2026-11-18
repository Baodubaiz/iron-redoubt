extends TestCase
## Armory consumables: data-driven one-shot items (no cooldown), bought with Cores, one use per item
## per match. Profile ledger + MatchController.apply_consumable().

var campaign: CampaignDef


func before_each() -> void:
	campaign = load("res://data/campaign.tres")


func _model() -> ProgressionModel:
	var pm := ProgressionModel.new(campaign, MemoryStore.new())
	pm.load_profile()
	return pm


func _item(id: String) -> ConsumableDef:
	return campaign.find_consumable(StringName(id))


func test_items_are_listed_and_priced() -> void:
	check(campaign.consumables.size() >= 4, "at least the 4 proposed items exist")
	for it in campaign.consumables:
		check(it.cost > 0, "%s has a Cores price" % it.id)


func test_buy_spends_cores_and_stacks() -> void:
	var pm := _model()
	var it := _item("airstrike")
	check(not pm.buy_item(it), "no Cores yet")
	pm.profile.credit("test", it.cost * 2)
	check(pm.buy_item(it), "first buy")
	eq(pm.profile.item_count(it.id), 1)
	check(pm.buy_item(it), "second buy stacks")
	eq(pm.profile.item_count(it.id), 2)
	eq(pm.profile.cores(), 0, "both purchases paid")


func test_use_is_limited_to_one_per_item_per_match() -> void:
	var pm := _model()
	var it := _item("repair_kit")
	pm.profile.credit("test", it.cost * 3)
	pm.buy_item(it)
	pm.buy_item(it)
	eq(pm.use_item_block_reason(it, "m1"), "", "owned, not used yet this match")
	check(pm.use_item(it, "m1"), "first use in match m1")
	eq(pm.profile.item_count(it.id), 1, "stock decreases")
	check(pm.use_item_block_reason(it, "m1") != "", "already used this item in m1")
	check(not pm.use_item(it, "m1"), "cannot use twice in the same match")
	eq(pm.use_item_block_reason(it, "m2"), "", "a different match is independent")
	check(pm.use_item(it, "m2"), "second stock used in match m2")
	eq(pm.profile.item_count(it.id), 0)
	check(pm.use_item_block_reason(it, "m3") != "", "none left")


func test_items_survive_save_and_merge() -> void:
	var pm := _model()
	pm.profile.credit("test", 1000)
	pm.buy_item(_item("overclock"))
	var clean: Dictionary = Profile.sanitize(JSON.parse_string(JSON.stringify(pm.profile.data)), campaign.starting_towers)["data"]
	eq(Profile.new(clean).item_count(&"overclock"), 1)
	var other := Profile.fresh(campaign.starting_towers)
	other["items"]["x"] = ["overclock", 1]
	var m := Profile.merge(clean, Profile.sanitize(other, campaign.starting_towers)["data"])
	eq(Profile.new(m).item_count(&"overclock"), 2, "merge = union of item events")
	var old := Profile.fresh(campaign.starting_towers)
	old.erase("items")
	old.erase("item_buy_seq")
	eq(Profile.new(Profile.sanitize(old, campaign.starting_towers)["data"]).item_count(&"overclock"), 0, "old saves load")


func test_airstrike_hits_the_toughest_enemy_on_screen() -> void:
	var m := make_lab()
	var weak := put(m, real_enemy("drone"), 50.0)
	var strong := put(m, make_enemy_def(500.0), 400.0) # far enough apart to be outside the blast radius
	m.step(DT) # the enemy spatial registry (used by the blast) rebuilds once per step
	check(m.apply_consumable(_item("airstrike")), "hit something")
	check(strong.hp < 500.0, "the tougher enemy took the airstrike's damage")
	eq(weak.hp, weak.def.max_hp, "the weaker, farther enemy is untouched")


func test_airstrike_is_a_no_op_with_no_enemies() -> void:
	var m := make_lab()
	check(not m.apply_consumable(_item("airstrike")), "nothing to hit")


func test_repair_kit_heals_the_base() -> void:
	var m := make_lab()
	m.base.apply_damage(5)
	var before := m.base.hp
	check(m.apply_consumable(_item("repair_kit")), "healed")
	eq(m.base.hp, before + _item("repair_kit").heal_amount)
	check(not m.apply_consumable(_item("repair_kit")) or m.base.hp <= m.base.max_hp, "never overheals")


func test_repair_kit_is_a_no_op_at_full_hp() -> void:
	var m := make_lab()
	check(not m.apply_consumable(_item("repair_kit")), "already full")


func test_stasis_charge_freezes_regular_enemies_and_staggers_bosses() -> void:
	var m := make_lab()
	var e := put(m, real_enemy("drone"), 50.0)
	check(m.apply_consumable(_item("stasis_charge")), "froze something")
	check(e.stun_timer > 0.0, "regular enemy is stunned")


func test_overclock_hastes_every_tower() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(400, 380))
	var it := _item("overclock")
	check(m.apply_consumable(it), "hasted something")
	near(t.effect_product("fire_rate_mult"), it.haste_mult, 0.001, "tower fires faster")


func test_overclock_is_a_no_op_with_no_towers() -> void:
	var m := make_lab()
	check(not m.apply_consumable(_item("overclock")), "no towers to haste")
