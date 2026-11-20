class_name CrazyGamesSdk
extends RefCounted
## Thin bridge to the CrazyGames HTML5 SDK v3 (2026-11-19). The ONE web build loads
## https://sdk.crazygames.com/crazygames-sdk-v3.js in its HTML head; the SDK itself reports where it runs:
##   "crazygames" (their site: real ads) / "local" (localhost: fake ads) / "disabled" (anywhere else, e.g. the
##   GitHub Pages playtest: every SDK call is skipped and the game falls back to its own test ads).
## Desktop and Android builds have no page and no SDK: every call is a no-op.
## Docs: https://docs.crazygames.com/sdk/intro/ , /sdk/game/ , /sdk/video-ads/

static var _ready := false
static var _environment := "none"
static var _init_cb: JavaScriptObject
static var _ad_cbs: Array = [] ## JS callbacks must stay referenced until the SDK calls them
static var _ad_running := false
static var _playing := false ## last gameplay state asked for (replayed once the SDK is ready)
static var _sent_playing := false
static var _ready_cbs: Array[Callable] = [] ## run once init() resolves (any environment)
## Audio is silenced (Master bus) while an ad plays OR while the CrazyGames site's mute setting is on.
## https://docs.crazygames.com/sdk/game/ : game.settings.muteAudio has priority over in-game audio settings;
## game.addSettingsChangeListener() reports changes. The in-game Music / SFX settings drive their own buses,
## so they can never re-enable sound while the site mutes it.
static var _site_muted := false
static var _ad_muted := false
static var _settings_cb: JavaScriptObject
## Set once the SDK answers an ad request with "adsDisabled" (ads are off during a CrazyGames Basic Launch).
static var ads_disabled := false


## True when the page carries the SDK script (web builds). Says nothing about where it runs: see is_active().
static func is_target() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.get_interface("CrazyGames") != null


## True once init() finished, whatever the environment (until then ads wait / are reported unavailable).
static func is_ready() -> bool:
	return _ready


## Running on the CrazyGames site itself (not localhost, not another host).
static func on_crazygames() -> bool:
	return _ready and _environment == "crazygames"


## True once init() resolved on a CrazyGames page (or the local test page): calls are live.
static func is_active() -> bool:
	return _ready and (_environment == "crazygames" or _environment == "local")


static func environment() -> String:
	return _environment


static func _sdk() -> JavaScriptObject:
	var cg: JavaScriptObject = JavaScriptBridge.get_interface("CrazyGames")
	if cg == null:
		return null
	return cg.SDK


## Starts the SDK (async). Reports loadingStart now and loadingStop once it is ready.
static func init() -> void:
	if not is_target() or _init_cb != null:
		return
	var sdk := _sdk()
	if sdk == null:
		push_warning("CrazyGames SDK script not found on the page")
		return
	_init_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		var s := _sdk()
		_environment = str(s.environment) if s != null else "none"
		_ready = true
		if is_active():
			_watch_settings()
		for cb in _ready_cbs:
			cb.call()
		_ready_cbs.clear()
		if is_active():
			_game_call("loadingStop")
			if _playing: # a match started before the SDK finished starting
				_send_gameplay(true))
	sdk.init().then(_init_cb)


## Runs `cb` once the SDK finished starting (right away if it already did). Web builds only.
static func when_ready(cb: Callable) -> void:
	if _ready:
		cb.call()
	elif is_target():
		_ready_cbs.append(cb)


# ---------------------------------------------------------------- Data module (progress save)
# https://docs.crazygames.com/sdk/data/ : same API as localStorage (getItem / setItem / removeItem / clear),
# synchronous, 1 MB max. Logged-in players: saved to their CrazyGames account and synced across devices;
# guests: browser localStorage. The SDK swaps the data itself when the player logs in or out.
# Calls go through a try/catch in JS so a disabled module ("Progress Save" not selected at submission) or a
# size error returns a failure instead of an engine error.

## On a CrazyGames page (or the localhost test page)? Known before the SDK finishes starting.
static func on_crazygames_host() -> bool:
	if not is_target():
		return false
	var host := str(JavaScriptBridge.eval("window.location.hostname", true))
	return host == "crazygames.com" or host.ends_with(".crazygames.com") or host == "localhost" or host == "127.0.0.1"


## The player's locale: SDK user.systemInfo.locale once the SDK is up, else the browser language. "" = unknown.
static func locale() -> String:
	if not is_target():
		return ""
	var js := "(function(){try{var s=window.CrazyGames.SDK.user.systemInfo;if(s&&s.locale)return String(s.locale);}catch(e){}"
	js += "return String(navigator.language||'');})()"
	return str(JavaScriptBridge.eval(js, true))


## Reads `key`. {ok, value: String ("" when absent), error}
static func data_get(key: String) -> Dictionary:
	if not is_active():
		return {"ok": false, "value": "", "error": "sdk not active"}
	var w: JavaScriptObject = JavaScriptBridge.get_interface("window")
	w.__irKey = key
	var r: Variant = JavaScriptBridge.eval("""(function(){try{var v=window.CrazyGames.SDK.data.getItem(window.__irKey);
		return JSON.stringify({ok:true,value:(v===null||v===undefined)?"":String(v)});}
		catch(e){return JSON.stringify({ok:false,value:"",error:String(e&&e.code||e)});}})()""", true)
	var d: Variant = JSON.parse_string(str(r))
	return d if d is Dictionary else {"ok": false, "value": "", "error": "bad reply"}


## Writes `value` under `key`. {ok, error}
static func data_set(key: String, value: String) -> Dictionary:
	if not is_active():
		return {"ok": false, "error": "sdk not active"}
	var w: JavaScriptObject = JavaScriptBridge.get_interface("window")
	w.__irKey = key
	w.__irVal = value
	var r: Variant = JavaScriptBridge.eval("""(function(){try{window.CrazyGames.SDK.data.setItem(window.__irKey,window.__irVal);
		window.__irVal=null;return JSON.stringify({ok:true});}
		catch(e){window.__irVal=null;return JSON.stringify({ok:false,error:String(e&&e.code||e)});}})()""", true)
	var d: Variant = JSON.parse_string(str(r))
	return d if d is Dictionary else {"ok": false, "error": "bad reply"}


static func _game_call(fn: String) -> void:
	if not is_active():
		return
	var game: JavaScriptObject = _sdk().game
	match fn:
		"gameplayStart": game.gameplayStart()
		"gameplayStop": game.gameplayStop()
		"loadingStop": game.loadingStop()
		"happytime": game.happytime()


## The player starts / resumes playing (match start, unpause).
static func gameplay_start() -> void:
	_playing = true
	_send_gameplay(true)


## Any break in play (pause, match end, back to a menu).
static func gameplay_stop() -> void:
	_playing = false
	_send_gameplay(false)


## Only real changes reach the SDK (a stop without a start, or two starts in a row, are dropped).
static func _send_gameplay(on: bool) -> void:
	if not is_active() or on == _sent_playing:
		return
	_sent_playing = on
	_game_call("gameplayStart" if on else "gameplayStop")


## A rare celebration moment (boss beaten).
static func happytime() -> void:
	_game_call("happytime")


## Shows a "rewarded" or "midgame" ad. `on_done(true)` only after a rewarded ad finished; errors
## (adblock, no fill, cooldown) give false. Audio is muted while the ad plays.
static func request_ad(kind: String, on_done: Callable) -> void:
	if not is_active() or _ad_running:
		on_done.call(false)
		return
	_ad_running = true
	var cbs: JavaScriptObject = JavaScriptBridge.create_object("Object")
	var started := JavaScriptBridge.create_callback(func(_a: Array) -> void:
		_ad_muted = true
		_apply_mute())
	var finished := JavaScriptBridge.create_callback(func(_a: Array) -> void:
		_end_ad()
		on_done.call(true))
	var failed := JavaScriptBridge.create_callback(func(a: Array) -> void:
		var err: Variant = a[0] if a.size() > 0 else null
		if err is JavaScriptObject and str((err as JavaScriptObject).code) == "adsDisabled":
			ads_disabled = true # Basic Launch: CrazyGames turns ads off -> stop offering them
		_end_ad()
		on_done.call(false))
	cbs.adStarted = started
	cbs.adFinished = finished
	cbs.adError = failed
	_ad_cbs = [cbs, started, finished, failed]
	_sdk().ad.requestAd(kind, cbs)


static func _end_ad() -> void:
	_ad_running = false
	_ad_muted = false
	_apply_mute()


static func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, _site_muted or _ad_muted)


## Reads game.settings.muteAudio now and follows every later change from the site's sound button.
static func _watch_settings() -> void:
	var game: JavaScriptObject = _sdk().game
	var st: JavaScriptObject = game.settings
	_site_muted = st != null and bool(st.muteAudio)
	_apply_mute()
	_settings_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
		var ns: Variant = args[0] if args.size() > 0 else null
		if ns is JavaScriptObject:
			_site_muted = bool((ns as JavaScriptObject).muteAudio)
			_apply_mute())
	game.addSettingsChangeListener(_settings_cb)


static func site_muted() -> bool:
	return _site_muted
