extends SceneTree
## Dev tool: store covers + trailer footage. Never touches the real profile.
## 2026-11-22 rework (user: old covers looked cluttered and machine-placed, no logo): level 18 "Delta Bridge"
## (zig-zag lane), a hand-placed defence like a real player builds it (killzone in the V, support beside it,
## cheap towers at the merge, a sniper at the back, mixed upgrade levels, one evolution), enemies marching in
## columns from both gates with a boss, and the game logo composited on the covers.
##   Stills: godot --path . --resolution 1920x1080 -s res://tools/capture_covers.gd -- --out=<dir>
##   Video : godot --path . --write-movie <dir>/raw.avi --fixed-fps 30 \
##             -s res://tools/capture_covers.gd -- --out=<dir> --video=20 [--zoom=1.0]
##           with a temporary override.cfg in the project root (delete it afterwards, never commit it):
##             [display] window/size/window_width_override=1920, window/size/window_height_override=1080
##               (Movie Maker records the project's 1280x720 otherwise)
##             [physics] common/physics_interpolation=false
##               (with --fixed-fps the interpolated enemies do not visibly move in the recording)
##           The action starts at frame 321 (after a 3x fast pre-roll); the store trailers are cut from there
##           with ffmpeg (20 s, logo fading in over the last 3 s; portrait = centre 720x1080 crop -> 1080x1620).
## Stills writes frame<n>_full.png (render size) and the composed covers cover_<n>_{1920x1080,800x1200,800x800}.png,
## plus logo.png (transparent) for the trailer overlay.

const LEVEL := 17 ## campaign index: 18 - Delta Bridge
## [tower, world position, main branch, main tiers, secondary branch, secondary tiers, evolve]
const LAYOUT := [
	["nova", Vector2(640, 470), 0, 3, 1, 1, true], # the killzone: inside the V, hits both legs
	["beacon", Vector2(640, 385), 0, 1, -1, 0, false], # support right behind it
	["storm", Vector2(400, 232), 0, 2, -1, 0, false], # under the first peak
	["lance", Vector2(880, 245), 0, 3, 1, 2, false], # under the second peak, last line before the core
	["pulse", Vector2(252, 402), 0, 2, -1, 0, false], # cheap towers where the two gates merge
	["pulse", Vector2(100, 296), 0, 0, -1, 0, false],
	["coil", Vector2(302, 330), 0, 2, -1, 0, false],
	["venom", Vector2(522, 252), 0, 1, -1, 0, false],
	["trap", Vector2(1012, 192), 0, 0, -1, 0, false],
	["sniper", Vector2(1150, 205), 0, 2, -1, 0, false], # long range, from the back
]
## enemy column pattern (repeats), alternating gates
const MARCH := ["drone", "drone", "hopper", "hopper", "hopper", "brute", "drone", "plated", "glider", "dart", "dart",
	"hopper", "aegis", "drone", "drone", "brute", "glider", "phantom"]

var _out := "user://covers"
var _video := 0.0
var _zoom := 1.0
var _wait := 8
var _step := 0
var _t := 0.0
var _spawn_t := 0.0
var _march_i := 0
var _shot := 0
var _ctrl: MatchController
var _scene: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
		elif a.begins_with("--video="): _video = float(a.substr(8))
		elif a.begins_with("--zoom="): _zoom = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(_out)


func _dt(delta: float) -> float:
	return 1.0 / 30.0 if _video > 0.0 else delta # movie mode: fixed 30 fps


func _process(delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root)
	var router = root.get_node("/root/SceneRouter")
	var pm: ProgressionModel = root.get_node("/root/Progression").model
	match _step:
		0:
			TranslationServer.set_locale("en")
			for id in ["pulse", "coil", "nova", "lance", "beacon", "trap", "venom", "sniper", "spotter", "storm"]:
				pm.profile.unlock_tower(StringName(id))
			for r in pm.campaign.research:
				pm.profile.data["research"].append(String(r.id))
			pm.profile.add_counter("tutorial_done", 1)
			router.first_run_done = true
			router.pending_level = pm.campaign.levels[LEVEL]
			var ids: Array[StringName] = [&"nova", &"lance", &"storm", &"pulse", &"coil", &"beacon"]
			router.start_match_with_loadout(ids)
			_step = 1
			_wait = 40
		1:
			_scene = current_scene
			_ctrl = _scene.get("controller")
			(_scene.get("hud") as CanvasLayer).visible = false
			_build_defence()
			if _zoom > 1.0:
				var cam: MatchCamera = _scene.get("camera")
				cam.zoom_at(Vector2(root.size) * 0.5, _zoom)
			if _video <= 0.0:
				_save_logo()
			Engine.time_scale = 3.0 # fill the lane quickly (trimmed from the trailer)
			_step = 2
			_t = 0.0
		2:
			if _video > 0.0: # stills: the lane is staged by _spread_groups instead of a long queue
				_march(_dt(delta))
			_t += _dt(delta)
			if _t >= 9.0:
				Engine.time_scale = 1.0
				for e in _ctrl.enemies: # the boss walks into the killzone just as the action starts
					if e.is_boss():
						e.place_at_progress(980.0)
				_spread_groups()
				_step = 3
				_t = 0.0
				print("ACTION_START_FRAME ", Engine.get_process_frames())
		3:
			if _video <= 0.0 and _t < 0.05:
				_spawn_t = 2.5 # a fresh group from the gates a moment later
			var bui = _ctrl.map_view.get("_boss_ui")
			if bui is CanvasItem:
				(bui as CanvasItem).visible = false # boss bar is HUD-like clutter on a cover
			var bars = _ctrl.map_view.get("_enemy_over")
			if bars is CanvasItem and _video <= 0.0:
				(bars as CanvasItem).visible = false # health bars of a whole column read as noise on a still
			_march(_dt(delta))
			_t += _dt(delta)
			if _video > 0.0:
				if _t >= _video:
					quit()
					return true
			elif _t >= 2.0 + _shot * 1.3 and not _ctrl.paused:
				# freeze one frame and drop hit flashes first: a 0.06 s white flash frozen on a still reads as a glitch
				_ctrl.paused = true
				for e in _ctrl.enemies:
					e._flash = 0.0
					for ch in e.get_children():
						if ch is CanvasItem:
							(ch as CanvasItem).queue_redraw()
			elif _ctrl.paused:
				_save_frame()
				_ctrl.paused = false
				_shot += 1
				if _shot >= 6:
					print("covers saved to ", ProjectSettings.globalize_path(_out))
					quit()
					return true
	return false


## Nearest valid build spot to the planned one (the plan is in world units; footprints / blocked tiles vary).
func _place(want: Vector2, def: TowerDef) -> Vector2:
	if _ctrl.validate_placement(def, want) == PlacementRules.Result.OK:
		return want
	for r in [6.0, 12.0, 18.0, 24.0, 30.0]:
		for k in range(12):
			var p: Vector2 = want + Vector2.from_angle(TAU * k / 12.0) * r
			if _ctrl.validate_placement(def, p) == PlacementRules.Result.OK:
				return p
	return Vector2.INF


func _build_defence() -> void:
	_ctrl.economy.credit(1000000, "covers")
	_ctrl.base.max_hp = 100000
	_ctrl.base.hp = 100000
	for row in LAYOUT:
		var def: TowerDef = load("res://data/towers/%s.tres" % row[0])
		var p := _place(row[1], def)
		if p == Vector2.INF:
			push_warning("no spot for %s near %s" % [row[0], row[1]])
			continue
		var t := _ctrl.try_build(def, p)
		if t == null:
			continue
		for k in range(int(row[3])):
			_ctrl.try_upgrade(t, int(row[2]))
		if int(row[4]) >= 0:
			for k in range(int(row[5])):
				_ctrl.try_upgrade(t, int(row[4]))
		if row[6]:
			t.waves_since_t3 = 5
			if _ctrl.unlocks != null:
				_ctrl.unlocks.evolutions[def.id] = true
			_ctrl.try_evolve(t)
	# no real wave: its spawns queue up at the gates; the lane is staged by _march / _spread_groups instead
	var boss := _ctrl.spawn_enemy(load("res://data/enemies/leviathan.tres"), 1)
	boss.max_hp *= 25.0
	boss.hp = boss.max_hp


## Mid-wave look: small groups spread along the whole lane (the front ones already worn down), so both Vs
## have something to shoot at instead of one long queue at the gates.
const GROUPS := [[260.0, ["drone", "drone", "hopper"]], [470.0, ["brute", "drone", "drone"]],
	[700.0, ["hopper", "hopper", "hopper", "dart"]], [1180.0, ["plated", "drone"]], [1400.0, ["hopper", "drone", "drone"]],
	[1640.0, ["aegis", "dart"]], [1860.0, ["drone"]]]


func _spread_groups() -> void:
	for g in GROUPS:
		var at: float = g[0]
		var worn := clampf(1.0 - at / 2400.0, 0.25, 1.0)
		var k := 0
		for id in g[1]:
			var e := _ctrl.spawn_enemy(load("res://data/enemies/%s.tres" % id), k % 2)
			e.place_at_progress(at - 26.0 * k)
			e.max_hp *= 10.0
			e.hp = e.max_hp * worn
			k += 1


## Groups from both gates like real waves: 3-5 enemies close together, then a gap; the gate alternates per
## group. Tough enough that some reach the second V.
var _group_left := 0
var _gate := 0


func _march(dt: float) -> void:
	_spawn_t -= dt
	if _spawn_t > 0.0 or _ctrl.alive_enemy_count() >= 34:
		return
	if _group_left <= 0:
		_group_left = 3 + (_march_i % 3)
		_gate = 1 - _gate
	var id: String = MARCH[_march_i % MARCH.size()]
	var e := _ctrl.spawn_enemy(load("res://data/enemies/%s.tres" % id), _gate)
	e.max_hp *= 10.0
	e.hp = e.max_hp
	_march_i += 1
	_group_left -= 1
	_spawn_t = 0.35 + 0.12 * float(_march_i % 3) if _group_left > 0 else 1.6 + 0.4 * float(_march_i % 2)


# ---------------------------------------------------------------- covers + logo

func _save_frame() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png("%s/frame%d_full.png" % [_out, _shot])
	var logo := Image.load_from_file(_out + "/logo.png")
	var w := img.get_width()
	var h := img.get_height()
	var land := img.duplicate() as Image
	land.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	_compose(land, logo, 0.42, false, true).save_png("%s/cover_%d_1920x1080.png" % [_out, _shot])
	var pw := int(h * 2.0 / 3.0)
	var pt := img.get_region(Rect2i((w - pw) / 2, 0, pw, h))
	pt.resize(800, 1200, Image.INTERPOLATE_LANCZOS)
	_compose(pt, logo, 0.92, true).save_png("%s/cover_%d_800x1200.png" % [_out, _shot])
	var sq := img.get_region(Rect2i((w - h) / 2, 0, h, h))
	sq.resize(800, 800, Image.INTERPOLATE_LANCZOS)
	_compose(sq, logo, 0.78, true).save_png("%s/cover_%d_800x800.png" % [_out, _shot])


## Dark band for contrast with the logo on it (width = share of the image width); at the top, or at the bottom
## (landscape: the lower-left of Delta Bridge is open ground, the top-left holds the first peak).
func _compose(base: Image, logo: Image, share: float, centered: bool, bottom: bool = false) -> Image:
	var out := base.duplicate() as Image
	var w := out.get_width()
	var h := out.get_height()
	var lw := int(w * share)
	var lh := int(logo.get_height() * float(lw) / logo.get_width())
	var band := int(lh * 1.9)
	var grad := Image.create(1, band, false, Image.FORMAT_RGBA8)
	for y in range(band):
		var k := float(band - 1 - y) / band if bottom else float(y) / band
		grad.set_pixel(0, y, Color(0.02, 0.03, 0.07, 0.82 * pow(1.0 - k, 1.4)))
	grad.resize(w, band, Image.INTERPOLATE_NEAREST)
	out.blend_rect(grad, Rect2i(0, 0, w, band), Vector2i(0, h - band if bottom else 0))
	var l := logo.duplicate() as Image
	l.resize(lw, lh, Image.INTERPOLATE_LANCZOS)
	var x := (w - lw) / 2 if centered else int(w * 0.03)
	var y := h - lh - int(lh * 0.30) if bottom else int(lh * 0.22)
	out.blend_rect(l, Rect2i(0, 0, lw, lh), Vector2i(x, y))
	return out


## The menu logo (hex emblem + IRON REDOUBT + DEFENSE PROTOCOL), rendered big on a transparent background.
func _save_logo() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(2000, 420)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 46)
	row.position = Vector2(20, 20)
	vp.add_child(row)
	var emblem := HexLogo.new()
	emblem.custom_minimum_size = Vector2(300, 300)
	row.add_child(emblem)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -14)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(tv)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 46)
	tv.add_child(name_row)
	for part in [["IRON", UiKit.TEXT], ["REDOUBT", UiKit.ACCENT]]:
		var lbl := UiKit.title(part[0], 176, part[1], 12)
		lbl.add_theme_constant_override("outline_size", 26)
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.9))
		name_row.add_child(lbl)
	var sub := UiKit.title("DEFENSE PROTOCOL", 52, VisualPalette.TEXT_DIM, 20)
	sub.add_theme_constant_override("outline_size", 14)
	sub.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.9))
	tv.add_child(sub)
	await process_frame
	await process_frame
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var used := img.get_used_rect()
	img = img.get_region(used.grow(12).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img.save_png(_out + "/logo.png")
	vp.queue_free()
