extends Node
## Autoload "Progression": owns the ProgressionModel for the running game.
## Phase 4 uses LocalFileStore (on-device). Phase 6 swaps in a GameHub-backed store.

const CAMPAIGN_PATH := "res://data/campaign.tres"

var model: ProgressionModel
var campaign: CampaignDef


func _ready() -> void:
	campaign = load(CAMPAIGN_PATH)
	var path := "user://profile.json"
	for a in OS.get_cmdline_user_args(): # dev tools / captures use a separate profile file
		if a.begins_with("--profile="):
			path = a.substr(10)
	model = ProgressionModel.new(campaign, LocalFileStore.new(path))
	model.load_profile()
	CrazyGamesSdk.when_ready(_adopt_crazygames_save) # web builds: no-op elsewhere


## On CrazyGames (and the localhost test page) the profile moves to the SDK Data module so it follows the
## player's CrazyGames account. Whatever this browser already had (an older guest save, or play before the SDK
## finished starting) is merged in: the ledger merge never loses or doubles Cores / clears. If the module is
## off or fails, the game simply keeps the on-device save.
func _adopt_crazygames_save() -> void:
	if not CrazyGamesSdk.is_active() or model == null:
		return
	var store := CrazyGamesDataStore.new()
	var r := store.load_data()
	if not r["ok"]:
		push_warning("CrazyGames Data module unavailable, keeping the local save: " + str(r["error"]))
		return
	var local := model.profile.data
	var merged: Dictionary = local
	if not (r["data"] as Dictionary).is_empty():
		var cloud: Dictionary = Profile.sanitize(r["data"], campaign.starting_towers)["data"]
		merged = Profile.merge(cloud, local)
	model.store = store
	model.profile = Profile.new(merged)
	for t in campaign.starting_towers:
		model.profile.unlock_tower(t)
	if not model.save(): # first write into the account; on failure keep going on the device file
		push_warning("CrazyGames Data module save failed, keeping the local save")
		model.store = LocalFileStore.new("user://profile.json")
		model.pending_save = false


## Device clock — NOT authoritative (see ChallengeSchedule). Phase 6: GameHub server time.
func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PREDELETE:
		if model != null and model.pending_save:
			model.save()
