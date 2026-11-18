class_name ProgressionModel
extends RefCounted
## Campaign + meta progression rules over a Profile and a ProgressionStore.
## Every reward is an idempotent ledger entry, every result submission carries a match id,
## and saves use optimistic concurrency with a monotonic merge on conflict.
## NOTE: results are client-reported. When a real backend exists it must re-validate them
## (see docs/INTEGRATION_NOTES.md); this model is the offline/local authority only.

signal changed

var campaign: CampaignDef
var store: ProgressionStore
var profile: Profile
var pending_save: bool = false
var last_load_error: String = ""
var recovered: bool = false


func _init(c: CampaignDef, s: ProgressionStore) -> void:
	campaign = c
	store = s
	profile = Profile.new(Profile.fresh(c.starting_towers))


func load_profile() -> void:
	var r := store.load_data()
	last_load_error = String(r.get("error", ""))
	var raw: Dictionary = r["data"] if r["ok"] else {}
	var san := Profile.sanitize(raw, campaign.starting_towers)
	recovered = (not r["ok"]) or bool(san["repaired"]) or last_load_error != ""
	profile = Profile.new(san["data"])
	for t in campaign.starting_towers:
		profile.unlock_tower(t)
	changed.emit()


## Saves with optimistic concurrency. On conflict: merge with the remote copy and retry once.
## On failure the data stays in memory and `pending_save` is set so the next save retries.
func save() -> bool:
	var base_rev := int(profile.data["revision"])
	profile.data["revision"] = base_rev + 1
	var r := store.save_data(profile.data, base_rev)
	if not r["ok"] and r["conflict"]:
		var remote := Profile.sanitize(r["remote"], campaign.starting_towers)["data"] as Dictionary
		var merged := Profile.merge(profile.data, remote)
		base_rev = int(remote["revision"])
		merged["revision"] = base_rev + 1
		profile.data = merged
		r = store.save_data(profile.data, base_rev)
	pending_save = not r["ok"]
	if pending_save:
		profile.data["revision"] = base_rev # keep the next attempt's base consistent
	changed.emit()
	return r["ok"]


# ================================================================ campaign

func is_level_unlocked(level: LevelDef) -> bool:
	var i := campaign.level_index(level.id)
	if i <= 0:
		return i == 0
	if profile.is_cleared(level.id):
		return true # a level you already cleared stays playable (older saves: levels were reordered in 0.10)
	return profile.is_cleared(campaign.levels[i - 1].id)


func next_level(level: LevelDef) -> LevelDef:
	var i := campaign.level_index(level.id)
	return campaign.levels[i + 1] if i >= 0 and i + 1 < campaign.levels.size() else null


func unlocks() -> UpgradeRules.Unlocks:
	var u := UpgradeRules.Unlocks.new()
	for r in campaign.research:
		if not profile.has_research(r.id):
			continue
		if r.kind == ResearchDef.Kind.BRANCH_C:
			u.branch_c[r.tower_id] = true
		elif r.kind == ResearchDef.Kind.EVOLUTION:
			u.evolutions[r.tower_id] = true
	return u


func has_wave_preview() -> bool:
	for r in campaign.research:
		if r.kind == ResearchDef.Kind.WAVE_PREVIEW and profile.has_research(r.id):
			return true
	return false


## First start of a level that introduces a counter tower: grant it. Returns the tower if new, else null.
func grant_level_start(level: LevelDef) -> TowerDef:
	if level == null or level.unlock_tower_on_start == null:
		return null
	var t := level.unlock_tower_on_start
	if profile.owns_tower(t.id):
		return null
	profile.unlock_tower(t.id)
	save()
	return t


func build_modifiers(challenge: ChallengeDef = null, period_key: String = "") -> MatchModifiers:
	var m := MatchModifiers.new()
	m.unlocks = unlocks()
	for t in profile.data["towers"]:
		m.owned_towers.append(StringName(t))
	for r in campaign.research:
		if not profile.has_research(r.id):
			continue
		match r.kind:
			ResearchDef.Kind.START_CURRENCY:
				m.start_currency_bonus += int(r.value)
			ResearchDef.Kind.BASE_HP:
				m.base_hp_bonus += int(r.value)
			ResearchDef.Kind.EARLY_BONUS:
				m.early_bonus_multiplier += r.value
	if challenge != null:
		m.banned_towers = challenge.banned_towers.duplicate()
		m.base_hp_cap = challenge.base_hp_cap
		m.currency_multiplier = challenge.currency_multiplier
		m.no_selling = challenge.no_selling
		m.challenge_id = challenge.id
		m.challenge_period = period_key
	return m


# ================================================================ results

## Applies a finished match. Safe to call repeatedly with the same match_id (no double rewards).
## Returns a report for the results screen.
func submit_match(result: Dictionary, match_id: String) -> Dictionary:
	var report := {"duplicate": false, "cores": 0, "first_clear": false, "flawless": false,
		"unlocked_tower": "", "unlocked_level": "", "achievements": [], "challenge_completed": false,
		"shards": {}}
	if match_id == "" or not profile.mark_processed(match_id):
		report["duplicate"] = true
		return report
	var before := profile.cores()
	var level_id := StringName(String(result.get("level_id", "")))
	var idx := campaign.level_index(level_id)
	var level: LevelDef = campaign.levels[idx] if idx >= 0 else null
	var is_challenge := String(result.get("challenge_id", "")) != ""
	var won := bool(result.get("won", false))

	# lifetime statistics
	profile.add_counter("matches", 1)
	var kbe: Dictionary = result.get("kills_by_enemy", {})
	for k in kbe:
		profile.add_counter("kills_" + String(k), int(kbe[k]))
	profile.add_to_set("evolved_types", result.get("evolved_types", []))
	profile.add_to_set("interactions", result.get("interactions", []))
	profile.add_to_set("seen_enemies", result.get("seen_enemies", []))

	if won and level != null and not is_challenge:
		var rec := profile.level_record(level_id).duplicate()
		var first := not bool(rec["cleared"])
		rec["cleared"] = true
		rec["clears"] = int(rec["clears"]) + 1
		rec["best_hp"] = maxi(int(rec["best_hp"]), int(result.get("base_hp", 0)))
		var dur := float(result.get("duration", 0.0))
		rec["best_time"] = dur if float(rec["best_time"]) <= 0.0 else minf(float(rec["best_time"]), dur)
		if int(result.get("damage_taken", 1)) == 0:
			rec["flawless"] = true
		profile.data["levels"][String(level_id)] = rec
		if profile.credit("clear:%s" % level_id, level.cores_first_clear):
			report["first_clear"] = true
			var nl := next_level(level)
			if nl != null:
				report["unlocked_level"] = nl.display_name
		elif not first:
			profile.credit("replay:%s:%s" % [level_id, match_id],
				int(floor(level.cores_first_clear * campaign.replay_reward_fraction)))
		if int(result.get("damage_taken", 1)) == 0 and profile.credit("flawless:%s" % level_id, campaign.flawless_bonus):
			report["flawless"] = true
		if level.unlock_tower_on_clear != null and profile.unlock_tower(level.unlock_tower_on_clear.id):
			report["unlocked_tower"] = level.unlock_tower_on_clear.display_name
		report["shards"] = roll_shards(level, match_id)

	# Defeat (2026-11-18, user): Cores for the waves survived, at the replay rate, so a loss is never wasted
	# but never pays more than winning: first_clear * replay fraction * waves cleared / total waves.
	if not won and level != null and not is_challenge:
		var total := maxi(1, level.waves.size())
		var cleared := clampi(int(result.get("waves_cleared", 0)), 0, total)
		var amount := int(floor(level.cores_first_clear * campaign.replay_reward_fraction * cleared / float(total)))
		if amount > 0 and profile.credit("defeat:%s:%s" % [level_id, match_id], amount):
			report["defeat_waves"] = cleared

	if is_challenge and won:
		var ch := find_challenge(StringName(String(result["challenge_id"])))
		var period := String(result.get("challenge_period", ""))
		var ok_time := ch != null and (ch.max_seconds <= 0.0 or float(result.get("duration", 0.0)) <= ch.max_seconds)
		if ch != null and ok_time and period != "":
			var key := "%s:%s" % [period, ch.id]
			if not profile.data["challenges"].has(key):
				profile.data["challenges"][key] = true
				report["challenge_completed"] = true
			profile.credit("challenge:%s" % key, ch.cores) # claim once per period

	for a in campaign.achievements:
		if profile.data["achievements"].has(String(a.id)):
			continue
		if AchievementRules.is_met(a, result, profile, campaign):
			profile.data["achievements"][String(a.id)] = true
			profile.credit("ach:%s" % a.id, a.cores)
			report["achievements"].append(a.display_name)

	report["cores"] = profile.cores() - before
	save()
	return report


# ================================================================ armory (S / SS towers)

## Shop towers the player does not own and still needs shards for.
func shard_pool() -> Array[TowerDef]:
	var out: Array[TowerDef] = []
	for t in campaign.shop_towers:
		if not profile.owns_tower(t.id) and profile.shards(t.id) < campaign.shard_cost(t):
			out.append(t)
	return out


## Rolls the level's shard drop for one win (deterministic per match id). Tower is random, never chosen.
## Returns {} (nothing) or {"tower": id, "name": display name, "amount": n, "jackpot": bool}.
func roll_shards(level: LevelDef, match_id: String) -> Dictionary:
	var drop := level.shard_drop
	var pool := shard_pool()
	if drop == null or pool.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s" % [match_id, level.id])
	var pity := int(profile.data["shard_pity"])
	var amount := 0
	var jackpot := false
	if rng.randf() < drop.jackpot_chance:
		amount = rng.randi_range(drop.jackpot_min, drop.jackpot_max)
		jackpot = true
	elif rng.randf() < drop.chance or pity >= campaign.shard_pity:
		amount = rng.randi_range(drop.min_shards, drop.max_shards)
	if amount <= 0:
		profile.data["shard_pity"] = pity + 1
		return {}
	profile.data["shard_pity"] = 0
	var t: TowerDef = pool[rng.randi() % pool.size()]
	amount = mini(amount, campaign.shard_cost(t) - profile.shards(t.id))
	profile.add_shards("drop:%s" % match_id, t.id, amount)
	return {"tower": String(t.id), "name": t.display_name, "amount": amount, "jackpot": jackpot}


func ads_watched_today(unix: int) -> int:
	return profile.shard_events("ad:%s:" % ChallengeSchedule.daily_key(unix))


func ads_left_today(unix: int) -> int:
	return maxi(campaign.ad_daily_cap - ads_watched_today(unix), 0)


## Why the player cannot watch an ad for `tower` right now ("" = can).
func ad_block_reason(tower: TowerDef, unix: int) -> String:
	if profile.owns_tower(tower.id):
		return I18n.t("Owned")
	if profile.shards(tower.id) >= campaign.shard_cost(tower):
		return I18n.t("Shards complete")
	if ads_left_today(unix) <= 0:
		return I18n.t("No more ads today")
	return ""


## Reward of one watched ad: shards for the tower the player picked.
func grant_ad_reward(tower: TowerDef, unix: int) -> bool:
	if ad_block_reason(tower, unix) != "":
		return false
	var key := "ad:%s:%d" % [ChallengeSchedule.daily_key(unix), ads_watched_today(unix) + 1]
	var n := mini(campaign.ad_shards, campaign.shard_cost(tower) - profile.shards(tower.id))
	if not profile.add_shards(key, tower.id, n):
		return false
	save()
	return true


func shop_block_reason(tower: TowerDef) -> String:
	if profile.owns_tower(tower.id):
		return I18n.t("Owned")
	var need := campaign.shard_cost(tower) - profile.shards(tower.id)
	if need > 0:
		return I18n.f("Need %d more shards", need)
	var price := campaign.core_price(tower)
	if profile.cores() < price:
		return I18n.f("Need %d more Cores", price - profile.cores())
	return ""


## Shards complete + Cores: the shards are used up, the Cores paid, the tower is owned for good.
func buy_tower(tower: TowerDef) -> bool:
	if shop_block_reason(tower) != "":
		return false
	if not profile.spend("tower:%s" % tower.id, campaign.core_price(tower)):
		return false
	profile.add_shards("buy:%s" % tower.id, tower.id, -campaign.shard_cost(tower))
	profile.unlock_tower(tower.id)
	save()
	return true


# ================================================================ consumable items

func buy_item(item: ConsumableDef) -> bool:
	if profile.cores() < item.cost:
		return false
	var key := profile.next_item_key()
	if not profile.spend(key, item.cost):
		return false
	profile.add_item(key, item.id, 1)
	save()
	return true


## Why `item` cannot be used right now in this match ("" = can). One use per item per match.
func use_item_block_reason(item: ConsumableDef, match_id: String) -> String:
	if profile.item_count(item.id) <= 0:
		return I18n.t("None owned")
	if profile.has_item_event("use:%s:%s" % [item.id, match_id]):
		return I18n.t("Already used this match")
	return ""


## Consumes one `item` for this match. Call only after MatchController applied its effect
## (or right before, since it cannot fail once use_item_block_reason() is "").
func use_item(item: ConsumableDef, match_id: String) -> bool:
	if use_item_block_reason(item, match_id) != "":
		return false
	profile.add_item("use:%s:%s" % [item.id, match_id], item.id, -1)
	save()
	return true


# ================================================================ research

func research_block_reason(id: StringName) -> String:
	var r := campaign.find_research(id)
	if r == null:
		return I18n.t("Unknown")
	if profile.has_research(id):
		return I18n.t("Owned")
	for req in r.requires:
		if not profile.has_research(req):
			var rd := campaign.find_research(req)
			return I18n.f("Requires %s", I18n.t(rd.display_name) if rd != null else String(req))
	if r.requires_tower != &"" and not profile.owns_tower(r.requires_tower):
		return I18n.f("Unlock %s first", I18n.t(String(r.requires_tower).capitalize()))
	if profile.cores() < r.cost:
		return I18n.f("Need %d more Cores", r.cost - profile.cores())
	return ""


func buy_research(id: StringName) -> bool:
	if research_block_reason(id) != "":
		return false
	var r := campaign.find_research(id)
	if not profile.spend("research:%s" % id, r.cost):
		return false
	profile.data["research"].append(String(id))
	save()
	return true


## Undo every research purchase and refund its Cores (2026-11-18, user: re-check the prices).
## Removes the "research:<id>" spend entries from the ledger together with the research ids, so a later
## merge with an older copy brings both back together (never a free refund). Returns the Cores refunded.
func research_refund_total() -> int:
	var total := 0
	for id in profile.data["research"]:
		total -= int(profile.data["ledger"].get("research:%s" % id, 0))
	return total


func reset_research() -> int:
	var refund := research_refund_total()
	for id in profile.data["research"]:
		profile.data["ledger"].erase("research:%s" % id)
	profile.data["research"].clear()
	save()
	return refund


# ================================================================ challenges

func find_challenge(id: StringName) -> ChallengeDef:
	for c in campaign.daily_pool + campaign.weekly_pool:
		if c.id == id:
			return c
	return null


func current_challenges(unix: int) -> Dictionary:
	var dk := ChallengeSchedule.daily_key(unix)
	var wk := ChallengeSchedule.weekly_key(unix)
	var d := ChallengeSchedule.pick(campaign.daily_pool, dk)
	var w := ChallengeSchedule.pick(campaign.weekly_pool, wk)
	return {
		"daily": d, "daily_key": dk, "daily_done": d != null and profile.data["challenges"].has("%s:%s" % [dk, d.id]),
		"weekly": w, "weekly_key": wk, "weekly_done": w != null and profile.data["challenges"].has("%s:%s" % [wk, w.id]),
	}


func challenge_level_unlocked(c: ChallengeDef) -> bool:
	return c != null and c.level != null and profile.is_cleared(c.level.id)
