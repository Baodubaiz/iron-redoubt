extends TestCase
## Reforged Stage F: a real profile written by build 0.7.0 (tests/fixtures/profile_v070.json, copied
## from a 0.7.0 desktop run) loads unchanged in 0.8.0 and survives a save/load round trip.

const FIXTURE := "res://tests/fixtures/profile_v070.json"
const TMP := "user://test_profile_v070_copy.json"


func _model() -> ProgressionModel:
	var campaign: CampaignDef = load("res://data/campaign.tres")
	var pm := ProgressionModel.new(campaign, LocalFileStore.new(TMP))
	pm.load_profile()
	return pm


func test_v070_profile_loads_without_repair_and_round_trips() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(raw != null and raw.has("levels"), "fixture readable")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURE))
	f.close()
	var pm := _model()
	check(not pm.recovered, "no repair needed: %s" % pm.last_load_error)
	var ledger_sum := 0
	for k in raw["ledger"]:
		ledger_sum += int(raw["ledger"][k])
	eq(pm.profile.cores() + _spent(raw), ledger_sum, "cores = ledger - spent")
	for id in raw["levels"]:
		eq(bool(pm.profile.level_record(StringName(id))["cleared"]), bool(raw["levels"][id]["cleared"]), "level %s cleared" % id)
	eq(pm.profile.data["achievements"].size(), raw["achievements"].size(), "achievements kept")
	# 0.7.0 cleared level_01..06; since 0.10 the campaign has 40 levels in a new order (ids kept):
	# every cleared level stays playable, the first new level after the clears opens, later ones stay locked
	for id in raw["levels"]:
		if bool(raw["levels"][id]["cleared"]):
			check(pm.is_level_unlocked(pm.campaign.levels[pm.campaign.level_index(StringName(id))]), "%s playable" % id)
	check(pm.is_level_unlocked(pm.campaign.levels[2]), "Circuit 3 (new) opens after level_02")
	check(not pm.is_level_unlocked(pm.campaign.levels[3]), "Circuit 4 still locked")
	check(not pm.is_level_unlocked(pm.campaign.levels[20]), "Prism 1 (level_07) locked")
	# round trip with the 0.8.0 code
	check(pm.save(), "saved")
	var again := _model()
	eq(again.profile.cores(), pm.profile.cores(), "cores after round trip")
	eq(again.profile.data["levels"].size(), pm.profile.data["levels"].size(), "levels after round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + ".bak"))


static func _spent(raw: Dictionary) -> int:
	var s := 0
	for k in raw.get("spent", {}):
		s += int(raw["spent"][k])
	return s
