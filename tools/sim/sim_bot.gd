class_name SimBot
extends RefCounted
## Map-agnostic scripted player for headless simulation (tests + balancing).
## Builds at the valid spot with the best route coverage. With `adaptive`, it reads the current and
## next wave (like an experienced player who knows the level) and buys the counter tower:
## Beacon for stealth, Pulse for fliers, Lance for armor/shields/bosses; otherwise it follows
## `build_order`. It builds a minimum defence before upgrading, then alternates.
## Never cheats: uses only the public MatchController command API.

var controller: MatchController
var build_order: Array[TowerDef] = []
var loop_order: bool = true
var start_early: bool = false
var think_interval: float = 0.5
## tower id -> branch index, or [main, secondary] branch indices (evolves when allowed). Empty = no upgrades.
var branch_pref: Dictionary = {}
## Build at most this many towers (then only upgrade). -1 = unlimited.
var max_towers: int = -1
## How much an air-route sample counts vs a ground sample for air-capable towers.
var air_weight: int = 1
var adaptive: bool = false
var min_towers_before_upgrade: int = 0
var upgrades_per_extra_tower: int = 2

var _order_i: int = 0
var _timer: float = 0.0
var _upgrades_done: int = 0
var _route_samples: PackedVector2Array
var _air_samples: PackedVector2Array


func _init(m: MatchController, order: Array[TowerDef]) -> void:
	controller = m
	build_order = order
	_route_samples = _sample(m.routes)
	_air_samples = _sample(m.air_routes)


func _sample(rs: Array[RoutePath]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for r in rs:
		var d := 0.0
		var seg := 0
		while d <= r.total_length:
			seg = r.segment_for(d, seg)
			out.append(r.position_at(d, seg))
			d += 12.0
	return out


func step(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = think_interval
	if controller.state == MatchController.State.WAITING_FIRST_WAVE:
		_try_build_all()
		controller.request_next_wave()
		return
	_try_build_all()
	if start_early and controller.state == MatchController.State.PREP:
		controller.request_next_wave()


func _try_build_all() -> void:
	var guard := 0
	while guard < 50:
		guard += 1
		var n := controller.towers.size()
		var prefer_upgrade := n >= min_towers_before_upgrade \
			and _upgrades_done < upgrades_per_extra_tower * (n - min_towers_before_upgrade + 1)
		if max_towers >= 0 and n >= max_towers:
			prefer_upgrade = true
		if prefer_upgrade:
			if _upgrade_once() or _build_once():
				continue
		else:
			if _build_once() or (n >= min_towers_before_upgrade and _upgrade_once()):
				continue
		return


func _upgrade_once() -> bool:
	if branch_pref.is_empty():
		return false
	for t in controller.towers:
		if not branch_pref.has(t.def.id):
			continue
		var pref: Variant = branch_pref[t.def.id]
		var order: Array = pref if pref is Array else [pref] # [main, secondary]
		for b in order:
			if controller.try_upgrade(t, int(b)):
				_upgrades_done += 1
				return true
		if controller.try_evolve(t):
			_upgrades_done += 1
			return true
	return false


func _build_once() -> bool:
	if build_order.is_empty() or (max_towers >= 0 and controller.towers.size() >= max_towers):
		return false
	if not loop_order and _order_i >= build_order.size():
		return false
	var def := _pick_def()
	if def == null or not controller.economy.can_afford(def.cost):
		return false
	var pos := best_spot(def)
	if pos.x < 0.0 or controller.try_build(def, pos) == null:
		return false
	_order_i += 1
	return true


func _count(id: StringName) -> int:
	var n := 0
	for t in controller.towers:
		if t.def.id == id:
			n += 1
	return n


func _available(id: StringName) -> TowerDef:
	for d in controller.available_towers():
		if d.id == id:
			return d
	return null


func _pick_def() -> TowerDef:
	if adaptive:
		var stealth := false
		var air_hp := 0.0
		var armor_hp := 0.0
		var waves: Array[WaveDef] = []
		var cur := controller.waves.index
		for i in [cur, cur + 1]:
			if i >= 0 and i < controller.level.waves.size():
				waves.append(controller.level.waves[i])
		for w in waves:
			for g in w.groups:
				var e := g.enemy
				var hp := e.max_hp * g.hp_multiplier * g.count + e.shield * g.count
				if e.stealth:
					stealth = true
				if e.flying:
					air_hp += hp
				if e.armor >= 4.0 or e.shield > 0.0 or e.is_boss:
					armor_hp += hp
		var beacon := _available(&"beacon")
		if stealth and beacon != null and _count(&"beacon") < mini(controller.routes.size(), 2):
			return beacon
		var pulse := _available(&"pulse")
		if air_hp > 0.0 and pulse != null and _count(&"pulse") < 2 + int(air_hp / 600.0):
			return pulse
		var lance := _available(&"lance")
		if armor_hp > 0.0 and lance != null and _count(&"lance") < 1 + int(armor_hp / 1500.0):
			return lance
	return build_order[_order_i % build_order.size()]


## Highest route coverage (samples within range) among valid grid positions; (-1,-1) if none.
func best_spot(def: TowerDef) -> Vector2:
	var area := controller.level.map.build_area
	var best := Vector2(-1, -1)
	var best_score := -1
	var r_sq := def.attack_range * def.attack_range
	var y := area.position.y + def.footprint_radius
	while y <= area.end.y - def.footprint_radius:
		var x := area.position.x + def.footprint_radius
		while x <= area.end.x - def.footprint_radius:
			var p := Vector2(x, y)
			if controller.validate_placement(def, p) == PlacementRules.Result.OK:
				var score := 0
				for s in _route_samples:
					if s.distance_squared_to(p) <= r_sq:
						score += 1
				if def.can_target_air: # fliers matter to towers that can hit them
					for s in _air_samples:
						if s.distance_squared_to(p) <= r_sq:
							score += air_weight
				if def.attack_mode == TowerDef.AttackMode.AURA:
					for t in controller.towers: # light / buff own towers like a player would
						if not t.is_beacon() and t.position.distance_squared_to(p) <= r_sq:
							score += 25
				if score > best_score:
					best_score = score
					best = p
			x += 24.0
		y += 24.0
	return best
