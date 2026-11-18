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


## Device clock — NOT authoritative (see ChallengeSchedule). Phase 6: GameHub server time.
func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PREDELETE:
		if model != null and model.pending_save:
			model.save()
