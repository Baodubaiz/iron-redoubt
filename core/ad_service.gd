class_name AdService
extends RefCounted
## Rewarded / midgame ad entry point. Picks the provider at runtime (2026-11-19, one web build for all):
##   crazygames : the web build where the CrazyGames SDK is live (their site, or localhost with fake ads)
##   test       : playtest builds elsewhere (GitHub Pages, playtest APK) and the editor -> "watched" at once
##   none       : any other release build (no ad SDK yet, e.g. Android before AdMob) -> no ads, no reward
## AdMob for Android plugs in here later as another provider; callers never change.

## Tests may force a provider ("test" / "none"); "" = decide from the build.
static var force_provider := ""


static func provider() -> String:
	if force_provider != "":
		return force_provider
	if CrazyGamesSdk.is_active():
		return "crazygames"
	if CrazyGamesSdk.is_target() and not CrazyGamesSdk.is_ready():
		return "pending" # SDK still starting: offer nothing yet
	if OS.has_feature("playtest") or OS.is_debug_build():
		return "test"
	return "none"


static func is_test_mode() -> bool:
	return provider() == "test"


## False when this build cannot show ads at all (the Armory then hides the ad button's offer).
static func is_available() -> bool:
	match provider():
		"test": return true
		"crazygames": return CrazyGamesSdk.is_active()
	return false


## `on_done(true)` only when the player watched the whole rewarded ad.
static func show_rewarded(on_done: Callable) -> void:
	match provider():
		"test":
			on_done.call(true)
		"crazygames":
			CrazyGamesSdk.request_ad("rewarded", on_done)
		_:
			on_done.call(false)


## Break ad between matches (CrazyGames handles the frequency: too soon = silently skipped).
static func show_midgame(on_done: Callable = Callable()) -> void:
	if provider() == "crazygames":
		CrazyGamesSdk.request_ad("midgame", func(_ok: bool) -> void:
			if on_done.is_valid():
				on_done.call())
	elif on_done.is_valid():
		on_done.call()
