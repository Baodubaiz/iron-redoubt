extends TestCase
## Settings persistence, audio limiter, safe-area / aspect-ratio layout math, audio assets.


func test_settings_roundtrip_and_clamping() -> void:
	var path := "user://test_settings_%d.cfg" % Time.get_ticks_usec()
	var s := GameSettings.new()
	s.music_on = false
	s.sfx_volume = 0.35
	s.music_volume = 0.9
	eq(s.save(path), OK)
	var t := GameSettings.new()
	t.load_from(path)
	check(not t.music_on and t.sfx_on, "toggles persisted")
	near(t.sfx_volume, 0.35, 0.0001)
	near(t.music_volume, 0.9, 0.0001)
	var cf := ConfigFile.new()
	cf.set_value("audio", "sfx_volume", 7.0)
	cf.set_value("audio", "music_volume", -3.0)
	cf.save(path)
	var u := GameSettings.new()
	u.load_from(path)
	near(u.sfx_volume, 1.0, 0.0001, "clamped high")
	near(u.music_volume, 0.0, 0.0001, "clamped low")
	var v := GameSettings.new()
	v.load_from("user://does_not_exist.cfg")
	check(v.music_on and v.sfx_on, "defaults when missing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	eq(GameSettings.to_db(0.5, false), -80.0, "off = silent")
	eq(GameSettings.to_db(0.0, true), -80.0, "zero = silent")
	near(GameSettings.to_db(1.0, true), 0.0, 0.001)


func test_sfx_limiter_caps_voices() -> void:
	var l := SfxLimiter.new()
	check(l.try_start(&"shot", 0, 100), "first")
	check(not l.try_start(&"shot", 10, 100), "cooldown 40 ms")
	check(l.try_start(&"shot", 50, 100), "second voice")
	check(not l.try_start(&"shot", 95, 100), "per-sound cap 2")
	check(l.try_start(&"shot", 160, 100), "voice freed after it ends")
	var ok := 0
	for i in range(30):
		if l.try_start(StringName("s%d" % i), 200, 1000):
			ok += 1
	check(ok <= l.global_max, "global cap respected (%d)" % ok)
	check(l.active_count(200) <= l.global_max, "active <= 12")
	eq(l.active_count(5000), 0, "all ended")


func test_safe_area_conversion() -> void:
	# 2400x1080 phone with a 100 px notch on the left and a 50 px gesture bar on the right.
	var ins := ScreenLayout.from_rects(Rect2(0, 0, 2400, 1080), Rect2(100, 0, 2250, 1080), Vector2(1600, 720))
	near(ins["left"], 100 * (1600.0 / 2400.0), 0.01)
	near(ins["right"], 50 * (1600.0 / 2400.0), 0.01)
	near(ins["top"], 0, 0.01)
	near(ins["bottom"], 0, 0.01)


func test_world_offset_centres_in_safe_area() -> void:
	var z := ScreenLayout.zero()
	check(ScreenLayout.world_offset(Vector2(1280, 720), z).is_equal_approx(Vector2.ZERO), "16:9 exact")
	check(ScreenLayout.world_offset(Vector2(1600, 720), z).is_equal_approx(Vector2(160, 0)), "20:9 centred")
	check(ScreenLayout.world_offset(Vector2(1280, 960), z).is_equal_approx(Vector2(0, 120)), "4:3 centred")
	var notch := {"left": 66.0, "top": 0.0, "right": 33.0, "bottom": 0.0}
	var off := ScreenLayout.world_offset(Vector2(1600, 720), notch)
	near(off.x, 66.0 + (1600 - 99 - 1280) * 0.5, 0.01, "centred inside safe area")
	check(off.x >= 66.0 and off.x + 1280 <= 1600 - 33.0 + 0.01, "world fully inside safe area")
	var tight := ScreenLayout.world_offset(Vector2(1280, 720), {"left": 40.0, "top": 0.0, "right": 0.0, "bottom": 0.0})
	near(tight.x, 40.0, 0.01, "never under the notch")


func test_all_audio_assets_load() -> void:
	for id in ["ui_click", "build", "upgrade", "evolve", "sell", "shot_pulse", "shot_nova", "shot_lance", "impact",
			"enemy_death", "wave_start", "boss", "emp", "victory", "defeat"]:
		var s: AudioStream = load("res://audio/sfx/%s.wav" % id)
		check(s != null and s.get_length() > 0.0, "sfx %s" % id)
	var m: AudioStream = load("res://audio/music/ambient_loop.wav")
	check(m != null and m.get_length() > 30.0, "music loop")


func test_every_tower_has_a_shot_sound_or_is_aura() -> void:
	for t in all_real_towers():
		if t.attack_mode == TowerDef.AttackMode.AURA:
			continue
		check(ResourceLoader.exists("res://audio/sfx/shot_%s.wav" % t.id), "shot sound for %s" % t.id)


func test_wide_screen_world_leaves_room_for_the_palette() -> void:
	var z := ScreenLayout.zero()
	var off := ScreenLayout.world_offset(Vector2(1600, 720), z, 120.0)
	near(off.x, 100.0, 0.001, "spare 320 - palette 120 = 200, split evenly")
	check(ScreenLayout.world_offset(Vector2(1280, 720), z, 120.0).is_equal_approx(Vector2.ZERO), "16:9 unchanged")
	near(ScreenLayout.world_offset(Vector2(1340, 720), z, 120.0).x, 0.0, 0.001, "never pushed off-screen")


## 2026-11-19 smooth camera: the wheel zoom glides to its target; a released drag keeps sliding, then stops.
func test_camera_zoom_glides_and_pan_coasts() -> void:
	var cam := MatchCamera.new()
	cam.world = Node2D.new()
	cam.reset(Vector2.ZERO, Rect2(0, 0, 1280, 720))
	cam._glide_zoom(Vector2(640, 360), 1.5)
	cam._process(1.0 / 60.0)
	check(cam.zoom > 1.0 and cam.zoom < 1.5, "first frame is part of the way (%.3f)" % cam.zoom)
	for i in range(60):
		cam._process(1.0 / 60.0)
	near(cam.zoom, 1.5, 0.01, "arrives within a second")
	cam._vel = Vector2(-600, 0)
	var x0 := cam.world.position.x
	cam._process(1.0 / 60.0)
	check(cam.world.position.x < x0, "keeps sliding after release")
	for i in range(240):
		cam._process(1.0 / 60.0)
	eq(cam._vel, Vector2.ZERO, "and comes to rest")
	cam.world.free()
	cam.free()
