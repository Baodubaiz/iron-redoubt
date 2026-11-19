extends TestCase
## Armory: S/SS towers from blueprint shards (random boss drops, 1 per ad) + a Cores price, all data-driven.

var campaign: CampaignDef


func before_each() -> void:
	campaign = load("res://data/campaign.tres")


func _model() -> ProgressionModel:
	var pm := ProgressionModel.new(campaign, MemoryStore.new())
	pm.load_profile()
	return pm


func _boss_level() -> int:
	for i in range(campaign.levels.size()):
		if campaign.levels[i].shard_drop != null:
			return i
	return -1


func _win(i: int) -> Dictionary:
	var l := campaign.levels[i]
	return {"level_id": String(l.id), "won": true, "base_hp": l.base_hp, "max_base_hp": l.base_hp, "damage_taken": 1,
		"duration": 400.0, "tower_types": [], "kills_by_enemy": {}, "evolved_types": [], "interactions": [],
		"early_starts": 0, "boss_kill_seconds": [], "challenge_id": "", "challenge_period": ""}


func test_shop_comes_from_the_rank_data() -> void:
	check(campaign.shop_towers.size() >= 2, "S towers listed in the Armory")
	for t in campaign.shop_towers:
		check(campaign.shard_cost(t) > 0 and campaign.core_price(t) > 0, "%s has shards + price from its rank" % t.id)
	eq(campaign.shard_cost(real_tower("storm")), 100)
	eq(campaign.shard_cost(real_tower("pulse")), 0, "level towers are not sold")
	var bosses := 0
	for l in campaign.levels:
		if l.shard_drop != null:
			bosses += 1
	eq(bosses, 8, "every boss level (5th / 10th of each region) drops shards")


func test_boss_drops_are_random_with_pity() -> void:
	var pm := _model()
	var i := _boss_level()
	var drops := 0
	var max_dry := 0
	var dry := 0
	var towers := {}
	for k in range(200):
		var rep := pm.submit_match(_win(i), "boss%d" % k)
		var sh: Dictionary = rep["shards"]
		if sh.is_empty():
			dry += 1
			max_dry = maxi(max_dry, dry)
		else:
			drops += 1
			dry = 0
			towers[sh["tower"]] = true
			check(int(sh["amount"]) >= 1, "a drop gives at least 1 shard")
	check(drops > 20 and drops < 180, "drops are random, not every win (%d / 200)" % drops)
	check(max_dry <= campaign.shard_pity, "pity: never more than %d dry wins in a row (%d)" % [campaign.shard_pity, max_dry])
	check(towers.size() >= 2, "the tower is random")


func test_same_match_never_drops_twice() -> void:
	var pm := _model()
	var i := _boss_level()
	pm.submit_match(_win(i), "same")
	var total := 0
	for t in campaign.shop_towers:
		total += pm.profile.shards(t.id)
	pm.submit_match(_win(i), "same")
	var again := 0
	for t in campaign.shop_towers:
		again += pm.profile.shards(t.id)
	eq(again, total, "duplicate submission pays no shards")


func test_ads_give_one_shard_for_the_chosen_tower_with_a_daily_cap() -> void:
	var pm := _model()
	var storm := campaign.find_shop_tower(&"storm")
	var day := 1_800_000_000
	for k in range(campaign.ad_daily_cap):
		check(pm.grant_ad_reward(storm, day), "ad %d" % k)
	eq(pm.profile.shards(&"storm"), campaign.ad_daily_cap * campaign.ad_shards)
	eq(pm.profile.shards(&"chronos"), 0, "only the chosen tower")
	check(not pm.grant_ad_reward(storm, day), "daily cap reached")
	check(pm.grant_ad_reward(storm, day + 86400), "next day works again")


func test_buy_needs_all_shards_and_cores_then_owns_the_tower() -> void:
	var pm := _model()
	var storm := campaign.find_shop_tower(&"storm")
	check(pm.shop_block_reason(storm) != "", "no shards: cannot buy")
	pm.profile.add_shards("test", &"storm", campaign.shard_cost(storm))
	check(pm.shop_block_reason(storm) != "", "no Cores: cannot buy")
	pm.profile.credit("test", campaign.core_price(storm))
	eq(pm.shop_block_reason(storm), "")
	check(pm.buy_tower(storm), "bought")
	check(pm.profile.owns_tower(&"storm"), "owned")
	eq(pm.profile.cores(), 0, "price paid")
	eq(pm.profile.shards(&"storm"), 0, "shards used up")
	check(not pm.buy_tower(storm), "cannot buy twice")
	check(pm.build_modifiers().allows_tower(storm), "owned S tower can be built in levels")
	check(campaign.levels[0].available_towers.has(storm), "S towers are offered in every level once owned")


func test_shards_survive_save_and_merge() -> void:
	var pm := _model()
	pm.profile.add_shards("a", &"storm", 7)
	pm.profile.data["shard_pity"] = 3
	var clean: Dictionary = Profile.sanitize(JSON.parse_string(JSON.stringify(pm.profile.data)), campaign.starting_towers)["data"]
	eq(Profile.new(clean).shards(&"storm"), 7)
	eq(int(clean["shard_pity"]), 3)
	var other := Profile.fresh(campaign.starting_towers)
	other["shards"]["b"] = ["storm", 2]
	var m := Profile.merge(clean, Profile.sanitize(other, campaign.starting_towers)["data"])
	eq(Profile.new(m).shards(&"storm"), 9, "merge = union of shard events")
	var old := Profile.fresh(campaign.starting_towers)
	old.erase("shards")
	old.erase("shard_pity")
	eq(Profile.new(Profile.sanitize(old, campaign.starting_towers)["data"]).shards(&"storm"), 0, "old saves load")


## 2026-11-19: ad provider by build. Outside the CrazyGames web build the SDK bridge is a silent no-op.
func test_ad_providers() -> void:
	check(not CrazyGamesSdk.is_target(), "desktop test run is not the CrazyGames build")
	CrazyGamesSdk.gameplay_start() # no-ops, must not error
	CrazyGamesSdk.gameplay_stop()
	CrazyGamesSdk.happytime()
	AdService.force_provider = "test"
	var got := []
	AdService.show_rewarded(func(ok: bool) -> void: got.append(ok))
	eq(got, [true], "test provider rewards at once")
	check(AdService.is_available(), "test ads available")
	AdService.force_provider = "none"
	got.clear()
	AdService.show_rewarded(func(ok: bool) -> void: got.append(ok))
	eq(got, [false], "no ad SDK: no reward")
	check(not AdService.is_available(), "no ads offered")
	var done := []
	AdService.show_midgame(func() -> void: done.append(1))
	eq(done, [1], "a break ad never blocks leaving the results")
	AdService.force_provider = ""
