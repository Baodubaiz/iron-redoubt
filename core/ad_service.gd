class_name AdService
extends RefCounted
## Rewarded-ad entry point. No ad SDK is integrated yet: every request is "watched" at once (test mode)
## so the shard economy can be played and tested. When AdMob is added, only show_rewarded() changes:
## call on_done(true) from the SDK's reward callback, on_done(false) when the ad fails / is skipped.

static var test_mode := true


static func is_test_mode() -> bool:
	return test_mode


static func show_rewarded(on_done: Callable) -> void:
	on_done.call(true)
