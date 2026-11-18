extends SceneTree
## Dev tool (Reforged Stage C+): screenshots of each map mid-battle and a sheet of every tower form.
##   godot --path . --resolution 1280x720 -s res://tools/capture_reforged.gd -- --out=<dir>

var _out := "user://captures_reforged"
var _stage := 0
var _wait := 5
var _node: Node
var _ctrl: MatchController
var _bot: SimBot
var _shots := [[0, "map_circuit", 4], [3, "map_delta_night", 5], [6, "map_prism_gates", 6], [8, "map_prism_boss", 18]]
var _i := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root) # never write the real profile
	var router = root.get_node("/root/SceneRouter")
	var prog = root.get_node("/root/Progression")
	match _stage:
		0:
			if _i >= _shots.size():
				_stage = 10
				return false
			var s: Array = _shots[_i]
			var pm: ProgressionModel = prog.model
			pm.profile.data = Profile.fresh(pm.campaign.starting_towers)
			for r in pm.campaign.research:
				pm.profile.data["research"].append(String(r.id))
			pm.profile.data["owned_towers"] = ["pulse", "nova", "lance", "beacon"]
			router.pending_level = pm.campaign.levels[s[0]]
			router.pending_challenge = null
			router.pending_is_lab = false
			_show("res://gameplay/match/match_scene.tscn")
			_stage = 1
			_wait = 3
		1:
			_ctrl = _node.get("controller")
			_ctrl.auto_process = false
			var sim = load("res://tools/sim/campaign_sim.gd")
			sim.crosspath = true
			_bot = sim.make_bot(_ctrl, "balanced" if String(_shots[_i][1]).contains("delta") else "heavy")
			_stage = 2
		2:
			var s: Array = _shots[_i]
			var want_night: bool = s[1].contains("night")
			var done := false
			for k in range(1200):
				if _ctrl.is_over():
					done = true
					break
				var in_wave: bool = _ctrl.waves.index + 1 >= int(s[2]) and _ctrl.alive_enemy_count() >= 5
				if in_wave and (not want_night or _ctrl.is_night):
					done = true
					break
				_bot.step(1.0 / 60.0)
				_ctrl.step(1.0 / 60.0)
			if done:
				var best: Tower = null
				for t in _ctrl.towers:
					if best == null or t.tier + (2 if t.evolved else 0) > best.tier + (2 if best.evolved else 0):
						best = t
				if best != null and s[1] == "map_circuit":
					_node.get("placement").select(best)
				_stage = 3
				_wait = 20
		3:
			_shot(_shots[_i][1])
			_i += 1
			_stage = 0
		10:
			_show_sheet()
			_stage = 11
			_wait = 30
		11:
			_shot("tower_sheet")
			_show_vfx_sheet()
			_stage = 30
			_wait = 3
		30:
			_shot("vfx_sheet")
			_show_enemy_sheet()
			_stage = 12
			_wait = 40
		12:
			_shot("enemy_sheet")
			_stage = 13
		13:
			_staged_boss()
			_stage = 14
			_wait = 8
		14:
			# advance the staged battle in real time-ish steps so effects are mid-flight
			for k in range(int(_boss_steps)):
				_ctrl.step(1.0 / 60.0)
			_boss_steps = 0
			_ctrl.auto_process = true # let it run live so shots / impacts are on screen
			_stage = 15
			_wait = 45
		15:
			var dis := 0
			var tgt := 0
			for t in _ctrl.towers:
				if t.is_disrupted(): dis += 1
				if t.target != null or t.beam_target() != null: tgt += 1
			print("staged: towers=%d disrupted=%d targeting=%d shots=%d enemies=%d state=%s" % [_ctrl.towers.size(), dis, tgt,
				_ctrl.projectiles.active_count(), _ctrl.alive_enemy_count(), _ctrl.State.keys()[_ctrl.state]])
			_shot("staged_boss_battle")
			_stage = 16
			_wait = 5
		16, 17, 18, 19:
			var af := 0
			for f in _ctrl.projectiles._fx:
				if f.active: af += 1
			print("frame: shots=%d fx_active=%d fx_pool=%d visible=%s z=%d" % [_ctrl.projectiles.active_count(), af, _ctrl.projectiles._fx.size(), _ctrl.projectiles.is_visible_in_tree(), _ctrl.projectiles.z_index])
			_shot("staged_boss_battle_%d" % (_stage - 15))
			_stage += 1
			_wait = 5
			if _stage == 20:
				print("capture_reforged: done")
				quit(0)
				return true
	return false


func _show(path: String) -> void:
	if _node != null:
		_node.queue_free()
	_node = load(path).instantiate()
	root.add_child(_node)


func _show_sheet() -> void:
	if _node != null:
		_node.queue_free()
	var host := Node2D.new()
	_node = host
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = Color("0E1830")
	bg.size = Vector2(1280, 720)
	host.add_child(bg)
	var cols := [["base", -1, 0, -1, 0, false], ["main A T1", 0, 1, -1, 0, false], ["main A T3", 0, 3, -1, 0, false],
		["main B T3", 1, 3, -1, 0, false], ["main C T3", 2, 3, -1, 0, false], ["A3 + B2", 0, 3, 1, 2, false],
		["evo A", 0, 3, -1, 0, true], ["evo B", 1, 3, -1, 0, true], ["evo C", 2, 3, -1, 0, true]]
	var ids := ["pulse", "nova", "lance", "beacon"]
	for ci in range(cols.size()):
		var l := Label.new()
		l.text = cols[ci][0]
		l.position = Vector2(118 + ci * 128 - 40, 14)
		l.add_theme_font_size_override("font_size", 15)
		host.add_child(l)
	for ri in range(ids.size()):
		var def: TowerDef = load("res://data/towers/%s.tres" % ids[ri])
		var l := Label.new()
		l.text = ids[ri].to_upper()
		l.position = Vector2(8, 110 + ri * 165)
		host.add_child(l)
		for ci in range(cols.size()):
			var c: Array = cols[ci]
			var t := Tower.new()
			t.setup(def, 100 + ri * 10 + ci, def.cost)
			if c[1] >= 0:
				for k in range(c[2]):
					t.add_tier(c[1])
			if c[3] >= 0:
				for k in range(c[4]):
					t.add_tier(c[3])
			t.evolved = c[5]
			t.recompute()
			t.aim_angle = -0.5
			t.position = Vector2(118 + ci * 128, 125 + ri * 165) / 1.9
			var holder := Node2D.new()
			holder.scale = Vector2(1.9, 1.9)
			host.add_child(holder)
			holder.add_child(t)
			var v := TowerVisual.new(t)
			t.add_child(v)
			if ci == 0 and ri == 0:
				t.selected = true


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])


var _boss_steps := 0


func _route(a: Vector2, b: Vector2) -> RoutePath:
	return RoutePath.new(PackedVector2Array([a, b]))


func _enemy(host: Node, id: String, pos: Vector2, uid: int) -> Enemy:
	var def: EnemyDef
	if id == "monolith_shard":
		def = EnemyAbilities.shard_def(load("res://data/enemies/monolith.tres"))
	else:
		def = load("res://data/enemies/%s.tres" % id)
	var e := Enemy.new()
	e.setup(def, _route(pos - Vector2(40, 0), pos + Vector2(400, 0)), uid)
	e.position = pos
	host.add_child(e)
	e.add_child(EnemyVisual.new(e))
	return e


func _label(host: Node, text: String, pos: Vector2, size: int = 14) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	host.add_child(l)


func _show_enemy_sheet() -> void:
	if _node != null:
		_node.queue_free()
	var host := Node2D.new()
	_node = host
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = Color("121B33")
	bg.size = Vector2(1280, 720)
	host.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2(2, 2)
	host.add_child(world)
	var ids := ["swarmling", "drone", "dart", "brute", "plated", "aegis", "mender", "phantom", "glider", "monolith_shard"]
	for i in range(ids.size()):
		var x := 34.0 + i * 62.0
		_enemy(world, ids[i], Vector2(x, 50), 10 + i)
		_label(host, ids[i].replace("monolith_", ""), Vector2(x * 2 - 34, 140), 13)
	# statuses / feedback row
	var row := [["slow", "drone"], ["burn", "drone"], ["frozen", "drone"], ["stun", "drone"], ["mark+shred", "drone"],
		["damaged", "brute"], ["shield hit", "aegis"], ["stealth", "phantom"], ["revealed", "phantom"], ["healing", "mender"]]
	for i in range(row.size()):
		var x := 34.0 + i * 62.0
		var e := _enemy(world, row[i][1], Vector2(x, 128), 40 + i)
		match row[i][0]:
			"slow": e.aura_slow = 0.3
			"burn":
				e.burn_timer = 5.0
				e.burn_dps = 5.0
			"frozen": e.frozen_timer = 5.0
			"stun": e.stun_timer = 5.0
			"mark+shred":
				e.mark_timer = 5.0
				e.mark_value = 0.2
				e.shred = 2.0
				e.shred_timer = 5.0
			"damaged": e.hp = e.max_hp * 0.45
			"shield hit": e.shield = e.shield_max * 0.5
			"revealed": e.reveal_timer = 5.0
			"healing": e.heal_pulse_fx = 0.25
		_label(host, row[i][0], Vector2(x * 2 - 34, 300), 13)
	# boss phases
	var phases := [["phase I · summon", 1, 1], ["phase II · EMP charge", 2, 2], ["phase III · armour torn", 3, 0]]
	for i in range(3):
		var x := 110.0 + i * 210.0
		var e := _enemy(world, "monolith", Vector2(x, 262), 80 + i)
		e.boss_phase = phases[i][1]
		e.hp = e.max_hp * [0.9, 0.5, 0.2][i]
		if phases[i][2] == 1:
			e.telegraph_kind = 1
			e.telegraph_timer = e.def.summon_telegraph * 0.4
		elif phases[i][2] == 2:
			e.telegraph_kind = 2
			e.telegraph_timer = e.def.emp_telegraph * 0.75
		_label(host, phases[i][0], Vector2(x * 2 - 80, 640), 15)


## Staged (not simulated from a real run): L9 map, a defended lane, the Monolith + escorts.
func _staged_boss() -> void:
	var pm: ProgressionModel = root.get_node("/root/Progression").model
	var router = root.get_node("/root/SceneRouter")
	router.pending_level = pm.campaign.levels[8]
	router.pending_challenge = null
	router.pending_is_lab = false
	_show("res://gameplay/match/match_scene.tscn")
	await process_frame
	await process_frame
	_ctrl = _node.get("controller")
	_ctrl.auto_process = false
	_ctrl.economy.credit(20000, "capture")
	var defs := {}
	for d in _ctrl.available_towers():
		defs[d.id] = d
	var spots := [[&"nova", Vector2(560, 225)], [&"lance", Vector2(650, 225)], [&"pulse", Vector2(740, 225)],
		[&"beacon", Vector2(650, 300)], [&"nova", Vector2(830, 225)], [&"pulse", Vector2(470, 225)]]
	for sp in spots:
		if defs.has(sp[0]):
			var t := _ctrl.try_build(defs[sp[0]], sp[1])
			if t != null:
				for k in range(3):
					_ctrl.try_upgrade(t, 0)
	var route: RoutePath = _ctrl.routes[0]
	var boss := _ctrl.spawn_enemy_on(load("res://data/enemies/monolith.tres"), route, route.total_length * 0.52)
	boss.hp = boss.max_hp * 0.55
	for i in range(6):
		_ctrl.spawn_enemy_on(load("res://data/enemies/%s.tres" % ["drone", "aegis", "brute", "swarmling", "plated", "dart"][i]),
			route, route.total_length * (0.40 + i * 0.025))
	_boss_steps = 95


## Every projectile / effect frozen mid-animation (presentation check; not a gameplay run).
func _show_vfx_sheet() -> void:
	if _node != null:
		_node.queue_free()
	var host := Node2D.new()
	_node = host
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = Color("121B33")
	bg.size = Vector2(1280, 720)
	host.add_child(bg)
	var ps := ProjectileSystem.new()
	host.add_child(ps)
	ps.set_process(false)
	var shots := [["pulse", &"pulse", &"", false, false, false, 0.0], ["penetrator", &"pulse", &"penetrator", false, false, false, 0.0],
		["crit", &"lance", &"overcharge", true, false, false, 0.0], ["nova orb (lobbed)", &"nova", &"", false, false, false, 55.0],
		["quake shell", &"nova", &"siege", false, true, false, 55.0]]
	for i in range(shots.size()):
		var row: Array = shots[i]
		var sh := ProjectileSystem.Shot.new()
		sh.active = true
		sh.tower_id = row[1]
		sh.branch_id = row[2]
		sh.crit = row[3]
		sh.quake = row[4]
		sh.splash = row[6]
		sh.homing = row[6] == 0.0
		var x := 120.0 + i * 240.0
		sh.origin = Vector2(x - 90, 120)
		sh.dest = Vector2(x + 90, 120)
		sh.pos = Vector2(x, 120)
		ps._shots.append(sh)
		_label(host, row[0], Vector2(x - 60, 170))
	var fx := [["impact", 0, Vector2(120, 330), Vector2.ZERO, 6.0, Color(0.3098, 0.8471, 1.0), 0.18, 0.3],
		["explosion r55", 0, Vector2(330, 330), Vector2.ZERO, 55.0, Color(1.0, 0.6235, 0.2627), 0.18, 0.35],
		["EMP wave", 0, Vector2(600, 330), Vector2.ZERO, 120.0, Color("ff5c6c"), 0.4, 0.45],
		["cryo pulse", 0, Vector2(900, 330), Vector2.ZERO, 70.0, Color("bfe9ff"), 0.35, 0.4],
		["arc chain", 1, Vector2(1060, 290), Vector2(1220, 370), 0.0, Color(1.0, 0.4196, 0.8392), 0.12, 0.2],
		["pierce trail", 1, Vector2(60, 560), Vector2(220, 520), 0.0, Color(0.3098, 0.8471, 1.0), 0.12, 0.2],
		["enemy destroyed", 2, Vector2(380, 540), Vector2.ZERO, 12.0, Color.WHITE, 0.55, 0.25],
		["... debris", 2, Vector2(560, 540), Vector2.ZERO, 12.0, Color.WHITE, 0.55, 0.6],
		["boss destroyed", 2, Vector2(820, 540), Vector2.ZERO, 28.0, Color.WHITE, 1.1, 0.3]]
	for row in fx:
		var f := ProjectileSystem.Fx.new()
		f.active = true
		f.kind = row[1]
		f.pos = row[2]
		f.pos2 = row[3]
		f.radius = row[4]
		f.color = row[5]
		f.life = row[6]
		f.t = row[6] * row[7]
		f.seed = randi()
		ps._fx.append(f)
		var lp: Vector2 = row[2]
		_label(host, row[0], lp + Vector2(-50, 90))
	ps.zones.append({"pos": Vector2(1080, 560), "radius": 50.0})
	_label(host, "fire patch", Vector2(1040, 630))
	ps.queue_redraw()
	ps._zone_layer.queue_redraw()
