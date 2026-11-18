class_name TestCase
extends RefCounted
## Base class for tests: assertions + helpers to build deterministic matches.

var tree: SceneTree
var failures: Array[String] = []
var assert_count: int = 0
var _nodes: Array[Node] = []

const DT := 1.0 / 60.0


func before_each() -> void:
	pass


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	if tree != null:
		tree.paused = false


# ---------------------------------------------------------------- assertions

func check(cond: bool, msg: String) -> void:
	assert_count += 1
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	check(actual == expected, "%s expected %s, got %s" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float, msg: String = "") -> void:
	check(absf(actual - expected) <= tol, "%s expected %.4f±%.4f, got %.4f" % [msg, expected, tol, actual])


# ---------------------------------------------------------------- fixtures

static func make_enemy_def(hp: float = 100.0, speed: float = 50.0, armor: float = 0.0, bounty: int = 5,
		base_damage: int = 1, flying: bool = false) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = &"test_enemy"
	e.display_name = "Test"
	e.max_hp = hp
	e.speed = speed
	e.armor = armor
	e.bounty = bounty
	e.base_damage = base_damage
	e.flying = flying
	return e


static func make_tower_def(cost: int = 100, damage: float = 10.0, rate: float = 2.0, attack_range: float = 150.0,
		splash: float = 0.0, air: bool = true, targeting: TowerDef.TargetRule = TowerDef.TargetRule.FIRST) -> TowerDef:
	var t := TowerDef.new()
	t.id = &"test_tower"
	t.display_name = "TestTower"
	t.cost = cost
	t.damage = damage
	t.fire_rate = rate
	t.attack_range = attack_range
	t.splash_radius = splash
	t.can_target_air = air
	t.targeting = targeting
	t.projectile_speed = 100000.0 # effectively instant for deterministic tests
	t.homing = splash <= 0.0
	return t


## Straight horizontal route y=300 from x=0 to x=1000 inside a 1280x720 build area.
static func make_map() -> MapDef:
	var m := MapDef.new()
	m.id = &"test_map"
	m.routes = [PackedVector2Array([Vector2(0, 300), Vector2(1000, 300)])]
	m.build_area = Rect2(0, 64, 1160, 656)
	m.blocked_rects = [Rect2(500, 500, 100, 100)]
	return m


static func make_wave(enemy: EnemyDef, count: int, interval: float = 1.0, variance: float = 0.0) -> WaveDef:
	var g := SpawnGroupDef.new()
	g.enemy = enemy
	g.count = count
	g.interval = interval
	g.count_variance = variance
	var w := WaveDef.new()
	var groups: Array[SpawnGroupDef] = [g]
	w.groups = groups
	return w


static func make_level(waves: Array[WaveDef], towers: Array[TowerDef], money: int = 500, hp: int = 10) -> LevelDef:
	var l := LevelDef.new()
	l.id = &"test_level"
	l.map = make_map()
	l.waves = waves
	l.available_towers = towers
	l.starting_currency = money
	l.base_hp = hp
	l.economy = EconomyConfig.new()
	l.prep_time = 20.0
	return l


func make_match(level: LevelDef, seed_value: int = 1234, unlocks: UpgradeRules.Unlocks = null) -> MatchController:
	var m := MatchController.new()
	m.auto_process = false
	tree.root.add_child(m)
	_nodes.append(m)
	m.setup(level, seed_value, unlocks)
	return m


static func real_tower(id: String) -> TowerDef:
	return load("res://data/towers/%s.tres" % id)


static func real_enemy(id: String, speed_override: float = -1.0) -> EnemyDef:
	var e: EnemyDef = load("res://data/enemies/%s.tres" % id)
	if speed_override >= 0.0:
		e = e.duplicate()
		e.speed = speed_override
	return e


static func all_real_towers() -> Array[TowerDef]:
	var a: Array[TowerDef] = [real_tower("pulse"), real_tower("nova"), real_tower("lance"), real_tower("beacon"),
		real_tower("trap"), real_tower("venom"), real_tower("sniper"), real_tower("bastion"), real_tower("spotter"), real_tower("storm"),
		real_tower("chronos")]
	return a


## Match with all 4 real towers, lots of money, two idle waves (so it never auto-ends).
func make_lab(money: int = 100000, unlocks: UpgradeRules.Unlocks = null) -> MatchController:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(), 1), make_wave(make_enemy_def(), 1)]
	return make_match(make_level(waves, all_real_towers(), money, 100), 1234, unlocks)


## Places an enemy at a given progress along the straight test route (y = 300).
func put(m: MatchController, def: EnemyDef, x: float) -> Enemy:
	var e := m.spawn_enemy(def)
	e.place_at_progress(x)
	return e


func run(m: MatchController, seconds: float) -> void:
	var steps := int(round(seconds / DT))
	for i in range(steps):
		m.step(DT)


func run_until(m: MatchController, cond: Callable, max_seconds: float) -> bool:
	var steps := int(max_seconds / DT)
	for i in range(steps):
		if cond.call():
			return true
		m.step(DT)
	return cond.call()
